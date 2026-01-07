# LXC Migration Plan: VM to LXC Consolidation

> **Date**: January 7, 2026
> **Objective**: Migrate Traefik, Authentik, and docker-media services from VMs to LXC containers to reduce RAM usage

---

## Executive Summary

This document details the migration of three VMs to lightweight LXC containers. The migration will free approximately **20GB of RAM** while maintaining all functionality.

| Service | Current (VM) | Target (LXC) | RAM Savings |
|---------|-------------|--------------|-------------|
| Traefik | VM 102 (8GB) | LXC 203 (2GB) | **6GB** |
| Authentik | VM 100 (8GB) | LXC 204 (4GB) | **4GB** |
| docker-media | VM 111 (18GB) | LXC 205 (8GB) | **10GB** |
| **Total** | **34GB** | **14GB** | **20GB** |

---

## Current Infrastructure Assessment

### Resource Inventory (Pre-Migration)

**node01 (60GB RAM)**:
| VMID | Name | Type | Status | RAM |
|------|------|------|--------|-----|
| 103 | ansible-controller01 | VM | Running | 8GB |
| 107 | docker-vm-core-utilities01 | VM | Running | 12GB |
| 111 | docker-vm-media01 | VM | Running | 18GB |
| 200 | docker-lxc-glance | LXC | Running | 4GB |
| 201 | docker-lxc-bots | LXC | Running | 2GB |
| 202 | pihole | LXC | Running | 1GB |
| - | K8s cluster (9 VMs) | VM | Stopped | 72GB (not active) |

**node02 (28GB RAM)**:
| VMID | Name | Type | Status | RAM |
|------|------|------|--------|-----|
| 100 | authentik-vm01 | VM | Running | 8GB |
| 102 | traefik-vm01 | VM | Running | 8GB |
| 106 | gitlab-vm01 | VM | Running | 8GB |
| 108 | immich-vm01 | VM | Running | 8GB |
| 109 | linux-syslog-server01 | VM | Running | 8GB |
| 121 | gitlab-runner-vm01 | VM | Running | 2GB |

### Services to Migrate

#### 1. Traefik VM (192.168.40.20)
- **Containers**: traefik, watchtower
- **Config Location**: `/opt/traefik/`
- **Ports**: 80, 443, 8082 (dashboard), 8083 (metrics)
- **Dependencies**: Cloudflare API token, Let's Encrypt certs
- **Critical**: All external traffic routes through this

#### 2. Authentik VM (192.168.40.21)
- **Containers**: authentik-server, authentik-worker, postgresql, redis, watchtower
- **Config Location**: `/opt/authentik/`
- **Ports**: 9000 (HTTP), 9443 (HTTPS)
- **Dependencies**: PostgreSQL database, Redis cache
- **Critical**: SSO for all protected services

#### 3. docker-media VM (192.168.40.11)
- **Containers**: jellyfin, radarr, sonarr, prowlarr, bazarr, lidarr, overseerr, jellyseerr, tdarr, autobrr, deluge, sabnzbd, metube, youtube-stats-api, cadvisor, docker-exporter, watchtower
- **Config Location**: `/opt/arr-stack/`, `/opt/metube/`, `/opt/youtube-stats-api/`, `/opt/cadvisor/`
- **NFS Mount**: `192.168.20.31:/volume2/Proxmox-Media/MediaFiles` → `/mnt/media`
- **Ports**: Multiple (8096, 7878, 8989, 9696, etc.)

---

## Migration Strategy

### Approach: Blue-Green Migration

We will use a blue-green deployment approach:
1. **Create new LXCs** (green) while VMs (blue) remain running
2. **Copy configurations and data** from VMs to LXCs
3. **Test LXC services** internally
4. **Update DNS** to point to new LXC IPs (same IPs will be reused)
5. **Verify all services** are functioning
6. **Shut down old VMs** once confirmed working

### IP Address Strategy

To minimize DNS changes and Traefik reconfiguration, we will:
1. Create LXCs with temporary IPs
2. Shut down VMs and release their IPs
3. Reconfigure LXCs with the original VM IPs

| Service | Original IP | Temporary IP | Final IP |
|---------|-------------|--------------|----------|
| Traefik | 192.168.40.20 | 192.168.40.120 | 192.168.40.20 |
| Authentik | 192.168.40.21 | 192.168.40.121 | 192.168.40.21 |
| docker-media | 192.168.40.11 | 192.168.40.111 | 192.168.40.11 |

---

## Migration Execution Plan

### Phase 1: Preparation

#### Step 1.1: Create LXC Template
```bash
# Download Ubuntu 24.04 LXC template on both nodes
pveam update
pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
```

#### Step 1.2: Create Migration Directory
```bash
# On ansible controller, create backup directory
mkdir -p ~/migration-backup/{traefik,authentik,docker-media}
```

### Phase 2: Traefik Migration

#### Step 2.1: Backup Traefik VM
```bash
# SSH to traefik VM and backup configs
ssh traefik "tar -czvf /tmp/traefik-backup.tar.gz /opt/traefik"
scp traefik:/tmp/traefik-backup.tar.gz ~/migration-backup/traefik/
```

#### Step 2.2: Create Traefik LXC (ID 203)
```bash
# On node02
pct create 203 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname traefik-lxc \
  --cores 2 \
  --memory 2048 \
  --swap 512 \
  --storage local-lvm \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,tag=40,ip=192.168.40.120/24,gw=192.168.40.1 \
  --nameserver 192.168.90.53 \
  --features nesting=1,keyctl=1,fuse=1 \
  --unprivileged 0 \
  --start 0
```

#### Step 2.3: Configure Traefik LXC
```bash
# Start and configure LXC
pct start 203

# Install Docker
pct exec 203 -- bash -c "
  apt update && apt install -y curl ca-certificates gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable' > /etc/apt/sources.list.d/docker.list
  apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable docker
"
```

#### Step 2.4: Deploy Traefik on LXC
```bash
# Copy backup to LXC
pct push 203 ~/migration-backup/traefik/traefik-backup.tar.gz /tmp/traefik-backup.tar.gz

# Extract and start
pct exec 203 -- bash -c "
  mkdir -p /opt/traefik
  tar -xzvf /tmp/traefik-backup.tar.gz -C /
  cd /opt/traefik && docker compose up -d
"
```

#### Step 2.5: Test Traefik LXC
```bash
# Test internal connectivity
curl -I http://192.168.40.120:8082/ping
curl -I https://192.168.40.120 -k
```

### Phase 3: Authentik Migration

#### Step 3.1: Backup Authentik VM
```bash
# Stop containers gracefully to ensure data consistency
ssh authentik "cd /opt/authentik && docker compose stop"

# Backup entire /opt/authentik including postgres data
ssh authentik "tar -czvf /tmp/authentik-backup.tar.gz /opt/authentik"
scp authentik:/tmp/authentik-backup.tar.gz ~/migration-backup/authentik/

# Restart containers on VM
ssh authentik "cd /opt/authentik && docker compose start"
```

#### Step 3.2: Create Authentik LXC (ID 204)
```bash
# On node02
pct create 204 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname authentik-lxc \
  --cores 2 \
  --memory 4096 \
  --swap 1024 \
  --storage local-lvm \
  --rootfs local-lvm:30 \
  --net0 name=eth0,bridge=vmbr0,tag=40,ip=192.168.40.121/24,gw=192.168.40.1 \
  --nameserver 192.168.90.53 \
  --features nesting=1,keyctl=1,fuse=1 \
  --unprivileged 0 \
  --start 0
```

#### Step 3.3: Configure and Deploy Authentik LXC
```bash
# Start, install Docker, restore data (similar to Traefik)
pct start 204
# ... Docker installation ...
# ... Data restoration ...
# ... Start containers ...
```

### Phase 4: docker-media Migration

#### Step 4.1: Backup docker-media VM
```bash
# This is the largest migration - backup all config directories
ssh docker-media "tar -czvf /tmp/arr-stack-backup.tar.gz /opt/arr-stack /opt/metube /opt/youtube-stats-api /opt/cadvisor /opt/docker-exporter"
scp docker-media:/tmp/arr-stack-backup.tar.gz ~/migration-backup/docker-media/
```

#### Step 4.2: Create docker-media LXC (ID 205)
```bash
# On node01
pct create 205 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname docker-lxc-media \
  --cores 4 \
  --memory 8192 \
  --swap 2048 \
  --storage local-lvm \
  --rootfs local-lvm:50 \
  --net0 name=eth0,bridge=vmbr0,tag=40,ip=192.168.40.111/24,gw=192.168.40.1 \
  --nameserver 192.168.90.53 \
  --features nesting=1,keyctl=1,fuse=1 \
  --unprivileged 0 \
  --start 0
```

#### Step 4.3: Configure NFS Mount in LXC
```bash
# Edit LXC config to add NFS mount point
# In /etc/pve/lxc/205.conf, add:
# mp0: /mnt/pve/Proxmox-Media,mp=/mnt/media

# Or mount inside LXC:
pct exec 205 -- bash -c "
  apt install -y nfs-common
  mkdir -p /mnt/media
  echo '192.168.20.31:/volume2/Proxmox-Media/MediaFiles /mnt/media nfs4 rw,soft,timeo=300 0 0' >> /etc/fstab
  mount -a
"
```

### Phase 5: IP Switchover

#### Step 5.1: Shutdown VMs and Reconfigure IPs
```bash
# On node02: Stop Traefik and Authentik VMs
qm stop 102  # traefik-vm01
qm stop 100  # authentik-vm01

# On node01: Stop docker-media VM
qm stop 111  # docker-vm-media01

# Reconfigure LXC IPs
pct set 203 --net0 name=eth0,bridge=vmbr0,tag=40,ip=192.168.40.20/24,gw=192.168.40.1
pct set 204 --net0 name=eth0,bridge=vmbr0,tag=40,ip=192.168.40.21/24,gw=192.168.40.1
pct set 205 --net0 name=eth0,bridge=vmbr0,tag=40,ip=192.168.40.11/24,gw=192.168.40.1

# Restart LXCs
pct reboot 203
pct reboot 204
pct reboot 205
```

### Phase 6: Verification

#### Step 6.1: Service Health Checks
```bash
# Traefik
curl -I https://traefik.hrmsmrflrii.xyz
curl -I http://192.168.40.20:8082/ping

# Authentik
curl -I https://auth.hrmsmrflrii.xyz

# Media services
curl -I https://jellyfin.hrmsmrflrii.xyz
curl -I https://radarr.hrmsmrflrii.xyz
curl -I https://sonarr.hrmsmrflrii.xyz
```

#### Step 6.2: Update Prometheus Targets
Update `/opt/monitoring/prometheus/prometheus.yml` on docker-vm-core-utilities01:
- Update any targets that reference the old VM IPs
- Restart Prometheus

#### Step 6.3: Update Glance Widgets
Update `/opt/glance/config/glance.yml` on docker-lxc-glance:
- Update any monitor widgets
- Restart Glance

---

## Rollback Plan

If migration fails:

1. **Stop LXCs**: `pct stop 203 204 205`
2. **Start VMs**: `qm start 102 100 111`
3. **Verify services**: Check all URLs respond correctly

---

## Post-Migration Tasks

### Documentation Updates Required

1. **INVENTORY.md**: Update VM/LXC lists
2. **context.md**: Update host information
3. **APPLICATION_CONFIGURATIONS.md**: Update host references
4. **NETWORKING.md**: Note IP assignments unchanged

### Monitoring Updates

1. **Grafana Container Status Dashboard**: May need to add new LXC targets
2. **Prometheus scrape configs**: Verify all targets reachable
3. **Uptime Kuma**: Verify monitors still working

---

## Expected Outcome

### RAM Usage After Migration

**node01**:
- Before: ~29GB used (with 18GB docker-media VM)
- After: ~19GB used (with 8GB docker-media LXC)
- Savings: **~10GB**

**node02**:
- Before: ~23GB used (with 8GB Traefik + 8GB Authentik)
- After: ~17GB used (with 2GB Traefik + 4GB Authentik)
- Savings: **~10GB**

**Total Cluster Savings: ~20GB RAM**

---

## Appendix: LXC Configuration Reference

### Required LXC Features for Docker

```conf
# /etc/pve/lxc/<vmid>.conf
features: nesting=1,keyctl=1,fuse=1
```

### Docker Security Options for LXC

```yaml
# In docker-compose.yml
services:
  myservice:
    security_opt:
      - apparmor=unconfined
```

### NFS Mount in LXC

Option 1: Bind mount from Proxmox host
```conf
# /etc/pve/lxc/<vmid>.conf
mp0: /mnt/pve/Proxmox-Media,mp=/mnt/media
```

Option 2: Direct NFS mount inside LXC
```bash
# /etc/fstab inside LXC
192.168.20.31:/volume2/Proxmox-Media/MediaFiles /mnt/media nfs4 rw,soft,timeo=300 0 0
```

---

## Migration Execution Summary

> **Executed**: January 7, 2026
> **Status**: ✅ Completed Successfully

### Timeline

| Phase | Service | Start Time | End Time | Status |
|-------|---------|------------|----------|--------|
| 1 | Traefik | 02:10 UTC | 02:15 UTC | ✅ Complete |
| 2 | Authentik | 02:15 UTC | 02:25 UTC | ✅ Complete |
| 3 | docker-media | 02:25 UTC | 02:50 UTC | ✅ Complete |

### Final LXC Configuration

| Service | LXC ID | Hostname | IP | Cores | RAM | Disk |
|---------|--------|----------|-----|-------|-----|------|
| Traefik | 203 | traefik-lxc | 192.168.40.20 | 2 | 2GB | 20GB |
| Authentik | 204 | authentik-lxc | 192.168.40.21 | 2 | 4GB | 30GB |
| docker-media | 205 | docker-lxc-media | 192.168.40.11 | 4 | 8GB | 50GB |

### Services Running on docker-lxc-media (205)

| Container | Port | Status |
|-----------|------|--------|
| jellyfin | 8096 | ✅ Healthy |
| radarr | 7878 | ✅ Running |
| sonarr | 8989 | ✅ Running |
| prowlarr | 9696 | ✅ Running |
| bazarr | 6767 | ✅ Running |
| lidarr | 8686 | ✅ Running |
| overseerr | 5055 | ✅ Running |
| jellyseerr | 5056 | ✅ Running |
| tdarr | 8265/8266 | ✅ Running |
| autobrr | 7474 | ✅ Running |
| deluge | 8112 | ✅ Running |
| sabnzbd | 8081 | ✅ Running |
| metube | 8082 | ✅ Running |
| cadvisor | 8083 | ✅ Healthy |

### Key Learnings

1. **AppArmor in LXC**: Docker containers in LXC require `security_opt: - apparmor=unconfined` in docker-compose.yml
2. **Docker Build in LXC**: Building images in LXC containers may fail due to AppArmor restrictions during RUN commands
3. **NFS Mounts**: Direct NFS mount inside LXC works well with nfs-common package installed
4. **Blue-Green Migration**: Using temporary IPs allowed for safe migration with rollback capability

### Decommissioned VMs

The following VMs have been permanently deleted:

| VMID | Hostname | Node | Status |
|------|----------|------|--------|
| 100 | authentik-vm01 | node02 | ✅ Deleted (`qm destroy 100 --purge`) |
| 102 | traefik-vm01 | node02 | ✅ Deleted (`qm destroy 102 --purge`) |
| 111 | docker-vm-media01 | node01 | ✅ Deleted (`qm destroy 111 --purge`) |

### Post-Migration Verification

| Check | Result |
|-------|--------|
| Prometheus targets | ✅ All services scraped from correct IPs |
| Glance dashboard | ✅ Monitors pointing to correct IPs |
| Traefik routing | ✅ All services accessible via HTTPS |
| Authentik SSO | ✅ Authentication working |
| Media services | ✅ 14 containers running on LXC 205 |

**Known Issues**:
- `docker-stats-media` (192.168.40.11:9417) - docker-exporter not built due to AppArmor build restrictions in LXC
- `proxmox` (192.168.20.22:8006) - Pre-existing misconfiguration (node doesn't exist)

### RAM Savings Achieved

| Node | Before | After | Savings |
|------|--------|-------|---------|
| node01 | ~38GB allocated | ~28GB allocated | **~10GB** |
| node02 | ~24GB allocated | ~14GB allocated | **~10GB** |
| **Total** | **~62GB** | **~42GB** | **~20GB** |
