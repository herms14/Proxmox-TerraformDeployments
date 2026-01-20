# Session Log

> Recent session history. Keep only last 3-5 entries. Archive older entries to `session-log-archive.md` if needed.

---

## 2026-01-21

### NAS Backup Status API Duration Fix
**Status**: Completed ✅
**Task**: Fix incorrect backup duration calculation on Glance Backup page

**Problem**: Dashboard showed "7h 21m" duration for daily backups when actual job took ~38 minutes. The API calculated duration from first to last backup timestamp of the entire day, not the actual job span.

**Root Cause**: When multiple backup jobs run on the same day (e.g., morning at 08:20 and afternoon at 15:03), the API incorrectly treated them as one job spanning 7+ hours.

**Fix**: Updated `get_backup_job_status()` in `/opt/nas-backup-status-api/app.py` to:
1. Sort backup timestamps descending (most recent first)
2. Group backups within 1 hour of each other as a single job
3. Calculate duration only for the most recent contiguous job

**Results**:
| Metric | Before | After |
|--------|--------|-------|
| Daily Backups Duration | 7h 21m | 38m 0s |
| Main Backups Duration | 1h 48m | 1h 48m (unchanged, was correct) |

**Files Modified**:
- `/opt/nas-backup-status-api/app.py` on docker-vm-core-utilities01
- Container rebuilt via `docker compose build --no-cache && docker compose up -d`

**Documentation Updated**:
- `.claude/session-log.md`
- `obsidian-homelab/23 - PBS Monitoring.md`
- Technical Manual (v6.9 → v7.0)
- Book Chapter 26

---

## 2026-01-20

### Azure Deployment Documentation
**Status**: Completed ✅
**Task**: Create comprehensive Azure deployment documentation for Claude agents

**Files Created/Updated**:
1. **AZURE-CLAUDE.md** (Obsidian)
   - Claude agent context file for Azure deployments
   - All three subscriptions: FireGiants-Prod, FireGiants-Dev, Nokron-Prod
   - SSH access details, key locations
   - Deployment workflow architecture
   - Terraform provider templates
   - **Comprehensive documentation requirements section**
   - Troubleshooting guide

2. **53 - Azure Deployment Tutorial.md** (Obsidian)
   - Step-by-step deployment guide
   - Local-to-Azure workflow
   - Best practices and naming conventions
   - Common operations (update, destroy, import)
   - Quick reference commands

3. **claude.md** (Project root)
   - Added all Azure subscriptions
   - Added Azure deployment workflow section
   - Added mandatory documentation requirements
   - Documentation checklist for implementations

**Documentation Synced To**:
- Technical Manual: Added "Azure Deployment Workflow" section
- Book Chapter 24: Expanded Terraform Deployment Workflow with architecture diagram

**Azure Subscriptions Documented**:
- FireGiants-Prod: `2212d587-1bad-4013-b605-b421b1f83c30` (Primary)
- FireGiants-Dev: `79e34814-e81a-465c-abf3-11103880db90`
- Nokron-Prod: `9dde5c52-88be-4608-9bee-c52d1909693f`

**Documentation Requirements Added**:
- All implementations must be documented in 3 locations
- Technical Manual: Tutorial style (steps, tables, code)
- Book: Narrative style (full paragraphs, context, lessons)
- Obsidian: Modular notes with diagrams and configs

---

### Glance Dashboard UI Redesign & Documentation Update
**Status**: Completed
**Task**: Major UI redesign with 25 new themes and comprehensive documentation updates

**Work Completed**:
1. **Glance UI Redesign**:
   - Added page icons/emojis for all 11 pages: 🏠🛠💻💾📦🌐🎬📰💰🤖🏀
   - Created new Services page consolidating all health monitors
   - Split Web page into News and Finance pages
   - Standardized widget styling (padding: 12px, border-radius: 8px)
   - Optimized iframe heights (Proxmox: 2400px, Container: 1800px)
   - Added 25 new themes (total now 35)
   - Fixed backup schedule text (Daily: 19:00, Main: 02:00 AM)

2. **Git Operations**:
   - Committed and pushed to `herms14/glance-dashboard` (commit 3680bbc)
   - Synced config to `ansible/playbooks/glance/files/glance.yml`

3. **Documentation Updates**:
   - CHANGELOG.md - Added UI redesign entry
   - `obsidian-homelab/23 - Glance Dashboard.md` - Updated page structure, themes, iframe heights
   - Technical Manual v6.9 - Updated Glance section with new page structure
   - Book Chapter 29 - Updated architecture diagram and page table

**Files Modified**:
- `gitops-repos/glance-homelab/config/glance.yml`
- `ansible/playbooks/glance/files/glance.yml`
- `ansible/playbooks/glance/files/backup-page.yml`
- `CHANGELOG.md`
- `obsidian-homelab/23 - Glance Dashboard.md`
- Obsidian Technical Manual (v6.8 → v6.9)
- Obsidian Book (Chapter 29)

---

### Azure Managed Grafana Deployment
**Status**: Completed ✅
**Task**: Create Azure Managed Grafana with comprehensive monitoring dashboards

**Grafana URL**: https://grafana-homelab-prod-cmd8aqhtemcddgdz.sing.grafana.azure.com

**Work Completed**:
1. **Terraform Deployment**: Grafana, Monitor Workspace, DCR, DCE, role assignments, alerts

2. **Dashboards Created** (4 total in Homelab Monitoring folder):
   - `compute-overview.json` - VM CPU, memory for SEA & East Asia
   - `network-overview.json` - Network traffic, bandwidth per VM
   - `storage-overview.json` - Disk performance, IOPS
   - `vwan-vpn-overview.json` - VPN tunnel status, traffic

3. **VPN Dashboard Fix** (Critical):
   - **Issue**: Dashboard showed "No data" for VPN metrics
   - **Root cause**: VPN Gateway metrics don't support 1-minute intervals
   - **Fix**: Changed `"timeGrain": "auto"` to `"timeGrain": "PT5M"`
   - Updated resource to correct VPN Gateway: `erd-shared-corp-vnetgw-sea` in `erd-connectivity-sea-rg`

4. **Documentation Updated**:
   - Obsidian `52 - Azure Managed Grafana.md` - Full documentation with query examples
   - Technical Manual - VPN Gateway query format and time grain warning
   - Book Chapter 34 - Added lesson #8 about VPN Gateway time grain

**Key Lesson**: VPN Gateway metrics require PT5M or higher time grain (PT5M, PT15M, PT30M, PT1H, PT6H, PT12H, P1D)

**Files Modified**:
- `terraform/azure/azure-managed-grafana/dashboards/vwan-vpn-overview.json`
- `obsidian-homelab/52 - Azure Managed Grafana.md` (Obsidian)
- Technical Manual, Book (Obsidian)

---

## 2026-01-16

### Gaming PC & Steam Integration for Glance
**Status**: Completed (Pending User Setup)
**Task**: Add gaming PC metrics and Steam profile to Glance Home dashboard

**Features Added**:
1. **Gaming PC Widget** (192.168.10.10):
   - CPU temperature and load
   - GPU temperature, load, VRAM usage
   - Memory usage (used/available)
   - Fan speeds
   - Storage temperatures and usage
   - Requires LibreHardwareMonitor HTTP server

2. **Steam Profile Widget**:
   - Top 3 recently played games with thumbnails
   - Playtime (total and last 2 weeks)
   - Last played timestamps
   - Total games owned count
   - Wishlist items on sale notifications

**Files Created**:
- `ansible/playbooks/glance/deploy-steam-stats-api.yml` - Steam API service
- `ansible/playbooks/glance/deploy-gaming-steam-widgets.yml` - Glance config update

**User Setup Required**:
1. Install LibreHardwareMonitor on gaming PC, enable HTTP server (port 8085)
2. Get Steam API key from https://steamcommunity.com/dev/apikey
3. Find Steam64 ID from https://steamid.io/
4. Run playbooks with credentials

---

### Backup Jobs Failing - VM Locked Fix
**Status**: Completed
**Issue**: Backup jobs reporting "job errors" - VMs 121 and 109 had orphaned backup locks
**Root Cause**: Node reboots on Jan 13 during scheduled backup jobs left VMs locked
**Fix**:
- `qm unlock 121` on node02 (gitlab-vm01)
- `qm unlock 109` on node03 (linux-syslog-server01)
- Verified backups work (VM 121 completed successfully)
**Documentation Updated**:
- `docs/TROUBLESHOOTING.md` (main repo)
- `12 - Troubleshooting.md` (Obsidian)
- `Hermes Homelab Technical Manual.md` v6.3
- `Book - The Complete Homelab Guide.md`

### PBS-to-NAS Sync Documentation
**Status**: Completed
**Task**: Document how PBS backups are synced to Synology NAS for offsite protection
**Key Details**:
- Script: `/usr/local/bin/pbs-backup-to-nas.sh`
- Schedule: Daily at 2:00 AM via cron
- Syncs `/backup` (main) and `/backup-ssd` (daily) to NAS at 192.168.20.31
- Logs: `/var/log/pbs-nas-sync.log`
**Documentation Updated**:
- `docs/TROUBLESHOOTING.md` (main repo)
- `12 - Troubleshooting.md` (Obsidian)
- `Hermes Homelab Technical Manual.md` v6.3
- `Book - The Complete Homelab Guide.md` (Chapter 27)

### Glance Backup Page Schedule Fix
**Status**: Completed
**Issue**: Backup schedule on Glance backup page showed incorrect times
**Fix**: Updated schedule from "Daily 1:00 AM, Weekly" to correct times
**Correct Schedule**:
- Daily backups: 21:00 (9 PM)
- Main backups: Fridays at midnight
- NAS Direct: Sundays at 01:00
- PBS-to-NAS Sync: 02:00 AM daily
**Changes Made**:
- Updated live Glance config on docker-lxc-glance (192.168.40.12)
- Committed to GitHub: https://github.com/herms14/glance-dashboard (commit f6df506)
- Updated `ansible/playbooks/glance/files/backup-page.yml`
- Updated `gitops-repos/glance-homelab/config/glance.yml`
**Documentation Updated**:
- `docs/GLANCE.md`
- `23 - Glance Dashboard.md` (Obsidian)
- `Hermes Homelab Technical Manual.md` (2 sections)
- `Book - The Complete Homelab Guide.md`

---

## 2026-01-15

### NAS Backup API - Windows VM Names Fix
**Status**: Completed
**Issue**: Windows VMs (300-311) showing as "k8s-ctrl-01" etc. in backup report
**Fix**: Updated `VM_NAMES` in nas-backup-api-app.py and deployed
**Files**: `ansible/playbooks/glance/files/nas-backup-api-app.py`, `gitops-repos/glance-homelab/apis/nas-backup-status-api.py`

### Directory Cleanup & Token Optimization
**Status**: In Progress
**Work**: Removing temp files, consolidating .claude/ files, optimizing claude.md

---

## 2026-01-14

### Azure Sentinel Homelab Integration
**Status**: Partially Complete (VPN-dependent items blocked)
**Completed**:
- Windows DCR Terraform deployed
- Syslog forwarding configured (all Proxmox nodes + Docker hosts)
- VNet NSG flow logs and analytics rules created
**Blocked**: AMA install on Azure DCs (VPN down), OPNsense logging (manual config needed)

### Hybrid AD Extension Playbooks
**Status**: Completed (Playbooks Created)
**Files Created**:
- `ansible/playbooks/azure-ad/promote-onprem-dcs.yml`
- `ansible/playbooks/azure-ad/transfer-fsmo-roles.yml`
- `ansible/playbooks/azure-ad/configure-dns.yml`
- `ansible/playbooks/azure-ad/domain-join-vms.yml`
- `terraform/azure/sentinel/windows-dcr.tf`

---

## 2026-01-13

### Azure Hybrid Lab Full Deployment
**Status**: Completed
**Result**: 12 Windows Server 2022 VMs deployed on node03
**Template**: 9022 (Windows Server 2022 with automated OOBE)
**VMs**: DC01, DC02, FS01, FS02, SQL01, AADCON01, AADPP01, AADPP02, CLIENT01, CLIENT02, IIS01, IIS02
