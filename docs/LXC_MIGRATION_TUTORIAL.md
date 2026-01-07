# Migrating Docker Services from VM to LXC Container

A beginner-friendly guide to migrating Docker-based services from a Virtual Machine to an LXC container on Proxmox.

## Table of Contents

1. [What are LXC Containers?](#what-are-lxc-containers)
2. [Why Migrate from VM to LXC?](#why-migrate-from-vm-to-lxc)
3. [Prerequisites](#prerequisites)
4. [Step 1: Create the LXC Container](#step-1-create-the-lxc-container)
5. [Step 2: Configure LXC for Docker](#step-2-configure-lxc-for-docker)
6. [Step 3: Install Docker in the Container](#step-3-install-docker-in-the-container)
7. [Step 4: Migrate Your Services](#step-4-migrate-your-services)
8. [Step 5: Working Around AppArmor Issues](#step-5-working-around-apparmor-issues)
9. [Step 6: Update Networking/Routing](#step-6-update-networkingrouting)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

---

## What are LXC Containers?

**LXC (Linux Containers)** is an operating-system-level virtualization method that allows you to run multiple isolated Linux systems (containers) on a single host.

Think of it this way:
- **Virtual Machine (VM)**: Like running a complete separate computer inside your computer. It has its own operating system, kernel, and all the overhead that comes with it.
- **LXC Container**: Like having a separate apartment in a building. You share the building's foundation (the Linux kernel) but have your own private space.

### Key Differences

| Feature | VM | LXC Container |
|---------|-----|---------------|
| Boot Time | 30-60 seconds | 1-2 seconds |
| RAM Overhead | High (needs full OS) | Low (shares host kernel) |
| Disk Usage | Large (GB) | Small (MB to GB) |
| Isolation | Complete (separate kernel) | Process-level |
| Performance | Good | Near-native |

---

## Why Migrate from VM to LXC?

In this case study, we migrated a **Glance dashboard** with custom APIs from a VM to an LXC container for these reasons:

1. **Reduced Resource Usage**: The dashboard doesn't need a full VM's overhead
2. **Faster Restarts**: LXC containers start in seconds vs. minutes for VMs
3. **Isolation**: Keep the dashboard separate from other services (so updates don't take it down)
4. **Simplicity**: Lighter weight for a simple web dashboard

---

## Prerequisites

Before starting, ensure you have:

- [ ] Proxmox VE installed and accessible
- [ ] SSH access to the Proxmox host
- [ ] An Ubuntu/Debian container template downloaded
- [ ] Network configuration planned (IP address, VLAN if applicable)
- [ ] Backups of your current services

---

## Step 1: Create the LXC Container

### Via Proxmox Web UI

1. Log into Proxmox web interface (https://your-proxmox-ip:8006)
2. Click **Create CT** in the top right
3. Fill in the details:
   - **Node**: Select your target node
   - **CT ID**: Choose a unique ID (e.g., 200)
   - **Hostname**: Give it a name (e.g., `docker-lxc-glance`)
   - **Password**: Set a root password

4. **Template**: Select your Ubuntu template (e.g., `ubuntu-24.04-standard`)
5. **Disk**:
   - Storage: Choose local storage (NOT NFS - LXC requires local storage)
   - Size: 20GB is usually enough for Docker services
6. **CPU**: 2 cores
7. **Memory**: 4096 MB (4GB)
8. **Network**:
   - Bridge: vmbr0
   - IPv4: Static (e.g., 192.168.40.12/24)
   - Gateway: Your gateway (e.g., 192.168.40.1)
   - VLAN Tag: If using VLANs (e.g., 40)

### Via Command Line (SSH to Proxmox)

```bash
# Create the container
pct create 200 local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst \
  --hostname docker-lxc-glance \
  --cores 2 \
  --memory 4096 \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.40.12/24,gw=192.168.40.1,tag=40 \
  --features nesting=1,fuse=1 \
  --unprivileged 0 \
  --onboot 1

# Start the container
pct start 200
```

**Important flags explained:**
- `--features nesting=1,fuse=1`: Required for Docker to work inside LXC
- `--unprivileged 0`: Privileged container (needed for Docker)
- `--onboot 1`: Start automatically when Proxmox boots

---

## Step 2: Configure LXC for Docker

Docker inside LXC requires special configuration to work properly.

### Edit the Container Configuration

SSH into your Proxmox host and edit the container config:

```bash
# Stop the container first
pct stop 200

# Edit the configuration
nano /etc/pve/lxc/200.conf
```

Add these lines to enable Docker compatibility:

```
# Enable nesting and FUSE (if not already present)
features: nesting=1,fuse=1

# Disable AppArmor restrictions
lxc.apparmor.profile: unconfined

# Allow required capabilities
lxc.cap.drop:

# Required for Docker overlay filesystem
lxc.mount.auto: proc:rw sys:rw
```

### Start the Container

```bash
pct start 200
```

### Enter the Container

```bash
# Method 1: Via pct
pct enter 200

# Method 2: Via SSH (if SSH is configured)
ssh root@192.168.40.12
```

---

## Step 3: Install Docker in the Container

Once inside the container:

```bash
# Update the system
apt update && apt upgrade -y

# Install prerequisites
apt install -y ca-certificates curl gnupg

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify Docker is working
docker --version
docker run hello-world
```

If `docker run hello-world` fails, see the [Troubleshooting](#troubleshooting) section.

---

## Step 4: Migrate Your Services

### Create Directory Structure

```bash
# Create directories for your services
mkdir -p /opt/glance/config
mkdir -p /opt/glance/assets
mkdir -p /opt/media-stats-api
mkdir -p /opt/reddit-manager
mkdir -p /opt/nba-stats-api
```

### Copy Configuration Files

From your source machine (or backup), copy the configuration files:

```bash
# Example: Copy from another host via SCP
scp user@old-host:/opt/glance/config/glance.yml /opt/glance/config/
scp user@old-host:/opt/media-stats-api/media-stats-api.py /opt/media-stats-api/
```

### Update Configuration References

If your services reference other services by IP, update them to use `localhost`:

```bash
# Example: Update IP references in config files
sed -i 's/192.168.40.13/localhost/g' /opt/glance/config/glance.yml
```

---

## Step 5: Working Around AppArmor Issues

### The Problem

Docker inside LXC often fails with AppArmor errors:

```
Error response from daemon: failed to create shim task:
OCI runtime create failed: runc create failed:
unable to start container process: error during container init:
error running hook: apparmor_parser --replace
```

### The Solution

**Option A: Use `--security-opt apparmor=unconfined`**

Add this flag to all your docker run commands:

```bash
docker run -d \
  --name glance \
  --security-opt apparmor=unconfined \
  -p 8080:8080 \
  -v /opt/glance/config:/app/config \
  glanceapp/glance:latest
```

**Option B: Avoid Docker Builds**

Docker `build` commands often fail in LXC due to AppArmor. Instead:

1. Use pre-built images from Docker Hub
2. Mount your code as a volume
3. Install dependencies at runtime

**Before (fails in LXC):**
```dockerfile
FROM python:3.11-slim
COPY . /app
RUN pip install flask requests
CMD ["python", "/app/app.py"]
```

**After (works in LXC):**
```bash
docker run -d \
  --name my-api \
  --security-opt apparmor=unconfined \
  -p 5054:5054 \
  -v /opt/my-api:/app \
  -w /app \
  python:3.11-slim \
  sh -c 'pip install -q flask requests && python app.py'
```

### Deploy Your Services

Here's how we deployed the Glance stack:

```bash
# 1. Glance Dashboard
docker run -d \
  --name glance \
  --security-opt apparmor=unconfined \
  --restart unless-stopped \
  -p 8080:8080 \
  -v /opt/glance/config:/app/config \
  -v /opt/glance/assets:/app/assets:ro \
  glanceapp/glance:latest

# 2. Media Stats API
docker run -d \
  --name media-stats-api \
  --security-opt apparmor=unconfined \
  --restart unless-stopped \
  -p 5054:5054 \
  -v /opt/media-stats-api:/app \
  -w /app \
  python:3.11-slim \
  sh -c 'pip install -q flask requests flask-cors && python media-stats-api.py'

# 3. Reddit Manager
docker run -d \
  --name reddit-manager \
  --security-opt apparmor=unconfined \
  --restart unless-stopped \
  -p 5053:5053 \
  -v /opt/reddit-manager:/app \
  -w /app \
  python:3.11-slim \
  sh -c 'pip install -q flask requests && python reddit-manager.py'

# 4. NBA Stats API
docker run -d \
  --name nba-stats-api \
  --security-opt apparmor=unconfined \
  --restart unless-stopped \
  -p 5060:5060 \
  -v /opt/nba-stats-api:/app \
  -w /app \
  python:3.11-slim \
  sh -c 'pip install -q flask requests python-dateutil flask-cors pytz && python nba-stats-api.py'
```

---

## Step 6: Update Networking/Routing

### Update Reverse Proxy

If you use a reverse proxy (like Traefik), update the service URLs:

```yaml
# Before (pointing to old VM)
services:
  glance:
    loadBalancer:
      servers:
        - url: "http://192.168.40.12:8080"

# After (pointing to new LXC)
services:
  glance:
    loadBalancer:
      servers:
        - url: "http://192.168.40.12:8080"
```

### Update DNS (if applicable)

If your DNS points to the old IP, update it to the new LXC IP.

### Test Connectivity

```bash
# From outside the container
curl http://192.168.40.12:8080

# Verify the service responds
curl -I https://glance.yourdomain.com
```

---

## Troubleshooting

### Docker Won't Start

**Symptom**: `docker run` fails immediately

**Solution**: Ensure the LXC config has the correct features:

```bash
# Check config
cat /etc/pve/lxc/200.conf | grep -E "features|apparmor"

# Should show:
# features: nesting=1,fuse=1
# lxc.apparmor.profile: unconfined
```

### AppArmor Errors

**Symptom**: "apparmor_parser" errors when running containers

**Solution**: Add `--security-opt apparmor=unconfined` to your docker run command

### Docker Build Fails

**Symptom**: `docker build` hangs or fails

**Solution**: Don't use `docker build` in LXC. Use pre-built images with volume mounts instead.

### Network Issues

**Symptom**: Container can't reach the internet

**Solution**: Check:
1. Gateway is correct in `/etc/pve/lxc/200.conf`
2. DNS is configured: `cat /etc/resolv.conf`
3. If using VLANs, ensure the tag is correct

### Storage Issues

**Symptom**: "filesystem not supported" or disk errors

**Solution**: LXC containers must use local storage (like `local-lvm`), not NFS shares.

---

## Best Practices

1. **Always backup before migrating** - You can't undo a failed migration easily

2. **Test in isolation first** - Deploy to the new LXC while keeping the old VM running

3. **Use restart policies** - Add `--restart unless-stopped` to ensure services come back after reboot

4. **Keep configs in version control** - Store your glance.yml, docker-compose.yml, etc. in Git

5. **Document your commands** - Save the exact docker run commands you used

6. **Monitor after migration** - Check logs for errors: `docker logs <container-name>`

7. **Consider resource limits** - LXC supports memory/CPU limits in the Proxmox config

---

## Summary

Migrating from VM to LXC involves:

1. Creating an LXC container with Docker support (`nesting=1,fuse=1`)
2. Disabling AppArmor restrictions
3. Installing Docker
4. Copying your service files
5. Running containers with `--security-opt apparmor=unconfined`
6. Updating routing/DNS

The main challenges are AppArmor restrictions and the inability to use `docker build`. Work around these by using pre-built images and runtime dependency installation.

---

## Real-World Example: Our Migration

**What we migrated:**
- Glance Dashboard (port 8080)
- Media Stats API (port 5054)
- Reddit Manager (port 5053)
- NBA Stats API (port 5060)

**LXC Specs:**
- Container ID: 200
- Hostname: docker-lxc-glance
- IP: 192.168.40.12
- Node: node01
- RAM: 4GB
- Cores: 2
- Storage: 20GB on local-lvm

**Time taken:** About 2 hours (including troubleshooting AppArmor issues)

**Result:** Dashboard loads in < 1 second after LXC restart, compared to 30+ seconds for the old VM.

---

*Created: December 27, 2025*
*Based on migration of Glance stack from docker-utilities VM to LXC container*
