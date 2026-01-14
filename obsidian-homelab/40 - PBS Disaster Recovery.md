# PBS Disaster Recovery Guide

Complete guide to recover Proxmox Backup Server when both local drives fail.

---

## Overview

```
FAILED STATE:                          RECOVERY SOURCE:
┌─────────────┐                       ┌─────────────────────┐
│   PBS LXC   │  ← Both drives       │   Synology NAS      │
│   node03    │    failed            │   192.168.20.31     │
│   LXC 100   │    • 1TB NVMe        │   /pbs-offsite/     │
│             │    • 4TB HDD         │   • main/   (~20GB) │
└─────────────┘                       │   • daily/  (~38GB) │
                                      └─────────────────────┘
```

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **New drives installed** | Replace failed drives in node03 |
| **NAS accessible** | Synology NAS at 192.168.20.31 |
| **Backup data intact** | `/volume2/ProxmoxData/pbs-offsite/` exists |
| **SSH access** | Access to node03 (192.168.20.22) |
| **Network connectivity** | node03 can reach NAS |

---

## Recovery Phases

### Phase 1: Prepare New Storage

#### Step 1.1: SSH to node03

```bash
ssh root@192.168.20.22
```

#### Step 1.2: Identify new drives

```bash
# List all block devices
lsblk

# Check for new drives (look for unmounted devices)
fdisk -l | grep -E "^Disk /dev"
```

Expected output example:
```
Disk /dev/sda: 3.64 TiB    # New HDD for main datastore
Disk /dev/nvme1n1: 953 GiB  # New NVMe for daily datastore
```

#### Step 1.3: Partition and format drives

**For HDD (main datastore):**
```bash
# Create partition
parted /dev/sda mklabel gpt
parted /dev/sda mkpart primary ext4 0% 100%

# Format
mkfs.ext4 -L pbs-main /dev/sda1
```

**For NVMe (daily datastore):**
```bash
# Create partition
parted /dev/nvme1n1 mklabel gpt
parted /dev/nvme1n1 mkpart primary ext4 0% 100%

# Format
mkfs.ext4 -L pbs-daily /dev/nvme1n1p1
```

#### Step 1.4: Create mount points and mount drives

```bash
# Create mount points
mkdir -p /mnt/pbs-backup/datastore
mkdir -p /mnt/pbs-ssd/datastore

# Mount drives
mount /dev/sda1 /mnt/pbs-backup/datastore
mount /dev/nvme1n1p1 /mnt/pbs-ssd/datastore

# Verify mounts
df -h | grep pbs
```

#### Step 1.5: Add to fstab for persistence

```bash
# Get UUIDs
blkid /dev/sda1
blkid /dev/nvme1n1p1

# Add to fstab (replace UUIDs with actual values)
cat >> /etc/fstab << 'EOF'
UUID=<sda1-uuid>      /mnt/pbs-backup/datastore  ext4  defaults  0  2
UUID=<nvme1n1p1-uuid> /mnt/pbs-ssd/datastore     ext4  defaults  0  2
EOF
```

---

### Phase 2: Restore PBS Container

#### Step 2.1: Check if LXC 100 exists

```bash
pct list | grep 100
```

#### Step 2.2a: If LXC exists but is broken - Recreate it

```bash
# Stop and destroy old container
pct stop 100
pct destroy 100

# Download PBS template if needed
pveam update
pveam available | grep proxmox-backup
pveam download local proxmox-backup-server_3.4-1_amd64.tar.zst
```

#### Step 2.2b: Create new PBS container

```bash
# Create container
pct create 100 local:vztmpl/proxmox-backup-server_3.4-1_amd64.tar.zst \
    --hostname pbs-server \
    --memory 4096 \
    --cores 2 \
    --rootfs local-lvm:20 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.20.50/24,gw=192.168.20.1 \
    --features nesting=1 \
    --unprivileged 0

# Add mount points for datastores
pct set 100 -mp0 /mnt/pbs-backup/datastore,mp=/backup
pct set 100 -mp1 /mnt/pbs-ssd/datastore,mp=/backup-ssd
```

#### Step 2.3: Start container

```bash
pct start 100
```

---

### Phase 3: Restore Backup Data from NAS

#### Step 3.1: Install required packages in PBS container

```bash
pct exec 100 -- apt-get update
pct exec 100 -- apt-get install -y nfs-common rsync
```

#### Step 3.2: Mount NAS

```bash
pct exec 100 -- mkdir -p /mnt/nas-restore
pct exec 100 -- mount -t nfs 192.168.20.31:/volume2/ProxmoxData /mnt/nas-restore
```

#### Step 3.3: Verify backup data on NAS

```bash
pct exec 100 -- ls -la /mnt/nas-restore/pbs-offsite/
pct exec 100 -- du -sh /mnt/nas-restore/pbs-offsite/*
```

Expected output:
```
20G     /mnt/nas-restore/pbs-offsite/main
38G     /mnt/nas-restore/pbs-offsite/daily
```

#### Step 3.4: Restore main datastore

```bash
pct exec 100 -- rsync -avh --progress \
    /mnt/nas-restore/pbs-offsite/main/ \
    /backup/
```

**Estimated time:** ~10-20 minutes for 20GB

#### Step 3.5: Restore daily datastore

```bash
pct exec 100 -- rsync -avh --progress \
    /mnt/nas-restore/pbs-offsite/daily/ \
    /backup-ssd/
```

**Estimated time:** ~15-30 minutes for 38GB

#### Step 3.6: Set correct ownership

```bash
pct exec 100 -- chown -R backup:backup /backup
pct exec 100 -- chown -R backup:backup /backup-ssd
```

---

### Phase 4: Configure PBS

#### Step 4.1: Access PBS Web UI

Open browser: `https://192.168.20.50:8007`

Default credentials:
- Username: `root@pam`
- Password: (root password of container)

#### Step 4.2: Verify datastores

In PBS Web UI:
1. Go to **Datastore** section
2. Check that `main` and `daily` datastores appear
3. Verify backup contents are visible

If datastores don't appear, create them:

```bash
pct exec 100 -- proxmox-backup-manager datastore create main /backup
pct exec 100 -- proxmox-backup-manager datastore create daily /backup-ssd
```

#### Step 4.3: Recreate API token for Proxmox

```bash
pct exec 100 -- proxmox-backup-manager user create backup@pbs
pct exec 100 -- proxmox-backup-manager token create backup@pbs pve
```

Save the token output - you'll need it for Proxmox VE.

#### Step 4.4: Update Proxmox VE storage configuration

On a Proxmox node (node01/02/03):

```bash
# Edit storage configuration
nano /etc/pve/storage.cfg
```

Update the fingerprint and token if changed:
```
pbs: pbs-main
    datastore main
    server 192.168.20.50
    content backup
    fingerprint <new-fingerprint>
    username backup@pbs!pve
    password <new-token>

pbs: pbs-daily
    datastore daily
    server 192.168.20.50
    content backup
    fingerprint <new-fingerprint>
    username backup@pbs!pve
    password <new-token>
```

Get the new fingerprint:
```bash
pct exec 100 -- proxmox-backup-manager cert info | grep Fingerprint
```

---

### Phase 5: Restore NAS Sync Job

#### Step 5.1: Reinstall sync script

```bash
pct exec 100 -- tee /usr/local/bin/pbs-backup-to-nas.sh << 'SCRIPT'
#!/bin/bash
set -e

NAS_MOUNT="/mnt/nas-backup"
NAS_BACKUP_DIR="${NAS_MOUNT}/pbs-offsite"
LOG_FILE="/var/log/pbs-nas-backup.log"
LOCK_FILE="/var/run/pbs-nas-backup.lock"

MAIN_DATASTORE="/backup"
DAILY_DATASTORE="/backup-ssd"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

if [ -f "$LOCK_FILE" ]; then
    log "ERROR: Backup already running"
    exit 1
fi

trap "rm -f $LOCK_FILE" EXIT
touch "$LOCK_FILE"

log "========================================"
log "Starting PBS backup to NAS"
log "========================================"

if ! mountpoint -q "$NAS_MOUNT"; then
    log "NAS not mounted, attempting to mount..."
    mount -t nfs 192.168.20.31:/volume2/ProxmoxData "$NAS_MOUNT"
fi

if ! mountpoint -q "$NAS_MOUNT"; then
    log "ERROR: Failed to mount NAS"
    exit 1
fi

log "Syncing main datastore..."
rsync -avh --delete --no-owner --no-group --no-perms \
    --exclude=".lock" \
    "$MAIN_DATASTORE/" "$NAS_BACKUP_DIR/main/" 2>&1 | tail -20 | tee -a "$LOG_FILE"

log "Syncing daily datastore..."
rsync -avh --delete --no-owner --no-group --no-perms \
    --exclude=".lock" \
    "$DAILY_DATASTORE/" "$NAS_BACKUP_DIR/daily/" 2>&1 | tail -20 | tee -a "$LOG_FILE"

MAIN_SIZE=$(du -sh "$NAS_BACKUP_DIR/main" 2>/dev/null | cut -f1)
DAILY_SIZE=$(du -sh "$NAS_BACKUP_DIR/daily" 2>/dev/null | cut -f1)

log "========================================"
log "Backup completed successfully"
log "Main datastore on NAS: $MAIN_SIZE"
log "Daily datastore on NAS: $DAILY_SIZE"
log "========================================"
SCRIPT

pct exec 100 -- chmod +x /usr/local/bin/pbs-backup-to-nas.sh
```

#### Step 5.2: Configure NFS mount persistence

```bash
pct exec 100 -- mkdir -p /mnt/nas-backup
pct exec 100 -- bash -c 'grep -q "192.168.20.31:/volume2/ProxmoxData" /etc/fstab || echo "192.168.20.31:/volume2/ProxmoxData /mnt/nas-backup nfs defaults,_netdev 0 0" >> /etc/fstab'
```

#### Step 5.3: Restore cron job

```bash
pct exec 100 -- bash -c 'echo "0 2 * * * root /usr/local/bin/pbs-backup-to-nas.sh" > /etc/cron.d/pbs-nas-backup'
pct exec 100 -- chmod 644 /etc/cron.d/pbs-nas-backup
```

---

### Phase 6: Verification

#### Step 6.1: Verify PBS datastores

```bash
pct exec 100 -- proxmox-backup-manager datastore list
```

Expected output:
```
┌───────┬─────────────┬──────────────────────────────────────┐
│ name  │ path        │ comment                              │
├───────┼─────────────┼──────────────────────────────────────┤
│ daily │ /backup-ssd │                                      │
│ main  │ /backup     │                                      │
└───────┴─────────────┴──────────────────────────────────────┘
```

#### Step 6.2: Verify backup contents

```bash
# List backups in main datastore
pct exec 100 -- proxmox-backup-client list --repository backup@pbs@localhost:main

# List backups in daily datastore
pct exec 100 -- proxmox-backup-client list --repository backup@pbs@localhost:daily
```

#### Step 6.3: Test restore capability

From Proxmox VE UI:
1. Go to **Datacenter** → **Storage** → **pbs-main**
2. Click **Backups**
3. Verify backups are listed
4. Optionally test restore of a small VM/container

#### Step 6.4: Verify NAS sync

```bash
pct exec 100 -- /usr/local/bin/pbs-backup-to-nas.sh
pct exec 100 -- cat /var/log/pbs-nas-backup.log | tail -20
```

---

## Quick Recovery Commands

For experienced users, condensed command sequence:

```bash
# On node03 - Prepare storage
ssh root@192.168.20.22
parted /dev/sda mklabel gpt && parted /dev/sda mkpart primary ext4 0% 100%
parted /dev/nvme1n1 mklabel gpt && parted /dev/nvme1n1 mkpart primary ext4 0% 100%
mkfs.ext4 -L pbs-main /dev/sda1
mkfs.ext4 -L pbs-daily /dev/nvme1n1p1
mkdir -p /mnt/pbs-backup/datastore /mnt/pbs-ssd/datastore
mount /dev/sda1 /mnt/pbs-backup/datastore
mount /dev/nvme1n1p1 /mnt/pbs-ssd/datastore

# Create PBS container
pct create 100 local:vztmpl/proxmox-backup-server_3.4-1_amd64.tar.zst \
    --hostname pbs-server --memory 4096 --cores 2 --rootfs local-lvm:20 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.20.50/24,gw=192.168.20.1 \
    --features nesting=1 --unprivileged 0
pct set 100 -mp0 /mnt/pbs-backup/datastore,mp=/backup
pct set 100 -mp1 /mnt/pbs-ssd/datastore,mp=/backup-ssd
pct start 100

# Restore data
pct exec 100 -- apt-get update && apt-get install -y nfs-common rsync
pct exec 100 -- mkdir -p /mnt/nas-restore
pct exec 100 -- mount -t nfs 192.168.20.31:/volume2/ProxmoxData /mnt/nas-restore
pct exec 100 -- rsync -avh /mnt/nas-restore/pbs-offsite/main/ /backup/
pct exec 100 -- rsync -avh /mnt/nas-restore/pbs-offsite/daily/ /backup-ssd/
pct exec 100 -- chown -R backup:backup /backup /backup-ssd
```

---

## Troubleshooting

### Datastores not visible in PBS

```bash
# Recreate datastores
pct exec 100 -- proxmox-backup-manager datastore create main /backup
pct exec 100 -- proxmox-backup-manager datastore create daily /backup-ssd
```

### Permission denied on backup files

```bash
# Fix ownership
pct exec 100 -- chown -R backup:backup /backup
pct exec 100 -- chown -R backup:backup /backup-ssd
```

### Proxmox VE can't connect to PBS

1. Check PBS is running: `pct exec 100 -- systemctl status proxmox-backup`
2. Check fingerprint matches in `/etc/pve/storage.cfg`
3. Recreate API token if needed

### NAS mount fails

```bash
# Check NAS connectivity
ping 192.168.20.31

# Check NFS exports
showmount -e 192.168.20.31

# Mount manually with verbose
mount -v -t nfs 192.168.20.31:/volume2/ProxmoxData /mnt/nas-restore
```

---

## Recovery Time Estimates

| Phase | Duration |
|-------|----------|
| Phase 1: Prepare Storage | 15-30 min |
| Phase 2: Restore PBS Container | 5-10 min |
| Phase 3: Restore Data | 30-60 min (for ~58GB) |
| Phase 4: Configure PBS | 10-15 min |
| Phase 5: Restore Sync Job | 5 min |
| Phase 6: Verification | 10-15 min |
| **Total** | **~1.5-2.5 hours** |

---

## Post-Recovery Checklist

- [ ] Both datastores visible in PBS UI
- [ ] All backups listed and accessible
- [ ] Proxmox VE can connect to PBS
- [ ] Test restore of at least one VM/CT
- [ ] NAS sync job configured and tested
- [ ] Cron job running at 2 AM daily
- [ ] fstab entries added for drives
- [ ] Monitoring working (Grafana dashboard shows PBS)

---

## Related Documentation

- [[39 - PBS Deployment Tutorial]] - Initial PBS setup
- [[23 - PBS Monitoring]] - Monitoring configuration
- [[03 - Storage Architecture]] - Storage overview
- [[02 - Proxmox Cluster]] - Proxmox documentation

---

*Last updated: January 12, 2026*
