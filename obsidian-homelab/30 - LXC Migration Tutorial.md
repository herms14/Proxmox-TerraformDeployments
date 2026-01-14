# LXC Migration Tutorial

> Migrating Docker services from Virtual Machine to LXC container on Proxmox.

Related: [[02 - Proxmox Cluster]] | [[26 - Tutorials Index]] | [[23 - Glance Dashboard]]

---

## Overview

A beginner-friendly guide to migrating Docker-based services from a VM to an LXC container.

### VM vs LXC Comparison

| Feature | VM | LXC Container |
|---------|-----|---------------|
| Boot Time | 30-60 seconds | 1-2 seconds |
| RAM Overhead | High (needs full OS) | Low (shares host kernel) |
| Disk Usage | Large (GB) | Small (MB to GB) |
| Isolation | Complete (separate kernel) | Process-level |
| Performance | Good | Near-native |

### Why Migrate?

1. **Reduced Resource Usage** - Dashboard doesn't need full VM overhead
2. **Faster Restarts** - LXC containers start in seconds
3. **Isolation** - Keep services separate from other workloads
4. **Simplicity** - Lighter weight for simple web services

---

## Prerequisites

- Proxmox VE 8.x or 9.x
- LXC template (Ubuntu 22.04 or Debian 12)
- Basic understanding of Docker
- SSH access to Proxmox node

---

## Step 1: Create LXC Container

### Via Proxmox UI

1. Click "Create CT"
2. Configure:
   - **Hostname**: `docker-lxc-glance`
   - **Template**: Ubuntu 22.04
   - **Disk**: 20GB
   - **Cores**: 2
   - **Memory**: 4096MB
   - **Network**: VLAN 40, IP 192.168.40.12/24

### Via CLI

```bash
pct create 200 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname docker-lxc-glance \
  --cores 2 \
  --memory 4096 \
  --rootfs VMDisks:20 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.40.12/24,gw=192.168.40.1,tag=40 \
  --features nesting=1 \
  --unprivileged 0
```

---

## Step 2: Configure LXC for Docker

### Enable Nesting and Keyctl

Edit `/etc/pve/lxc/200.conf`:

```
features: nesting=1,keyctl=1
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.mount.auto: proc:rw sys:rw
```

### Start Container

```bash
pct start 200
pct enter 200
```

---

## Step 3: Install Docker

```bash
# Update system
apt update && apt upgrade -y

# Install prerequisites
apt install -y ca-certificates curl gnupg

# Add Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify
docker run hello-world
```

---

## Step 4: Migrate Services

### Copy from VM to LXC

```bash
# On source VM - create backup
cd /opt/glance
docker compose down
tar -czvf glance-backup.tar.gz config/ docker-compose.yml

# Transfer to LXC
scp glance-backup.tar.gz root@192.168.40.12:/opt/

# On LXC - restore
cd /opt
tar -xzvf glance-backup.tar.gz
docker compose up -d
```

---

## Step 5: AppArmor Workaround

If Docker fails with AppArmor errors:

```bash
# On Proxmox host, edit LXC config
nano /etc/pve/lxc/200.conf

# Add:
lxc.apparmor.profile: unconfined
```

Restart container:
```bash
pct stop 200
pct start 200
```

---

## Step 6: Update Networking

### Update Traefik Routes

Edit `/opt/traefik/config/dynamic/services.yml`:
```yaml
services:
  glance:
    loadBalancer:
      servers:
        - url: "http://192.168.40.12:8080"  # New LXC IP
```

### Update DNS

Add/update Pi-hole DNS record:
```
glance.hrmsmrflrii.xyz → 192.168.40.20 (via Traefik)
```

---

## Full Tutorial

For complete step-by-step guide:
- **GitHub**: `docs/LXC_MIGRATION_TUTORIAL.md`

---

## Related Documentation

- [[02 - Proxmox Cluster]] - LXC configuration standards
- [[23 - Glance Dashboard]] - Glance-specific setup
- [[09 - Traefik Reverse Proxy]] - Route configuration
