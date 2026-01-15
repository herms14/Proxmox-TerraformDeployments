# Proxmox Backup Server (PBS) Deployment Guide

> Part of the [Proxmox Infrastructure Documentation](../CLAUDE.md)

## Overview

This document details the complete deployment of Proxmox Backup Server as an LXC container on node03, with dual-datastore configuration for tiered backup strategy.

## Architecture

```
node03 (192.168.20.22)
├── Physical Storage
│   ├── /dev/sda (Seagate 4TB HDD) → /mnt/pbs-backup
│   └── /dev/nvme0n1 (Kingston 1TB NVMe) → /mnt/pbs-ssd
│
└── PBS LXC (VMID 100, IP: 192.168.20.50)
    ├── /backup (bind mount from /mnt/pbs-backup/datastore)
    │   └── Datastore: main (3.4TB)
    └── /backup-ssd (bind mount from /mnt/pbs-ssd/datastore)
        └── Datastore: daily (870GB)
```

## Deployment Steps

### Step 1: Prepare Physical Storage

#### 4TB HDD (Main Datastore)

```bash
# Wipe existing partitions
wipefs -a /dev/sda

# Create GPT partition table
parted /dev/sda --script mklabel gpt
parted /dev/sda --script mkpart primary ext4 0% 100%

# Format with ext4
mkfs.ext4 -L pbs-backup /dev/sda1

# Create mount point and mount
mkdir -p /mnt/pbs-backup
mount /dev/sda1 /mnt/pbs-backup

# Add to fstab for persistence
echo 'UUID=<uuid> /mnt/pbs-backup ext4 defaults 0 2' >> /etc/fstab
```

#### 1TB NVMe SSD (Daily Datastore)

```bash
# Wipe existing partitions (was Windows NTFS)
wipefs -a /dev/nvme0n1

# Create GPT partition table
parted /dev/nvme0n1 --script mklabel gpt
parted /dev/nvme0n1 --script mkpart primary ext4 0% 100%

# Format with ext4
mkfs.ext4 -L pbs-ssd /dev/nvme0n1p1

# Create mount point and mount
mkdir -p /mnt/pbs-ssd
mount /dev/nvme0n1p1 /mnt/pbs-ssd

# Add to fstab for persistence
echo 'UUID=<uuid> /mnt/pbs-ssd ext4 defaults 0 2' >> /etc/fstab
```

### Step 2: Download LXC Template

```bash
# Update template list
pveam update

# Download Debian 12 template
pveam download local debian-12-standard_12.12-1_amd64.tar.zst
```

### Step 3: Create PBS LXC Container

```bash
pct create 100 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname pbs-server \
  --cores 2 \
  --memory 4096 \
  --swap 512 \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.20.50/24,gw=192.168.20.1 \
  --nameserver '8.8.8.8 8.8.4.4' \
  --searchdomain hrmsmrflrii.xyz \
  --features nesting=1 \
  --unprivileged 0 \
  --start 0
```

### Step 4: Configure Bind Mounts

```bash
# Create datastore directories on host
mkdir -p /mnt/pbs-backup/datastore
mkdir -p /mnt/pbs-ssd/datastore

# Add bind mounts to container
pct set 100 -mp0 /mnt/pbs-backup/datastore,mp=/backup
pct set 100 -mp1 /mnt/pbs-ssd/datastore,mp=/backup-ssd

# Start container
pct start 100
```

### Step 5: Install PBS Inside Container

```bash
# Enter container
pct exec 100 -- bash

# Update packages
apt-get update

# Add Proxmox GPG key
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg \
  -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

# Add PBS repository
echo "deb http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription" \
  > /etc/apt/sources.list.d/pbs.list

# Update and install PBS
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-backup-server
```

### Step 6: Create Datastores

```bash
# Create main datastore (HDD)
proxmox-backup-manager datastore create main /backup \
  --comment 'Main backup datastore - 4TB HDD'

# Create daily datastore (SSD)
proxmox-backup-manager datastore create daily /backup-ssd \
  --comment 'Daily backups - Kingston NVMe SSD 1TB'
```

### Step 7: Configure Users and Permissions

```bash
# Set root password
passwd root

# Create backup user for PVE integration
proxmox-backup-manager user create backup@pbs \
  --password backup123temp \
  --comment 'PVE backup user'

# Generate API token
proxmox-backup-manager user generate-token backup@pbs pve \
  --comment 'PVE integration token'
# Output: tokenid: backup@pbs!pve, value: <token-secret>

# Add root-level Audit permission (to list datastores)
proxmox-backup-manager acl update / Audit --auth-id backup@pbs!pve

# Add DatastoreAdmin permission for main datastore
proxmox-backup-manager acl update /datastore/main DatastoreAdmin --auth-id backup@pbs!pve

# Add DatastoreAdmin permission for daily datastore
proxmox-backup-manager acl update /datastore/daily DatastoreAdmin --auth-id backup@pbs!pve
```

### Step 8: Verify Permissions

```bash
# List all ACLs
proxmox-backup-manager acl list

# Expected output:
# +================+=================+===========+=================+
# | ugid           | path            | propagate | roleid          |
# +================+=================+===========+=================+
# | backup@pbs!pve | /               |         1 | Audit           |
# | backup@pbs!pve | /datastore/main |         1 | DatastoreAdmin  |
# | backup@pbs!pve | /datastore/daily|         1 | DatastoreAdmin  |
# +================+=================+===========+=================+

# Verify token permissions
proxmox-backup-manager user permissions backup@pbs!pve
```

### Step 9: Get Certificate Fingerprint

```bash
proxmox-backup-manager cert info 2>/dev/null | grep -A1 'Fingerprint'
# Output: Fingerprint (sha256): 32:27:42:d5:...
```

## Adding PBS to Proxmox VE

### Add Main Datastore (HDD)

1. Go to **Datacenter → Storage → Add → Proxmox Backup Server**
2. Configure:

| Field | Value |
|-------|-------|
| ID | `pbs-main` |
| Server | `192.168.20.50` |
| Username | `backup@pbs!pve` |
| Password | `<token-secret>` |
| Datastore | `main` |
| Fingerprint | `32:27:42:d5:ab:7e:41:ef:80:17:ea:30:b8:43:9a:f3:59:af:60:f5:6b:05:ea:1f:28:30:ff:7f:19:b6:d4:55` |

### Add Daily Datastore (SSD)

Repeat with:

| Field | Value |
|-------|-------|
| ID | `pbs-daily` |
| Datastore | `daily` |

## LXC Configuration Reference

Final `/etc/pve/lxc/100.conf`:

```
arch: amd64
cores: 2
features: nesting=1
hostname: pbs-server
memory: 4096
mp0: /mnt/pbs-backup/datastore,mp=/backup
mp1: /mnt/pbs-ssd/datastore,mp=/backup-ssd
nameserver: 8.8.8.8 8.8.4.4
net0: name=eth0,bridge=vmbr0,gw=192.168.20.1,ip=192.168.20.50/24,type=veth
ostype: debian
rootfs: local-lvm:vm-100-disk-0,size=20G
searchdomain: hrmsmrflrii.xyz
swap: 512
```

## Credentials Summary

| Access | Value |
|--------|-------|
| **Web UI** | https://192.168.20.50:8007 |
| **Root User** | `root@pam` |
| **Root Password** | `PBSr00t@2025!` |
| **API Token ID** | `backup@pbs!pve` |
| **API Token Secret** | `cae1be63-f700-4af6-9419-198f7cdf0330` |
| **Fingerprint** | `32:27:42:d5:ab:7e:41:ef:80:17:ea:30:b8:43:9a:f3:59:af:60:f5:6b:05:ea:1f:28:30:ff:7f:19:b6:d4:55` |

> **Login Note**: In the web UI, enter `root` in the username field (not `root@pam`). The realm dropdown adds the `@pam` suffix automatically.

## Remove Subscription Nag (Optional)

To remove the "No valid subscription" popup:

```bash
# SSH to node03 and enter PBS container
pct exec 100 -- bash

# Patch the subscription check
perl -i.bak -pe 's/res.status.toLowerCase\(\) !== .active./false/g' \
  /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Restart the proxy
systemctl restart proxmox-backup-proxy
```

**Note**: This patch may need to be reapplied after PBS updates.

## Recommended Backup Jobs

Create these backup jobs in **Datacenter → Backup → Add**:

| Job Name | Storage | Schedule | Selection | Mode | Retention |
|----------|---------|----------|-----------|------|-----------|
| Critical Daily | pbs-daily | Daily 02:00 | Traefik, Authentik, Glance, Grafana | Snapshot | Keep Last: 7 |
| Services Daily | pbs-daily | Daily 03:00 | GitLab, Immich, Pi-hole | Snapshot | Keep Last: 7 |
| Weekly Archive | pbs-main | Sun 04:00 | All | Snapshot | Keep Weekly: 4, Keep Monthly: 2 |

## Troubleshooting

### "Cannot find datastore" Error

This occurs when the API token lacks proper permissions. Fix:

```bash
# Add root-level Audit (required to list datastores)
proxmox-backup-manager acl update / Audit --auth-id backup@pbs!pve

# Add DatastoreAdmin for each datastore
proxmox-backup-manager acl update /datastore/main DatastoreAdmin --auth-id backup@pbs!pve
proxmox-backup-manager acl update /datastore/daily DatastoreAdmin --auth-id backup@pbs!pve
```

### Container Network Issues

If the container can't reach the internet:

1. Check if VLAN tagging is needed (vmbr0 configuration on node03)
2. If bridge is already on VLAN 20 natively, remove VLAN tag from container:
   ```bash
   pct set 100 --net0 name=eth0,bridge=vmbr0,ip=192.168.20.50/24,gw=192.168.20.1
   ```

### Verify PBS Services

```bash
# Check PBS services
pct exec 100 -- systemctl status proxmox-backup-proxy
pct exec 100 -- systemctl status proxmox-backup

# List datastores
pct exec 100 -- proxmox-backup-manager datastore list
```

## Related Documentation

- [Storage](./STORAGE.md) - Storage architecture
- [Proxmox](./PROXMOX.md) - Cluster configuration
- [Inventory](./INVENTORY.md) - Deployed infrastructure
