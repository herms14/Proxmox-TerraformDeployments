# Immich Backup and Restore Guide

Complete guide to backing up and restoring Immich photo management system, including VM-level and application-level backup strategies.

---

## Overview

```
IMMICH BACKUP ARCHITECTURE
==========================

┌─────────────────────────────────────────────────────────────────────────┐
│                         Immich VM (192.168.40.22)                       │
│                              immich-vm01                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  LOCAL STORAGE (/opt/immich)           NFS STORAGE (Synology NAS)       │
│  ├── docker-compose.yml                /mnt/immich-uploads/             │
│  ├── .secrets                          ├── upload/                      │
│  ├── postgres/    ◄── DB Data          ├── thumbs/                      │
│  └── model-cache/ ◄── ML Models        ├── library/                     │
│                                        ├── encoded-video/               │
│                                        └── db-backups/ ◄── DB Dumps     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                    │                              │
                    ▼                              ▼
┌────────────────────────────┐    ┌────────────────────────────────────┐
│     PBS VM-Level Backup    │    │   Application-Level DB Backup      │
│   (Daily @ 03:00)          │    │   (Daily @ 02:30)                  │
│                            │    │                                    │
│   Captures:                │    │   Captures:                        │
│   • Full VM disk           │    │   • PostgreSQL database dump       │
│   • Docker volumes         │    │   • All Immich metadata            │
│   • Local config           │    │   • User accounts, albums, faces   │
│                            │    │                                    │
│   Storage: pbs-daily (SSD) │    │   Storage: NAS (/Immich Photos/)   │
│   Retention: 7 days        │    │   Retention: 7 days                │
└────────────────────────────┘    └────────────────────────────────────┘
```

---

## Backup Strategy Summary

| Component | Backup Method | Schedule | Location | Retention |
|-----------|---------------|----------|----------|-----------|
| **Immich VM** | PBS Snapshot | 03:00 daily | pbs-daily (NVMe) | 7 days |
| **PostgreSQL DB** | pg_dumpall | 02:30 daily | NAS `/db-backups/` | 7 days |
| **Photos (Active)** | Synology Hyper Backup | User configured | Cloud (B2/S3) | User defined |
| **Photos (Legacy)** | Already on NAS | N/A | Synology NAS | Permanent |

---

## Prerequisites

| Requirement | Current Value | Purpose |
|-------------|---------------|---------|
| Immich VM IP | 192.168.40.22 | Target host |
| PBS Server | 192.168.20.50 | VM-level backups |
| Synology NAS | 192.168.20.31 | Photo storage + DB dumps |
| SSH Access | `hermes-admin@192.168.40.22` | Admin access |
| Ansible Controller | 192.168.20.30 | Playbook execution |

---

## Part 1: VM-Level Backup (PBS)

### Current Configuration

Immich is included in the **Services Daily** backup job.

| Setting | Value |
|---------|-------|
| Job Name | Services Daily |
| Schedule | Daily 03:00 |
| Storage | pbs-daily (NVMe SSD) |
| Retention | Keep Last: 7 |
| Mode | Snapshot |

### Verify PBS Backup

```bash
# From any Proxmox node
ssh root@192.168.20.20

# List backups for Immich VM
pvesh get /nodes/node01/storage/pbs-daily/content --vmid 115

# Or from PBS directly
ssh root@192.168.20.50
proxmox-backup-client list --repository backup@pbs@localhost:daily | grep vm/115
```

### VM-Level Restore Procedure

#### Quick Restore (Recommended)

1. **Access Proxmox Web UI**: https://proxmox.hrmsmrflrii.xyz
2. Navigate to **Datacenter** → **Storage** → **pbs-daily**
3. Click **Backups** tab
4. Find `vm/115` (Immich VM)
5. Select desired backup date
6. Click **Restore**
7. Choose restore options:
   - **Target Storage**: local-lvm
   - **Unique**: Check if restoring alongside existing VM
8. Click **Restore**

#### Command Line Restore

```bash
# SSH to Proxmox node
ssh root@192.168.20.20

# List available backups
pvesh get /nodes/node01/storage/pbs-daily/content --vmid 115

# Restore VM (this will overwrite existing VM 115)
qmrestore pbs-daily:backup/vm/115/2026-01-14T03:00:00Z 115 --storage local-lvm

# Or restore as new VM with different ID
qmrestore pbs-daily:backup/vm/115/2026-01-14T03:00:00Z 200 --storage local-lvm
```

#### Post-Restore Steps

After VM-level restore:

```bash
# SSH to restored Immich VM
ssh hermes-admin@192.168.40.22

# Verify containers are running
cd /opt/immich && docker compose ps

# Check Immich health
curl -s http://localhost:2283/api/server/ping

# Verify NFS mounts
mount | grep -E "synology|immich"

# If NFS mounts failed, remount
sudo mount -a
```

---

## Part 2: Application-Level Backup (Database)

### Setup (One-Time)

Run the Ansible playbook to configure automated database backups:

```bash
# From Ansible controller
ssh hermes-admin@192.168.20.30
cd ~/ansible

# Deploy backup configuration
ansible-playbook playbooks/backup/configure-immich-backup.yml -v
```

### What Gets Deployed

| File | Purpose |
|------|---------|
| `/opt/immich/backup-db.sh` | Database backup script |
| `/opt/immich/restore-db.sh` | Database restore script |
| Cron job | Runs backup at 02:30 daily |

### Manual Backup

```bash
# SSH to Immich VM
ssh hermes-admin@192.168.40.22

# Run backup manually
sudo /opt/immich/backup-db.sh

# View backup log
tail -50 /var/log/immich-backup.log

# List backups
ls -lah /mnt/immich-uploads/db-backups/
```

### Database Restore Procedure

#### List Available Backups

```bash
# SSH to Immich VM
ssh hermes-admin@192.168.40.22

# List available backups
sudo /opt/immich/restore-db.sh
```

Expected output:
```
Available Immich database backups:
==================================

File                                    Size       Date
----                                    ----       ----
immich-db-20260114_023000.sql.gz        45M        2026-01-14 02:30:00
immich-db-20260113_023000.sql.gz        44M        2026-01-13 02:30:00
immich-db-20260112_023000.sql.gz        43M        2026-01-12 02:30:00
...

Usage: /opt/immich/restore-db.sh <backup_file.sql.gz>
```

#### Perform Database Restore

```bash
# Restore from specific backup
sudo /opt/immich/restore-db.sh immich-db-20260114_023000.sql.gz
```

The script will:
1. Prompt for confirmation
2. Stop Immich services
3. Drop and recreate the database
4. Restore from backup
5. Restart Immich services
6. Verify services are running

#### Manual Database Restore (Advanced)

If the restore script is not available:

```bash
# SSH to Immich VM
ssh hermes-admin@192.168.40.22
cd /opt/immich

# Stop Immich services (keep PostgreSQL running)
docker compose stop immich-server immich-machine-learning

# Find backup file
ls /mnt/immich-uploads/db-backups/

# Restore database
gunzip -c /mnt/immich-uploads/db-backups/immich-db-20260114_023000.sql.gz | \
  docker exec -i immich-postgres psql -U postgres

# Restart services
docker compose start immich-server immich-machine-learning

# Verify
curl -s http://localhost:2283/api/server/ping
```

---

## Part 3: Photo Storage Backup

### Current Photo Storage

| Location | Path | Size | Purpose |
|----------|------|------|---------|
| **Active Uploads** | `/volume2/Immich Photos/` | ~500GB+ | New photos from mobile app |
| **Legacy Photos** | `/volume2/homes/hermes-admin/Photos/` | ~200GB | Historical photos (read-only) |

### Recommended: Synology Hyper Backup to Backblaze B2

#### Setup Steps

1. **Create Backblaze B2 Account**
   - Go to https://www.backblaze.com/b2
   - Create account (free tier available)
   - Create bucket: `immich-photos-backup`
   - Generate Application Key

2. **Configure Hyper Backup on Synology**
   - Open DSM: https://192.168.20.31:5001
   - Install **Hyper Backup** from Package Center
   - Create new backup task:
     - **Destination**: Backblaze B2
     - **Bucket**: `immich-photos-backup`
     - **Source folders**:
       - `/volume2/Immich Photos`
     - **Schedule**: Daily at 04:00 (after PBS completes)
     - **Retention**: Keep daily for 7 days, weekly for 4 weeks

#### Cost Estimate

| Photo Storage | Monthly Cost |
|---------------|--------------|
| 100 GB | ~$0.50 |
| 500 GB | ~$2.50 |
| 1 TB | ~$5.00 |
| 2 TB | ~$10.00 |

---

## Disaster Recovery Scenarios

### Scenario 1: Immich VM Crashed (Quick Recovery)

**Symptoms**: VM won't boot, but storage is intact

**Recovery**:
```bash
# Restore from PBS (5-10 minutes)
qmrestore pbs-daily:backup/vm/115/latest 115 --storage local-lvm

# Start VM
qm start 115

# Verify
ssh hermes-admin@192.168.40.22 "docker compose -f /opt/immich/docker-compose.yml ps"
```

### Scenario 2: Database Corruption (Medium Recovery)

**Symptoms**: Immich shows errors, missing photos, broken albums

**Recovery**:
```bash
# SSH to Immich VM
ssh hermes-admin@192.168.40.22

# List available DB backups
sudo /opt/immich/restore-db.sh

# Restore from yesterday's backup
sudo /opt/immich/restore-db.sh immich-db-20260113_023000.sql.gz
```

### Scenario 3: Complete VM Loss (Full Recovery)

**Symptoms**: VM disk corrupted, need fresh restore

**Recovery**:
```bash
# 1. Restore VM from PBS
ssh root@192.168.20.20
qmrestore pbs-daily:backup/vm/115/latest 115 --storage local-lvm
qm start 115

# 2. Wait for VM to boot
sleep 60

# 3. Verify NFS mounts
ssh hermes-admin@192.168.40.22 "mount | grep immich"

# 4. If DB issues, restore from application backup
ssh hermes-admin@192.168.40.22 "sudo /opt/immich/restore-db.sh"
```

### Scenario 4: NAS Failure (Extended Recovery)

**Symptoms**: Photos inaccessible, NFS mounts failed

**Recovery**:
1. Repair/replace NAS hardware
2. Restore photos from Hyper Backup (cloud)
3. Restore Immich VM from PBS
4. Restore database from backup
5. Remount NFS shares

---

## Backup Verification

### Daily Checks (Automated)

The following should be verified by monitoring:

| Check | Expected | Dashboard |
|-------|----------|-----------|
| PBS backup completed | Job status: OK | Grafana PBS Dashboard |
| DB backup created | New file at 02:30 | `/var/log/immich-backup.log` |
| Immich service healthy | Ping: pong | Uptime Kuma |

### Weekly Manual Verification

```bash
# 1. Verify PBS backups exist
ssh root@192.168.20.50
proxmox-backup-client list --repository backup@pbs@localhost:daily | grep vm/115

# 2. Verify DB backups exist
ssh hermes-admin@192.168.40.22
ls -la /mnt/immich-uploads/db-backups/ | head -10

# 3. Check backup sizes are reasonable
du -sh /mnt/immich-uploads/db-backups/

# 4. Verify backup log shows success
tail -20 /var/log/immich-backup.log
```

### Monthly Test Restore

Quarterly, perform a test restore to verify backups are valid:

```bash
# 1. Create test VM from backup
qmrestore pbs-daily:backup/vm/115/latest 999 --storage local-lvm --unique

# 2. Start test VM (use different IP)
qm set 999 --ipconfig0 ip=192.168.40.99/24,gw=192.168.40.1
qm start 999

# 3. Verify Immich works
curl http://192.168.40.99:2283/api/server/ping

# 4. Clean up test VM
qm stop 999
qm destroy 999
```

---

## Quick Reference Commands

### Backup Commands

```bash
# Manual database backup
ssh hermes-admin@192.168.40.22 "sudo /opt/immich/backup-db.sh"

# View backup log
ssh hermes-admin@192.168.40.22 "tail -50 /var/log/immich-backup.log"

# List database backups
ssh hermes-admin@192.168.40.22 "ls -lh /mnt/immich-uploads/db-backups/"

# List PBS backups
ssh root@192.168.20.50 "proxmox-backup-client list --repository backup@pbs@localhost:daily | grep vm/115"
```

### Restore Commands

```bash
# Restore database (interactive)
ssh hermes-admin@192.168.40.22 "sudo /opt/immich/restore-db.sh"

# Restore VM from PBS
ssh root@192.168.20.20 "qmrestore pbs-daily:backup/vm/115/latest 115 --storage local-lvm"

# Restart Immich services
ssh hermes-admin@192.168.40.22 "cd /opt/immich && docker compose restart"
```

### Troubleshooting Commands

```bash
# Check Immich health
curl -s http://192.168.40.22:2283/api/server/ping

# Check container status
ssh hermes-admin@192.168.40.22 "docker ps --filter 'name=immich'"

# Check NFS mounts
ssh hermes-admin@192.168.40.22 "mount | grep -E 'synology|immich'"

# Check cron job
ssh hermes-admin@192.168.40.22 "crontab -l | grep immich"
```

---

## Recovery Time Objectives

| Scenario | RTO (Recovery Time) | RPO (Data Loss) |
|----------|---------------------|-----------------|
| VM crash | 10-15 minutes | Max 24 hours |
| DB corruption | 5-10 minutes | Max 24 hours |
| Complete VM loss | 20-30 minutes | Max 24 hours |
| NAS failure | 2-4 hours | Depends on cloud backup |
| Datacenter loss | 4-8 hours | Depends on cloud backup |

---

## Related Documentation

- [[39 - PBS Deployment Tutorial]] - PBS setup guide
- [[40 - PBS Disaster Recovery]] - PBS recovery procedures
- [[07 - Deployed Services]] - Immich service details
- [[21 - Application Configurations]] - Immich configuration
- [[03 - Storage Architecture]] - NAS and storage overview

---

*Last updated: January 14, 2026*
