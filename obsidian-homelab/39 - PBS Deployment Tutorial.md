# Proxmox Backup Server (PBS) Deployment Tutorial

> **Complete guide to deploying PBS as an LXC container with dual-datastore backup architecture**

Related: [[00 - Homelab Index]] | [[02 - Proxmox Cluster]] | [[03 - Storage Architecture]] | [[11 - Credentials]]

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Part 1: Prepare Physical Storage](#part-1-prepare-physical-storage)
5. [Part 2: Create PBS LXC Container](#part-2-create-pbs-lxc-container)
6. [Part 3: Install PBS Inside Container](#part-3-install-pbs-inside-container)
7. [Part 4: Configure PBS Datastores](#part-4-configure-pbs-datastores)
8. [Part 5: Configure Users and Permissions](#part-5-configure-users-and-permissions)
9. [Part 6: Add PBS to Proxmox VE](#part-6-add-pbs-to-proxmox-ve)
10. [Part 7: Post-Deployment Configuration](#part-7-post-deployment-configuration)
11. [Backup Strategy](#backup-strategy)
12. [CLI Commands Reference](#cli-commands-reference)
13. [Troubleshooting](#troubleshooting)

---

## Overview

### What is Proxmox Backup Server?

**Proxmox Backup Server (PBS)** is an enterprise-grade backup solution designed specifically for Proxmox VE. Unlike the built-in `vzdump` backup, PBS provides:

| Feature | Description |
|---------|-------------|
| **Deduplication** | Only stores unique data blocks - saves ~70% storage |
| **Incremental Backups** | After initial full backup, only changes are transferred |
| **Encryption** | Optional client-side encryption for sensitive data |
| **Verification** | Checksums detect bit-rot and data corruption |
| **Fast Restore** | Can mount backups directly without full restore |
| **Web UI** | Easy management interface at port 8007 |

### Why This Setup?

We deploy PBS as an LXC container with **two separate datastores**:

1. **SSD Datastore (daily)**: Fast NVMe storage for frequent backups and quick restores
2. **HDD Datastore (main)**: Large capacity for long-term archival backups

This tiered approach optimizes for both speed and capacity.

---

## Architecture

```
node03 (192.168.20.22) - Proxmox Host
├── Physical Storage
│   ├── /dev/sda (Seagate 4TB HDD)
│   │   ├── Mounted at: /mnt/pbs-backup
│   │   └── Purpose: Weekly/monthly archival backups
│   │
│   └── /dev/nvme0n1 (Kingston 1TB NVMe)
│       ├── Mounted at: /mnt/pbs-ssd
│       └── Purpose: Daily backups (fast restore)
│
└── PBS LXC Container (VMID 100)
    ├── IP: 192.168.20.50
    ├── Web UI: https://192.168.20.50:8007
    │
    ├── /backup (bind mount from /mnt/pbs-backup/datastore)
    │   └── Datastore: "main" (3.4TB available)
    │
    └── /backup-ssd (bind mount from /mnt/pbs-ssd/datastore)
        └── Datastore: "daily" (870GB available)
```

### Data Flow

```
Proxmox VE (node01/node02/node03)
         │
         │ Backup Job (vzdump)
         ▼
    PBS API (192.168.20.50:8007)
         │
         ├─────────────────────────────┐
         │                             │
         ▼                             ▼
   pbs-daily (SSD)              pbs-main (HDD)
   Daily backups                Weekly archives
   7-day retention              4-week + 2-month
```

---

## Prerequisites

### Hardware Requirements

| Component | Minimum | Our Setup |
|-----------|---------|-----------|
| CPU | 1 core | 2 cores |
| RAM | 2 GB | 4 GB |
| Storage | 1 disk | 2 disks (SSD + HDD) |
| Network | 1 Gbps | 1 Gbps |

### Software Requirements

- Proxmox VE 8.x or 9.x on the host
- SSH access to Proxmox node
- Available VMID (we use 100)
- Unused IP address (we use 192.168.20.50)

### Information to Gather

Before starting, identify:

```bash
# SSH to your Proxmox node
ssh root@192.168.20.22

# List available disks
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINT

# Check available VMIDs
cat /etc/pve/.vmlist | grep -v "^#"
```

---

## Part 1: Prepare Physical Storage

### Step 1.1: Identify Your Disks

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINT
```

**Example Output:**
```
NAME        SIZE TYPE MODEL                    MOUNTPOINT
sda         3.6T disk ST4000VN006-3CW104
nvme0n1   931.5G disk Kingston SNV3S1000G
nvme1n1   476.9G disk Samsung SSD 980 PRO      /
```

**What to look for:**
- Disks without MOUNTPOINT are available
- Note the device names (sda, nvme0n1, etc.)
- Check MODEL to identify which physical disk is which

### Step 1.2: Wipe the First Disk (HDD)

```bash
wipefs -a /dev/sda
```

**What `wipefs` does:**
- Removes filesystem signatures (ext4, ntfs, etc.)
- Removes partition table signatures (GPT, MBR)
- Removes RAID metadata
- The `-a` flag removes ALL signatures

**Why this is important:** Old signatures can confuse the system about what's on the disk.

### Step 1.3: Create GPT Partition Table

```bash
# Create GPT partition table
parted /dev/sda --script mklabel gpt

# Create single partition using entire disk
parted /dev/sda --script mkpart primary ext4 0% 100%
```

**Command breakdown:**

| Part | Meaning |
|------|---------|
| `parted` | GNU partition editor |
| `/dev/sda` | Target disk |
| `--script` | Non-interactive mode (no prompts) |
| `mklabel gpt` | Create GPT partition table |
| `mkpart primary ext4 0% 100%` | Create partition from start to end |

**Why GPT?**
- Modern standard (replaces MBR)
- Supports disks larger than 2TB
- More reliable (backup partition table)

### Step 1.4: Format with ext4

```bash
mkfs.ext4 -L pbs-backup /dev/sda1
```

**What this does:**
- `mkfs.ext4`: Create ext4 filesystem
- `-L pbs-backup`: Set volume label (helpful for identification)
- `/dev/sda1`: Target the first partition we created

**Why ext4?**
- Mature, stable filesystem
- Good performance for backup workloads
- Supports large files
- Well-supported by PBS

### Step 1.5: Create Mount Point and Mount

```bash
# Create the directory where disk will be accessible
mkdir -p /mnt/pbs-backup

# Mount the partition to this directory
mount /dev/sda1 /mnt/pbs-backup

# Verify it worked
df -h /mnt/pbs-backup
```

**Expected output:**
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       3.6T   28K  3.4T   1% /mnt/pbs-backup
```

### Step 1.6: Make Mount Persistent (Survives Reboot)

```bash
# Get the UUID of the partition
blkid /dev/sda1
```

**Example output:**
```
/dev/sda1: LABEL="pbs-backup" UUID="a1b2c3d4-e5f6-7890-abcd-ef1234567890" TYPE="ext4"
```

```bash
# Add to fstab (replace UUID with yours)
echo 'UUID=a1b2c3d4-e5f6-7890-abcd-ef1234567890 /mnt/pbs-backup ext4 defaults 0 2' >> /etc/fstab
```

**Why UUID instead of /dev/sda1?**
- Device names can change between reboots
- UUID is permanent and unique
- Prevents mounting wrong disk if hardware changes

**The fstab columns explained:**

| Column | Value | Meaning |
|--------|-------|---------|
| 1 | UUID=... | Device identifier |
| 2 | /mnt/pbs-backup | Where to mount |
| 3 | ext4 | Filesystem type |
| 4 | defaults | Mount options |
| 5 | 0 | Dump (backup) - disabled |
| 6 | 2 | fsck order (2 = check after root) |

### Step 1.7: Repeat for Second Disk (NVMe SSD)

```bash
# Wipe old data (may have old Windows NTFS)
wipefs -a /dev/nvme0n1

# Create GPT partition table
parted /dev/nvme0n1 --script mklabel gpt
parted /dev/nvme0n1 --script mkpart primary ext4 0% 100%

# Format with ext4
mkfs.ext4 -L pbs-ssd /dev/nvme0n1p1

# Create mount point and mount
mkdir -p /mnt/pbs-ssd
mount /dev/nvme0n1p1 /mnt/pbs-ssd

# Get UUID and add to fstab
blkid /dev/nvme0n1p1
echo 'UUID=<your-uuid-here> /mnt/pbs-ssd ext4 defaults 0 2' >> /etc/fstab

# Verify
df -h /mnt/pbs-ssd
```

**Note:** NVMe partitions use `p1` suffix (nvme0n1p1), not just `1` like SATA disks.

### Step 1.8: Verify All Mounts

```bash
# Test fstab entries work
mount -a

# Show all mounts
df -h | grep pbs
```

**Expected output:**
```
/dev/sda1        3.6T   28K  3.4T   1% /mnt/pbs-backup
/dev/nvme0n1p1   916G   28K  870G   1% /mnt/pbs-ssd
```

---

## Part 2: Create PBS LXC Container

### Step 2.1: Download Debian Template

```bash
# Update template list from Proxmox servers
pveam update

# Download Debian 12 (Bookworm) template
pveam download local debian-12-standard_12.12-1_amd64.tar.zst
```

**What `pveam` does:**
- Proxmox VE Appliance Manager
- Downloads and manages container templates
- Templates are stored in `/var/lib/vz/template/cache/`

### Step 2.2: Create Datastore Directories

```bash
# Create directories for PBS datastores
mkdir -p /mnt/pbs-backup/datastore
mkdir -p /mnt/pbs-ssd/datastore
```

**Why separate `/datastore` subdirectory?**
- Keeps PBS data organized
- Parent directory can hold other files (logs, scripts)
- Cleaner bind mount configuration

### Step 2.3: Create the LXC Container

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

**Parameter-by-parameter explanation:**

| Parameter | Value | Why |
|-----------|-------|-----|
| `100` | VMID | Unique container ID |
| `local:vztmpl/...` | Template path | The Debian 12 template |
| `--hostname pbs-server` | Container name | Shows in console/logs |
| `--cores 2` | CPU cores | Enough for deduplication |
| `--memory 4096` | RAM (MB) | 4GB for dedup operations |
| `--swap 512` | Swap (MB) | Emergency overflow |
| `--rootfs local-lvm:20` | Root disk | 20GB for OS on local storage |
| `--net0 ...` | Network config | Static IP, bridge, gateway |
| `--nameserver` | DNS servers | Google DNS (8.8.8.8) |
| `--searchdomain` | Domain suffix | For short hostnames |
| `--features nesting=1` | Enable nesting | Some PBS features need this |
| `--unprivileged 0` | Privileged mode | Required for bind mounts |
| `--start 0` | Don't auto-start | Configure first |

**Why privileged container?**
- Bind mounts from host require privileged mode
- PBS needs access to mounted storage
- Security trade-off is acceptable for dedicated backup server

### Step 2.4: Add Bind Mounts

```bash
# Mount HDD datastore into container
pct set 100 -mp0 /mnt/pbs-backup/datastore,mp=/backup

# Mount SSD datastore into container
pct set 100 -mp1 /mnt/pbs-ssd/datastore,mp=/backup-ssd
```

**What bind mounts do:**
- Host path → Container path
- `/mnt/pbs-backup/datastore` (host) appears as `/backup` (container)
- Container can read/write to host storage
- Changes persist even if container is destroyed

### Step 2.5: Verify Container Configuration

```bash
# View the configuration
pct config 100
```

**Expected output includes:**
```
arch: amd64
cores: 2
features: nesting=1
hostname: pbs-server
memory: 4096
mp0: /mnt/pbs-backup/datastore,mp=/backup
mp1: /mnt/pbs-ssd/datastore,mp=/backup-ssd
net0: name=eth0,bridge=vmbr0,ip=192.168.20.50/24,gw=192.168.20.1
...
```

### Step 2.6: Start the Container

```bash
pct start 100

# Verify it's running
pct status 100
```

---

## Part 3: Install PBS Inside Container

### Step 3.1: Enter the Container

```bash
pct exec 100 -- bash
```

**What `pct exec` does:**
- Runs command inside container
- `100`: Target container ID
- `--`: Separates pct options from command
- `bash`: Start interactive shell

You're now "inside" the container. The prompt changes.

### Step 3.2: Update Package Lists

```bash
apt-get update
```

### Step 3.3: Add Proxmox GPG Key

```bash
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg \
  -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
```

**What this does:**
- Downloads Proxmox's signing key
- Allows apt to verify packages are authentic
- Without this, apt will reject Proxmox packages

### Step 3.4: Add PBS Repository

```bash
echo "deb http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription" \
  > /etc/apt/sources.list.d/pbs.list
```

**Repository URL breakdown:**

| Part | Meaning |
|------|---------|
| `http://download.proxmox.com/debian/pbs` | Proxmox package server |
| `bookworm` | Debian version codename |
| `pbs-no-subscription` | Free tier (no support contract) |

**Why no-subscription?**
- Enterprise repo requires paid subscription
- No-subscription has identical packages
- Only difference is support availability

### Step 3.5: Install PBS

```bash
# Update with new repository
apt-get update

# Install PBS (non-interactive)
DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-backup-server
```

**The `DEBIAN_FRONTEND=noninteractive`:**
- Prevents installer from asking questions
- Uses default answers
- Required for scripted installations

This takes a few minutes. PBS and all dependencies are installed.

### Step 3.6: Verify Installation

```bash
# Check PBS version
proxmox-backup-manager version

# Check services are running
systemctl status proxmox-backup-proxy
systemctl status proxmox-backup
```

---

## Part 4: Configure PBS Datastores

### Step 4.1: Create Main Datastore (HDD)

```bash
proxmox-backup-manager datastore create main /backup \
  --comment 'Main backup datastore - 4TB HDD for archival'
```

**Command breakdown:**
- `proxmox-backup-manager`: PBS CLI tool
- `datastore create`: Create new datastore
- `main`: Name (used in Proxmox VE)
- `/backup`: Path (our bind mount)
- `--comment`: Description for web UI

### Step 4.2: Create Daily Datastore (SSD)

```bash
proxmox-backup-manager datastore create daily /backup-ssd \
  --comment 'Daily backups - 1TB NVMe SSD for fast restores'
```

### Step 4.3: Verify Datastores

```bash
proxmox-backup-manager datastore list
```

**Expected output:**
```
+-------+-------------+
| name  | path        |
+=======+=============+
| daily | /backup-ssd |
| main  | /backup     |
+-------+-------------+
```

---

## Part 5: Configure Users and Permissions

### Step 5.1: Set Root Password

```bash
echo "root:PBSr00t@2025!" | chpasswd
```

**This sets the password for web UI login.**

> **Important Login Note:** When logging into the web UI, enter just `root` in the username field. Select "Linux PAM standard authentication" as the realm. The realm dropdown adds `@pam` automatically.

### Step 5.2: Create Backup User

```bash
proxmox-backup-manager user create backup@pbs \
  --comment 'PVE backup user'
```

**Why a separate user?**
- Principle of least privilege
- Dedicated user for automated backups
- Can revoke without affecting root

### Step 5.3: Generate API Token

```bash
proxmox-backup-manager user generate-token backup@pbs pve \
  --comment 'PVE integration token'
```

**Output:**
```
tokenid: backup@pbs!pve
value: cae1be63-f700-4af6-9419-198f7cdf0330
```

**SAVE THIS TOKEN!** You'll need the value when configuring Proxmox VE.

### Step 5.4: Grant Permissions (CRITICAL STEP)

This is where most deployments fail. The API token needs explicit permissions.

```bash
# Root-level Audit - allows listing datastores
proxmox-backup-manager acl update / Audit --auth-id backup@pbs!pve

# DatastoreAdmin on main - full access to main datastore
proxmox-backup-manager acl update /datastore/main DatastoreAdmin --auth-id backup@pbs!pve

# DatastoreAdmin on daily - full access to daily datastore
proxmox-backup-manager acl update /datastore/daily DatastoreAdmin --auth-id backup@pbs!pve
```

**Why each permission:**

| Path | Role | Purpose |
|------|------|---------|
| `/` | Audit | List datastores (without this: "Cannot find datastore" error) |
| `/datastore/main` | DatastoreAdmin | Create, read, delete backups |
| `/datastore/daily` | DatastoreAdmin | Create, read, delete backups |

### Step 5.5: Verify Permissions

```bash
proxmox-backup-manager acl list
```

**Expected output:**
```
+================+=================+===========+=================+
| ugid           | path            | propagate | roleid          |
+================+=================+===========+=================+
| backup@pbs!pve | /               |         1 | Audit           |
| backup@pbs!pve | /datastore/daily|         1 | DatastoreAdmin  |
| backup@pbs!pve | /datastore/main |         1 | DatastoreAdmin  |
+================+=================+===========+=================+
```

### Step 5.6: Get SSL Fingerprint

```bash
proxmox-backup-manager cert info 2>/dev/null | grep -A1 'Fingerprint'
```

**Output:**
```
Fingerprint (sha256): 32:27:42:d5:ab:7e:41:ef:80:17:ea:30:b8:43:9a:f3:59:af:60:f5:6b:05:ea:1f:28:30:ff:7f:19:b6:d4:55
```

**Save this fingerprint!** Proxmox VE uses it to verify PBS identity.

### Step 5.7: Exit Container

```bash
exit
```

You're back on the Proxmox host.

---

## Part 6: Add PBS to Proxmox VE

### Step 6.1: Open Proxmox VE Web UI

Navigate to: https://192.168.20.20:8006 (or your Proxmox node)

### Step 6.2: Add Main Datastore

1. Go to **Datacenter → Storage → Add → Proxmox Backup Server**
2. Fill in the form:

| Field | Value |
|-------|-------|
| ID | `pbs-main` |
| Server | `192.168.20.50` |
| Username | `backup@pbs!pve` |
| Password | `cae1be63-f700-4af6-9419-198f7cdf0330` (your token) |
| Datastore | `main` |
| Fingerprint | (paste from Step 5.6) |

3. Click **Add**

### Step 6.3: Add Daily Datastore

Repeat with:
- ID: `pbs-daily`
- Datastore: `daily`
- (Other fields same as above)

### Step 6.4: Verify in Proxmox VE

The new storages should appear in **Datacenter → Storage** and on each node's storage list.

---

## Part 7: Post-Deployment Configuration

### Step 7.1: Remove Subscription Nag (Optional)

The "No valid subscription" popup appears on login. To remove it:

```bash
# From the Proxmox host (node03)
pct exec 100 -- perl -i.bak -pe \
  's/res.status.toLowerCase\(\) !== .active./false/g' \
  /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

pct exec 100 -- systemctl restart proxmox-backup-proxy
```

**Note:** This patch needs reapplication after PBS updates.

### Step 7.2: Configure Backup Retention (in PBS Web UI)

1. Login to PBS: https://192.168.20.50:8007
2. Go to **Datastore → main → Prune & GC**
3. Set retention:
   - Keep Weekly: 4
   - Keep Monthly: 2

4. Repeat for **daily** datastore:
   - Keep Last: 7

---

## Backup Strategy

### Recommended Backup Schedule

| Job Name | Storage | Schedule | VMs | Retention |
|----------|---------|----------|-----|-----------|
| Critical Daily | pbs-daily | Daily 02:00 | Traefik, Authentik, Glance | 7 daily |
| Services Daily | pbs-daily | Daily 03:00 | GitLab, Immich, Pi-hole | 7 daily |
| Weekly Archive | pbs-main | Sunday 04:00 | All VMs | 4 weekly, 2 monthly |

### Creating Backup Jobs (in Proxmox VE)

1. Go to **Datacenter → Backup → Add**
2. Configure:
   - **Storage**: pbs-daily or pbs-main
   - **Schedule**: Cron expression (e.g., `0 2 * * *` for 2 AM daily)
   - **Selection Mode**: Include selected VMs
   - **Mode**: Snapshot
   - **Compression**: ZSTD

---

## CLI Commands Reference

### Container Management

```bash
# Enter PBS container
pct exec 100 -- bash

# Start/stop/restart container
pct start 100
pct stop 100
pct restart 100

# View container config
pct config 100
```

### PBS Management (run inside container)

```bash
# List datastores
proxmox-backup-manager datastore list

# Check datastore status
proxmox-backup-manager datastore status main

# List users
proxmox-backup-manager user list

# List permissions
proxmox-backup-manager acl list

# List backup snapshots
proxmox-backup-client list --repository backup@pbs!pve@localhost:main

# Verify backup integrity
proxmox-backup-manager verify main

# Run garbage collection (free space)
proxmox-backup-manager gc run main
```

### Service Management (inside container)

```bash
# Check service status
systemctl status proxmox-backup-proxy
systemctl status proxmox-backup

# Restart services
systemctl restart proxmox-backup-proxy
```

---

## Troubleshooting

### "Cannot find datastore" Error

**Symptom:** When adding PBS to Proxmox VE, datastore dropdown is empty or shows error.

**Cause:** API token lacks root-level Audit permission.

**Fix:**
```bash
pct exec 100 -- proxmox-backup-manager acl update / Audit --auth-id backup@pbs!pve
```

### Login Failed in Web UI

**Symptom:** Password is correct but login fails.

**Cause:** Entering `root@pam` in username field.

**Fix:** Enter just `root`. Select "Linux PAM standard authentication" from realm dropdown. The dropdown adds `@pam` automatically.

### Container Can't Reach Network

**Symptom:** Container can't ping gateway or internet.

**Cause:** VLAN tag conflict when bridge is natively on VLAN.

**Fix:**
```bash
pct set 100 --net0 name=eth0,bridge=vmbr0,ip=192.168.20.50/24,gw=192.168.20.1
```

### Blank/Black Web UI

**Symptom:** PBS web UI loads but shows black screen.

**Cause:** JavaScript patch broke something.

**Fix:**
```bash
pct exec 100 -- cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak \
  /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
pct exec 100 -- systemctl restart proxmox-backup-proxy
```

### Backups Failing with Permission Error

**Symptom:** Backup jobs fail with "permission denied" or "403 Forbidden".

**Cause:** API token lacks DatastoreAdmin on target datastore.

**Fix:**
```bash
pct exec 100 -- proxmox-backup-manager acl update /datastore/daily DatastoreAdmin --auth-id backup@pbs!pve
```

---

## Credentials Summary

| Field | Value |
|-------|-------|
| LXC | 100 on node03 |
| IP | 192.168.20.50 |
| Web UI | https://192.168.20.50:8007 |
| Username | `root` (select Linux PAM realm) |
| Password | `PBSr00t@2025!` |
| API Token ID | `backup@pbs!pve` |
| API Token Secret | `cae1be63-f700-4af6-9419-198f7cdf0330` |
| Fingerprint | `32:27:42:d5:ab:7e:41:ef:80:17:ea:30:b8:43:9a:f3:59:af:60:f5:6b:05:ea:1f:28:30:ff:7f:19:b6:d4:55` |

---

## Related Documentation

- [[02 - Proxmox Cluster]] - Cluster configuration
- [[03 - Storage Architecture]] - Storage design
- [[11 - Credentials]] - All credentials
- [[38 - Homelab Technical Manual]] - Complete reference

---

*Created: January 11, 2026*
*Last Updated: January 11, 2026*
