---
banner: "[[999 Attachments/pixel-banner-images/Omada Network Configs.jpg]]"
---
# Glance Dashboard

Glance is a self-hosted dashboard that provides a central view of all homelab services, monitoring, and media statistics. This guide documents how the dashboard was built, including the custom Media Stats grid widget.

## Quick Reference

| Item | Value |
|------|-------|
| **Dashboard URL** | https://glance.hrmsmrflrii.xyz |
| **Internal URL** | http://192.168.40.12:8080 |
| **Config Location** | `/opt/glance/config/glance.yml` |
| **CSS Location** | `/opt/glance/assets/custom-themes.css` |
| **Host** | LXC 200 (lxc-glance) on 192.168.40.12 |

> **Note**: Glance runs on an LXC container with Docker. The docker-compose.yml requires `security_opt: apparmor=unconfined` due to AppArmor restrictions in LXC environments.

## Full-Width Display Fix

By default, Glance limits content width to 1600px via the `.content-bounds` CSS class. To enable full-width display that utilizes the entire monitor:

### Configuration

1. **glance.yml** - Add document-width to theme:
```yaml
theme:
  document-width: 100%
```

2. **custom-themes.css** - Override the content bounds:
```css
/* Full-width display - override default max-width constraint */
.content-bounds {
  max-width: 100% !important;
  width: 100% !important;
  margin-left: 10px !important;
  margin-right: 10px !important;
}
```

### Apply Changes

```bash
# Restart Glance to apply CSS changes
ssh root@192.168.40.12 "cd /opt/glance && docker compose restart"

# If changes don't appear, hard refresh the browser (Ctrl+Shift+R)
```

> **Note**: Browser caching may prevent CSS changes from appearing immediately. Always perform a hard refresh after updating CSS.

## Dashboard Tab Structure (9 Tabs)

| Tab | Protected | Contents |
|-----|-----------|----------|
| **Home** | Yes | Clock, Weather, Bookmarks, Life Progress, Service Health, Markets, Tech News |
| **Compute** | Yes | Proxmox Cluster Dashboard (1100px) + Container Monitoring Dashboard (1400px) |
| **Storage** | Yes | Synology NAS Storage Dashboard (1350px) |
| **Network** | Yes | Omada Network Dashboard (2200px) + Speedtest Widget |
| **Backup** | Yes | PBS Backup Status Dashboard, Drive Health, NAS Backup Sync, Backups on NAS |
| **Media** | Yes | Media Stats Grid, Recent Movies, RSS Feeds, Media Apps Bookmarks |
| **Web** | No | Tech News RSS, AI/ML News, Crypto News, Stock Markets |
| **Reddit** | No | Dynamic Reddit Feed (via Reddit Manager API) |
| **Sports** | Yes | NBA Games, Standings, Yahoo Fantasy League |

> [!warning] Protected Pages
> **Home**, **Compute**, **Storage**, **Network**, **Backup**, **Media**, and **Sports** tabs are finalized layouts. Do not modify without explicit permission.

## Embedded Grafana Dashboards

| Dashboard | UID | Height | Tab | Protected |
|-----------|-----|--------|-----|-----------|
| Network Utilization | `network-utilization` | 1100px | Network | Yes |
| Proxmox Cluster Health | `proxmox-cluster-health` | 1100px | Compute | Yes |
| Proxmox Cluster Overview | `proxmox-compute` | 1100px | Compute | Yes |
| Container Monitoring | `containers-modern` | 1400px | Compute | Yes |
| Container Status History | `container-status` | 1250px | Compute | Yes |
| Synology NAS Storage | `synology-nas-modern` | 1350px | Storage | Yes |
| Omada Network | `omada-network` | 2200px | Network | Yes |
| PBS Backup Status | `pbs-backup-status` | 600px | Backup | Yes |

### Proxmox Cluster Health Dashboard (Added January 11, 2026)

Comprehensive cluster monitoring with hardware temperature tracking:

| Panel | Description |
|-------|-------------|
| Cluster Status | Quorum, Nodes Online, VMs, Containers |
| CPU Temperature | Per-node gauges (node01, node02, node03) |
| Temperature History | 24-hour line chart for all nodes |
| Drive Temperatures | NVMe and GPU temps |
| Resource Usage | Top VMs by CPU, Top VMs by Memory |
| Storage | Pool usage bar gauges |

**Data Sources**:
- `proxmox-nodes` job: node_exporter v1.7.0 on port 9100 (all 3 nodes)
- `proxmox` job: PVE exporter on port 9221

**Temperature Thresholds**: Green (<60°C), Yellow (60-80°C), Red (>80°C)

**Visual Features**:
- All dashboards use `theme=transparent` for seamless integration
- Hidden scrollbars via custom CSS
- Gradient bar gauges with continuous color mode

### Modern Container Monitoring Dashboard

> [!warning] Do Not Modify
> The Container Monitoring dashboard layout is finalized. Do not modify without explicit permission.

The Container Monitoring dashboard uses modern visual design with gradient bar gauges. It displays 5 rows of panels including summary stats, VM summary, memory/CPU usage, and container uptime:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ [Total Containers] [Running]    [Total Memory Used]   [Total CPU Gauge] │  Row 1: Summary Stats
├─────────────────────────────────────────────────────────────────────────┤
│ [Utilities VM Mem] [Utilities #] [Media VM Memory]    [Media #]         │  Row 2: VM Summary
├──────────────────────────────┬──────────────────────────────────────────┤
│ Memory % - Utilities VM      │ Memory % - Media VM                      │  Row 3: Memory Bars
│ ████████░░ container 45%     │ ████████████░ container 62%              │  (sorted high→low)
├──────────────────────────────┼──────────────────────────────────────────┤
│ CPU % - Utilities VM         │ CPU % - Media VM                         │  Row 4: CPU Bars
│ ██████░░░░ container 32%     │ ████████░░ container 45%                 │  (sorted high→low)
├──────────────────────────────┼──────────────────────────────────────────┤
│ Uptime (Hours) - Utilities   │ Uptime (Hours) - Media VM                │  Row 5: Uptime Bars
│ ████████████ container 48h   │ ████████████ container 48h               │  (sorted high→low)
└──────────────────────────────┴──────────────────────────────────────────┘
```

**Row 1: Summary Stats** (colored tiles)
| Panel | Color | Query |
|-------|-------|-------|
| Total Containers | Blue (#3b82f6) | `count(docker_container_running)` |
| Running | Green (#22c55e) | `sum(docker_container_running)` |
| Total Memory Used | Orange (#f59e0b) | `sum(docker_container_memory_usage_bytes)` |
| Total CPU % | Gauge with thresholds | `sum(docker_container_cpu_percent)` |

**Row 2: VM Summary** (colored tiles)
| Panel | Color | Query |
|-------|-------|-------|
| Utilities VM Memory | Purple (#8b5cf6) | `sum(docker_container_memory_usage_bytes{job="docker-stats-utilities"})` |
| Utilities Containers | Purple (#a855f7) | `count(docker_container_running{job="docker-stats-utilities"})` |
| Media VM Memory | Pink (#ec4899) | `sum(docker_container_memory_usage_bytes{job="docker-stats-media"})` |
| Media Containers | Pink (#f472b6) | `count(docker_container_running{job="docker-stats-media"})` |

**Row 3-5: Bar Gauges** (horizontal gradient bars, sorted high→low)
- Memory: Blue-Yellow-Red gradient (`continuous-BlYlRd`), thresholds at 70%/90%
- CPU: Green-Yellow-Red gradient (`continuous-GrYlRd`), thresholds at 50%/80%
- Uptime: Green = 24+ hours (stable), Yellow = 1-24h, Red = <1h (recently restarted)

**Sorting**: All bar gauge panels use `topk()` queries with `sortBy` transformation to display containers from highest to lowest.

### How Container Monitoring Was Built

**1. Docker Stats Exporter Enhancement**

The docker-stats-exporter (`ansible-playbooks/monitoring/docker-stats-exporter.py`) was enhanced to expose container uptime metrics:

```python
# New metrics added
container_uptime_seconds = Gauge(
    'docker_container_uptime_seconds',
    'Container uptime in seconds',
    ['name', 'id', 'image']
)

container_started_at = Gauge(
    'docker_container_started_at',
    'Container start time as Unix timestamp',
    ['name', 'id', 'image']
)
```

**2. Grafana Dashboard (Provisioned)**

The dashboard is provisioned from a JSON file, not managed via API:
- **Location**: `/opt/monitoring/grafana/dashboards/container-monitoring.json`
- **UID**: `containers-modern`
- **Provisioning**: Grafana auto-loads dashboards from this directory on startup

**3. Deployment Process**

```bash
# 1. Deploy docker-stats-exporter to both VMs
ssh hermes-admin@192.168.20.30 "cd ~/ansible && ansible-playbook monitoring/deploy-docker-exporter.yml"

# 2. Copy dashboard JSON to Grafana host (docker-vm-core-utilities-1)
scp temp-container-monitoring.json hermes-admin@192.168.40.13:/opt/monitoring/grafana/dashboards/container-monitoring.json

# 3. Restart Grafana to load new dashboard
ssh hermes-admin@192.168.40.13 "cd /opt/monitoring && docker compose restart grafana"

# 4. Update Glance config and restart (Glance is on LXC)
scp temp-glance-update.py root@192.168.40.12:/tmp/
ssh root@192.168.40.12 "python3 /tmp/temp-glance-update.py && cd /opt/glance && docker compose restart"
```

## Storage Tab (PROTECTED)

> [!warning] Do Not Modify
> The Storage tab layout is finalized. Do not modify without explicit permission.

Displays Synology NAS metrics via embedded Grafana dashboard.

### Dashboard Configuration

| Setting | Value |
|---------|-------|
| **UID** | `synology-nas-modern` |
| **Height** | 1350px |
| **URL** | `https://grafana.hrmsmrflrii.xyz/d/synology-nas-modern/synology-nas-storage?kiosk&theme=transparent&refresh=30s` |
| **Dashboard JSON** | `temp-synology-nas-dashboard.json` |
| **Ansible Playbook** | `ansible-playbooks/monitoring/deploy-synology-nas-dashboard.yml` |

### Layout Structure

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ [RAID Status] [SSD Cache] [Uptime]  [Total]  [Used]  [Storage %]              │  Row 1: Summary
├────────────────────────────────────────────────────────────────────────────────┤
│ [HDD 1]   [HDD 2]   [HDD 3]   [HDD 4]   [M.2 SSD 1]   [M.2 SSD 2]             │  Row 2: Disk Health
│ (green)   (green)   (green)   (green)   (purple)       (purple)                │  (HDDs=green, SSDs=purple)
├────────────────────────────────────────────────────────────────────────────────┤
│ [Disk Temperatures ██████████]    [Sys Temp]  [Healthy]  [CPU Gauge]          │  Row 3: Temps & Stats
│ All 6 drives with gradient        [CPU Cores] [Free]     [Mem Gauge]          │
├────────────────────────────────────────────────────────────────────────────────┤
│ [CPU Usage Over Time]              [Memory Usage Over Time]                    │  Row 4: Time Series
├────────────────────────────────────────────────────────────────────────────────┤
│ [Storage Consumption Over Time - Used (amber) / Free (green) / Total (blue)]  │  Row 5: Storage Timeline
└────────────────────────────────────────────────────────────────────────────────┘
```

### RAID Status Panels (Added January 8, 2026)

Two new panels monitor RAID array health (not just individual disk health):

| Panel | Metric | Description |
|-------|--------|-------------|
| **RAID Status** | `synologyRaidStatus{raidIndex="0"}` | Storage Pool 1 (HDD array) |
| **SSD Cache Status** | `synologyRaidStatus{raidIndex="1"}` | SSD Cache Pool |

**RAID Status Value Mappings:**
| Value | Status | Color | Description |
|-------|--------|-------|-------------|
| 1 | Normal | Green (#22c55e) | Array healthy |
| 2 | REPAIRING | Orange (#f59e0b) | Rebuilding after drive replacement |
| 7 | SYNCING | Blue (#3b82f6) | Data verification in progress |
| 11 | DEGRADED | Red (#ef4444) | Drive failure, needs attention |
| 12 | CRASHED | Red (#ef4444) | Array failed |

> [!tip] Why RAID Status Matters
> Individual disk health (`synologyDiskHealthStatus`) only shows per-disk SMART status. RAID status (`synologyRaidStatus`) shows overall array health. A degraded RAID can show all disks as "Healthy" while the array is rebuilding.

### Disk Configuration

| Slot | Type | Model | Health Color |
|------|------|-------|--------------|
| Disk 1-4 | HDD | WD Red Plus | Green (#22c55e) |
| Disk 5-6 | M.2 SSD | Samsung NVMe | Purple (#8b5cf6) |

### Memory Metrics (Important)

> [!tip] Correct Memory Calculation
> The memory gauge excludes cache/buffers (reclaimable memory) to show actual usage.

**Memory Usage Formula:**
```promql
((memTotalReal - memAvailReal - memBuffer - memCached) / memTotalReal) * 100
```

This shows ~7% actual usage instead of ~95% (which incorrectly treated cache as "used").

**Memory Over Time Chart** shows 3 series:
| Series | Query | Color |
|--------|-------|-------|
| Used (Real) | `memTotalReal - memAvailReal - memBuffer - memCached` | Red (#ef4444) |
| Cache/Buffers | `memCached + memBuffer` | Amber (#f59e0b) |
| Free | `memAvailReal` | Green (#22c55e) |

### Prometheus Metrics

| Metric | Description |
|--------|-------------|
| `synologyRaidStatus` | RAID array health (1=Normal, 2=Repairing, 7=Syncing, 11=Degraded, 12=Crashed) |
| `synologyDiskHealthStatus` | Disk health (1=Normal, 2=Warning, 3=Critical) |
| `synologyDiskTemperature` | Disk temperatures in Celsius |
| `synologyRaidTotalSize` | Total storage capacity (bytes) |
| `synologyRaidFreeSize` | Free storage (bytes) |
| `hrProcessorLoad` | CPU load per core |
| `memTotalReal` | Total memory in KB |
| `memAvailReal` | Available (free) memory in KB |
| `memBuffer` | Buffer memory in KB (reclaimable) |
| `memCached` | Cached memory in KB (reclaimable) |
| `sysUpTime` | System uptime |

## Backup Tab (Added January 12, 2026)

> [!warning] Do Not Modify
> The Backup tab layout is finalized. Do not modify without explicit permission.

The Backup tab provides comprehensive visibility into PBS (Proxmox Backup Server) operations and NAS backup sync status.

### Layout Structure

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     PBS Backup Status Dashboard (Grafana)                        │
│  ┌──────────┬──────────┬──────────┬──────────────┬──────────────┐               │
│  │ PBS Up   │ Snapshots│  Daily   │    Main      │ Backup Count │               │
│  │ (green)  │  (blue)  │  Usage   │   Usage      │  Bar Chart   │               │
│  └──────────┴──────────┴──────────┴──────────────┴──────────────┘               │
├──────────────────────────────┬──────────────────────────────────────────────────┤
│     DRIVE HEALTH STATUS      │              NAS BACKUP STATUS                    │
│     (custom-api widget)      │              (custom-api widgets)                 │
│                              │                                                   │
│  Seagate 4TB: ●● Healthy     │  NAS Backup Sync        │  Backups on NAS         │
│  Kingston 1TB: ●● Healthy    │  ✓ Synced (green)       │  14 Protected           │
│                              │  Last: 2026-01-12       │  7 VMs | 7 CTs          │
│                              │  7.2 TB / 16.0 TB       │  ┌─────────────────┐    │
│                              │                         │  │ VM 100 Jan-12   │    │
│                              │                         │  │ VM 101 Jan-12   │    │
│                              │                         │  │ CT 200 Jan-12   │    │
│                              │                         │  └─────────────────┘    │
└──────────────────────────────┴─────────────────────────┴─────────────────────────┘
```

### Widgets

| Widget | Type | API Endpoint | Cache |
|--------|------|--------------|-------|
| PBS Backup Status | Grafana iframe | `grafana.hrmsmrflrii.xyz/d/pbs-backup-status` | N/A |
| Drive Health Status | custom-api | `http://192.168.20.22:9101/health` | 5m |
| NAS Backup Sync | custom-api | `http://192.168.40.13:9102/status` | 10m |
| Backups on NAS | custom-api | `http://192.168.40.13:9102/backups` | 10m |

### PBS Grafana Dashboard

| Setting | Value |
|---------|-------|
| **UID** | `pbs-backup-status` |
| **Height** | 600px |
| **URL** | `https://grafana.hrmsmrflrii.xyz/d/pbs-backup-status/pbs-backup-status?kiosk&theme=transparent&refresh=60s` |
| **Dashboard JSON** | `dashboards/pbs-backup-status.json` |

**Panels**:
| Panel | Metric | Description |
|-------|--------|-------------|
| PBS Status | `pbs_up` | Connection status (1=connected) |
| Snapshots | `sum(pbs_snapshot_count)` | Total backup count across datastores |
| Daily Usage | `pbs_used{datastore="daily"}` | Kingston NVMe usage |
| Main Usage | `pbs_used{datastore="main"}` | Seagate HDD usage |
| Backup Count | `pbs_snapshot_count` by datastore | Bar chart comparison |

### Drive Health Status Widget

Monitors SMART health of PBS storage drives via custom API running on node03.

| Property | Value |
|----------|-------|
| **API Endpoint** | http://192.168.20.22:9101/health |
| **Service** | `smart-health-api.service` on node03 |
| **Drives Monitored** | Seagate 4TB HDD (main datastore), Kingston 1TB NVMe (daily datastore) |

### NAS Backup Sync Widget

Shows PBS-to-NAS rsync status.

| Property | Value |
|----------|-------|
| **API Endpoint** | http://192.168.40.13:9102/status |
| **Container** | `nas-backup-status-api` on docker-vm-core-utilities01 |
| **Port** | 9102 |

**Displayed Fields**:
| Field | Description |
|-------|-------------|
| Sync Status | ✓ Synced (green) or ✗ Not Synced (red) |
| Last Sync | Timestamp of last successful rsync |
| NAS Usage | Used / Total storage on NAS backup volume |

### Backups on NAS Widget

Lists all VMs and CTs backed up on the Synology NAS.

| Property | Value |
|----------|-------|
| **API Endpoint** | http://192.168.40.13:9102/backups |
| **Container** | `nas-backup-status-api` on docker-vm-core-utilities01 |
| **Port** | 9102 |

**Response Format**:
```json
{
  "backups": [
    {"vmid": "100", "type": "VM", "datastore": "daily", "last_backup": "2026-01-12 14:30"},
    {"vmid": "200", "type": "CT", "datastore": "main", "last_backup": "2026-01-11 02:00"}
  ],
  "total_count": 14,
  "vm_count": 7,
  "ct_count": 7
}
```

**Display**:
- Total protected count with breakdown (VMs | CTs)
- Scrollable list with type indicator (blue=VM, orange=CT)
- Last backup timestamp for each

### NAS Backup Status API

Python Flask/Gunicorn API that queries PBS via SSH.

| Property | Value |
|----------|-------|
| **Host** | docker-vm-core-utilities01 (192.168.40.13) |
| **Port** | 9102 |
| **Container** | `nas-backup-status-api` |
| **Config** | `/opt/nas-backup-status-api/` |

**Endpoints**:
| Endpoint | Description |
|----------|-------------|
| `/status` | Sync status, last sync time, datastore sizes |
| `/backups` | List of all VMs/CTs backed up on NAS with timestamps |
| `/health` | Health check |

**Test Commands**:
```bash
curl http://192.168.40.13:9102/status
curl http://192.168.40.13:9102/backups
curl http://192.168.40.13:9102/health
```

### Deployment

```bash
# Deploy NAS Backup Status API
ansible-playbook glance/deploy-nas-backup-status-api.yml

# Verify API is working
curl http://192.168.40.13:9102/status
curl http://192.168.40.13:9102/backups
```

See also: [[23 - PBS Monitoring]] for detailed PBS monitoring documentation.

## Network Tab (PROTECTED)

> [!warning] Do Not Modify
> The Network tab layout is finalized. Do not modify without explicit permission.

The Network tab provides comprehensive network monitoring via embedded Grafana dashboards.

### Layout Structure

```
┌───────────────────────────────────────────────────────┬──────────────────┐
│                    MAIN (full)                         │  SIDEBAR (small) │
├───────────────────────────────────────────────────────┼──────────────────┤
│ Network Utilization Dashboard (Grafana iframe, h=1100)│ Network Device   │
│ - Cluster & NAS bandwidth stats                       │ Status (custom)  │
│ - Per-node utilization (node01/02/03)                 │                  │
│ - Bandwidth timelines with 1Gbps reference            │ Latest Speedtest │
│ - NAS eth0/eth1 traffic monitoring                    │ (Download/Upload │
│ - Combined cluster + NAS view                         │  Ping/Jitter)    │
├───────────────────────────────────────────────────────┤                  │
│ Omada Network Dashboard (Grafana iframe, h=2200)      │                  │
│ - Overview: Clients, Controller, WiFi modes           │                  │
│ - Device Health: CPU/Memory gauges                    │                  │
│ - WiFi Signal Quality: RSSI, SNR                      │                  │
│ - Switch Port Status: Table                           │                  │
│ - PoE Power Usage                                     │                  │
│ - Traffic Analysis: Top 10 clients (barchart)         │                  │
│ - Client Details: Full table                          │                  │
└───────────────────────────────────────────────────────┴──────────────────┘
```

### Network Utilization Dashboard (Added January 13, 2026)

| Setting | Value |
|---------|-------|
| **UID** | `network-utilization` |
| **Height** | 1100px |
| **URL** | `https://grafana.hrmsmrflrii.xyz/d/network-utilization/network-utilization?kiosk&theme=transparent&refresh=30s` |
| **Dashboard JSON** | `dashboards/network-utilization.json` |
| **Ansible Playbook** | `ansible/playbooks/monitoring/deploy-network-utilization-dashboard.yml` |

**Purpose**: Monitor network bandwidth utilization to determine if upgrading to a 2.5GbE switch would be beneficial.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [Total Cluster]  [Cluster %]  [Peak 24h]  [Avg 24h]  [NAS BW]  [NAS %]      │  Row 1
├──────────────────────────────────┬──────────────────────────────────────────┤
│ [node01] [node02] [node03]       │         [NAS Peak 24h]                   │  Row 2
├──────────────────────────────────┴──────────────────────────────────────────┤
│ Cluster Bandwidth Over Time (per-node RX/TX, 1Gbps reference)               │  Row 3
├─────────────────────────────────────────────────────────────────────────────┤
│ Synology NAS Bandwidth Over Time (eth0/eth1 RX/TX)                          │  Row 4
├─────────────────────────────────────────────────────────────────────────────┤
│ Combined Bandwidth (Cluster + NAS totals, 1Gbps reference)                  │  Row 5
└─────────────────────────────────────────────────────────────────────────────┘
```

**Panels:**
| Panel | Type | Description |
|-------|------|-------------|
| Total Cluster Bandwidth | stat | Combined RX+TX for all Proxmox nodes (vmbr0) |
| Cluster Utilization | gauge | % of 1Gbps capacity (Green <50%, Yellow 50-80%, Red >80%) |
| Peak (24h) | stat | Maximum bandwidth in 24 hours |
| Avg (24h) | stat | Average bandwidth in 24 hours |
| Synology NAS | stat | eth0+eth1 combined bandwidth |
| NAS Utilization | gauge | % of 2Gbps bonded capacity |
| Per-Node Stats | stat | node01, node02, node03 individual |
| Cluster Bandwidth Timeline | timeseries | Per-node RX/TX with 1Gbps reference line |
| NAS Bandwidth Timeline | timeseries | eth0/eth1 RX/TX |
| Combined Bandwidth | timeseries | Cluster Total + NAS Total |

**Data Sources:**
- `proxmox-nodes` job: node_exporter on port 9100 (`node_network_*_bytes_total`)
- `synology` job: SNMP exporter with IF-MIB (`ifHCInOctets`, `ifHCOutOctets`)

**NAS Interface Mapping:**
| Interface | ifIndex | Speed |
|-----------|---------|-------|
| eth0 | 3 | 1Gbps |
| eth1 | 4 | 1Gbps |

**PromQL Examples:**
```promql
# Total cluster bandwidth (bits per second)
sum(rate(node_network_receive_bytes_total{device="vmbr0"}[5m]) +
    rate(node_network_transmit_bytes_total{device="vmbr0"}[5m])) * 8

# NAS combined bandwidth
sum(rate(ifHCInOctets{ifIndex=~"3|4"}[5m]) +
    rate(ifHCOutOctets{ifIndex=~"3|4"}[5m])) * 8
```

### Omada Network Dashboard

| Setting | Value |
|---------|-------|
| **UID** | `omada-network` |
| **Height** | 2200px |
| **URL** | `https://grafana.hrmsmrflrii.xyz/d/omada-network/omada-network-overview?kiosk&theme=transparent&refresh=30s` |
| **Data Source** | Omada Exporter (192.168.20.30:9202) |

**Panels:** Overview stats, Device Health, WiFi Signal Quality, Switch Port Status, PoE Power Usage, Traffic Analysis, Client Details.

## Prometheus Exporters

| Exporter | Port | Target | Metrics |
|----------|------|--------|---------|
| Docker Stats (Utilities) | 9417 | 192.168.40.13 | Container CPU, memory, status, uptime |
| Docker Stats (Media) | 9417 | 192.168.40.11 | Container CPU, memory, status, uptime |
| SNMP Exporter | 9116 | 192.168.20.31 | Synology NAS metrics |
| PVE Exporter | 9221 | Proxmox Nodes | Node CPU, memory, disk |

### Docker Stats Exporter Metrics

| Metric | Description |
|--------|-------------|
| `docker_container_running` | Container status (1=running, 0=stopped) |
| `docker_container_memory_percent` | Memory usage percentage |
| `docker_container_memory_usage_bytes` | Memory usage in bytes |
| `docker_container_cpu_percent` | CPU usage percentage |
| `docker_container_uptime_seconds` | Container uptime in seconds |
| `docker_container_started_at` | Container start time (Unix timestamp) |

### Prometheus Scrape Config

```yaml
- job_name: 'docker-stats-utilities'
  static_configs:
    - targets: ['192.168.40.13:9417']
      labels:
        vm: 'docker-vm-core-utilities-1'

- job_name: 'docker-stats-media'
  static_configs:
    - targets: ['192.168.40.11:9417']
      labels:
        vm: 'docker-vm-media01'
```

## The Media Stats Widget

### Overview

The Media Stats widget displays Radarr and Sonarr statistics in a colorful 3x2 tile grid, similar to Pi-hole's dashboard style.

### Architecture

```
Glance Dashboard (Port 8080)
         │
         │ Fetches from single endpoint
         ▼
Media Stats API (Port 5054)
         │
    ┌────┴────┐
    ▼         ▼
 Radarr    Sonarr
(7878)    (8989)
```

### Why We Need the Media Stats API

**Problem:** Glance's `custom-api` widget can only fetch from ONE URL at a time, but we need data from 6 different API endpoints (3 from Radarr, 3 from Sonarr).

**Solution:** Created a lightweight Python API service that:
1. Fetches all 6 stats from Radarr and Sonarr
2. Combines them into a single JSON response
3. Returns data formatted for the grid widget

## Media Stats API

### Service Details

| Item | Value |
|------|-------|
| **Container** | media-stats-api |
| **Port** | 5054 |
| **Health** | http://192.168.40.13:5054/health |
| **Stats** | http://192.168.40.13:5054/api/stats |
| **Location** | `/opt/media-stats-api/` (on docker-vm-core-utilities-1) |

### API Response Format

```json
{
  "stats": [
    {"label": "WANTED MOVIES", "value": 15, "color": "#f59e0b"},
    {"label": "MOVIES DOWNLOADING", "value": 9, "color": "#3b82f6"},
    {"label": "MOVIES DOWNLOADED", "value": 0, "color": "#22c55e"},
    {"label": "WANTED EPISODES", "value": 1906, "color": "#ef4444"},
    {"label": "EPISODES DOWNLOADING", "value": 98, "color": "#8b5cf6"},
    {"label": "EPISODES DOWNLOADED", "value": 5, "color": "#06b6d4"}
  ],
  "radarr": {"wanted": 15, "downloading": 9, "downloaded": 0},
  "sonarr": {"wanted": 1906, "downloading": 98, "downloaded": 5}
}
```

### Color Reference

| Stat | Hex Color | Color Name |
|------|-----------|------------|
| Wanted Movies | #f59e0b | Amber |
| Movies Downloading | #3b82f6 | Blue |
| Movies Downloaded | #22c55e | Green |
| Wanted Episodes | #ef4444 | Red |
| Episodes Downloading | #8b5cf6 | Purple |
| Episodes Downloaded | #06b6d4 | Cyan |

## Source Code

### media-stats-api.py

```python
#!/usr/bin/env python3
"""
Media Stats API Aggregator
Combines Radarr and Sonarr stats into a single endpoint for Glance dashboard.
"""

import os
import requests
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Configuration from environment variables
RADARR_URL = os.getenv('RADARR_URL', 'http://192.168.40.11:7878')
RADARR_API_KEY = os.getenv('RADARR_API_KEY', '')
SONARR_URL = os.getenv('SONARR_URL', 'http://192.168.40.11:8989')
SONARR_API_KEY = os.getenv('SONARR_API_KEY', '')


def fetch_radarr_stats():
    """Fetch all Radarr statistics."""
    headers = {'X-Api-Key': RADARR_API_KEY}
    stats = {'wanted': 0, 'downloading': 0, 'downloaded': 0}

    try:
        # Wanted movies
        resp = requests.get(f'{RADARR_URL}/api/v3/wanted/missing',
                           headers=headers, params={'pageSize': 1}, timeout=5)
        if resp.ok:
            stats['wanted'] = resp.json().get('totalRecords', 0)

        # Downloading
        resp = requests.get(f'{RADARR_URL}/api/v3/queue',
                           headers=headers, params={'pageSize': 1}, timeout=5)
        if resp.ok:
            stats['downloading'] = resp.json().get('totalRecords', 0)

        # Downloaded (movies with files)
        resp = requests.get(f'{RADARR_URL}/api/v3/movie',
                           headers=headers, timeout=10)
        if resp.ok:
            movies = resp.json()
            stats['downloaded'] = sum(1 for m in movies if m.get('hasFile', False))

    except requests.RequestException as e:
        print(f"Radarr error: {e}")

    return stats


def fetch_sonarr_stats():
    """Fetch all Sonarr statistics."""
    headers = {'X-Api-Key': SONARR_API_KEY}
    stats = {'wanted': 0, 'downloading': 0, 'downloaded': 0}

    try:
        # Wanted episodes
        resp = requests.get(f'{SONARR_URL}/api/v3/wanted/missing',
                           headers=headers, params={'pageSize': 1}, timeout=5)
        if resp.ok:
            stats['wanted'] = resp.json().get('totalRecords', 0)

        # Downloading
        resp = requests.get(f'{SONARR_URL}/api/v3/queue',
                           headers=headers, params={'pageSize': 1}, timeout=5)
        if resp.ok:
            stats['downloading'] = resp.json().get('totalRecords', 0)

        # Downloaded episodes
        resp = requests.get(f'{SONARR_URL}/api/v3/series',
                           headers=headers, timeout=10)
        if resp.ok:
            series = resp.json()
            stats['downloaded'] = sum(
                s.get('statistics', {}).get('episodeFileCount', 0) for s in series
            )

    except requests.RequestException as e:
        print(f"Sonarr error: {e}")

    return stats


@app.route('/api/stats')
def get_stats():
    """Return combined media stats for Glance dashboard grid."""
    radarr = fetch_radarr_stats()
    sonarr = fetch_sonarr_stats()

    return jsonify({
        'stats': [
            {'label': 'WANTED MOVIES', 'value': radarr['wanted'], 'color': '#f59e0b', 'icon': 'movie'},
            {'label': 'MOVIES DOWNLOADING', 'value': radarr['downloading'], 'color': '#3b82f6', 'icon': 'download'},
            {'label': 'MOVIES DOWNLOADED', 'value': radarr['downloaded'], 'color': '#22c55e', 'icon': 'check'},
            {'label': 'WANTED EPISODES', 'value': sonarr['wanted'], 'color': '#ef4444', 'icon': 'tv'},
            {'label': 'EPISODES DOWNLOADING', 'value': sonarr['downloading'], 'color': '#8b5cf6', 'icon': 'download'},
            {'label': 'EPISODES DOWNLOADED', 'value': sonarr['downloaded'], 'color': '#06b6d4', 'icon': 'check'}
        ],
        'radarr': radarr,
        'sonarr': sonarr
    })


@app.route('/health')
def health():
    """Health check endpoint."""
    return jsonify({'status': 'ok'})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5054, debug=False)
```

### Glance Widget Template

```html
<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; padding: 4px;">
  {{ range .JSON.Array "stats" }}
  <div style="background: {{ .String "color" }}; border-radius: 8px; padding: 16px; min-height: 90px; display: flex; flex-direction: column; justify-content: center;">
    <div style="font-size: 11px; color: rgba(255,255,255,0.85); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px; font-weight: 500;">
      {{ .String "label" }}
    </div>
    <div style="font-size: 32px; font-weight: bold; color: #fff;">
      {{ .Int "value" | formatNumber }}
    </div>
  </div>
  {{ end }}
</div>
```

### Ansible Deployment Playbook

Located at: `ansible-playbooks/glance/deploy-media-stats-api.yml`

## Deployment Commands

### Deploy Media Stats API

```bash
# From Ansible controller
cd ~/ansible
ansible-playbook glance/deploy-media-stats-api.yml
```

### Update Glance Configuration

```bash
# Copy update script to LXC and apply
scp temp-media-fix.py root@192.168.40.12:/tmp/
ssh root@192.168.40.12 "python3 /tmp/temp-media-fix.py && cd /opt/glance && docker compose restart"
```

### Redeploy Glance (full)

```bash
cd ~/ansible
ansible-playbook glance/deploy-glance-dashboard.yml
```

## Troubleshooting

### Check Media Stats API

```bash
# Container status (on docker-vm-core-utilities-1)
ssh hermes-admin@192.168.40.13 "docker ps | grep media-stats"

# Logs
ssh hermes-admin@192.168.40.13 "docker logs media-stats-api"

# Test endpoint
curl http://192.168.40.13:5054/api/stats
```

### Check Glance

```bash
# Container status (Glance is on LXC at 192.168.40.12)
ssh root@192.168.40.12 "docker ps | grep glance"

# Logs
ssh root@192.168.40.12 "docker logs glance"

# View config
ssh root@192.168.40.12 "cat /opt/glance/config/glance.yml"
```

### Restart Services

```bash
# Restart Media Stats API (on docker-vm-core-utilities-1)
ssh hermes-admin@192.168.40.13 "cd /opt/media-stats-api && docker compose restart"

# Restart Glance (on LXC)
ssh root@192.168.40.12 "cd /opt/glance && docker compose restart"
```

### Fix Broken Icons (Arr Stack)

If icons show as placeholder squares, replace `si:` icons with Dashboard Icons URLs:

```bash
# Fix all broken arr stack icons (Glance is on LXC at 192.168.40.12)
ssh root@192.168.40.12 'sed -i "s|icon: si:lidarr|icon: https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/lidarr.png|g" /opt/glance/config/glance.yml'
ssh root@192.168.40.12 'sed -i "s|icon: si:prowlarr|icon: https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/prowlarr.png|g" /opt/glance/config/glance.yml'
ssh root@192.168.40.12 'sed -i "s|icon: si:bazarr|icon: https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/bazarr.png|g" /opt/glance/config/glance.yml'
ssh root@192.168.40.12 'sed -i "s|icon: si:jellyseerr|icon: https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/jellyseerr.png|g" /opt/glance/config/glance.yml'
ssh root@192.168.40.12 'sed -i "s|icon: si:tdarr|icon: https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/tdarr.png|g" /opt/glance/config/glance.yml'
ssh root@192.168.40.12 'cd /opt/glance && docker compose restart'
```

**Icon Sources**:
| Source | Format | Example |
|--------|--------|---------|
| Simple Icons | `si:iconname` | `si:radarr` |
| Dashboard Icons | Full URL | `https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/radarr.png` |

## Files Reference

| File | Location | Purpose |
|------|----------|---------|
| media-stats-api.py | `/opt/media-stats-api/` | API source code |
| docker-compose.yml | `/opt/media-stats-api/` | API container config |
| glance.yml | `/opt/glance/config/` | Dashboard config |
| custom-themes.css | `/opt/glance/assets/` | Custom CSS themes |
| container-monitoring.json | `/opt/monitoring/grafana/dashboards/` | Grafana dashboard JSON |
| docker-stats-exporter.py | `ansible-playbooks/monitoring/` | Prometheus exporter |
| deploy-media-stats-api.yml | `ansible-playbooks/glance/` | API deployment |
| deploy-glance-dashboard.yml | `ansible-playbooks/glance/` | Dashboard deployment |
| deploy-docker-exporter.yml | `ansible-playbooks/monitoring/` | Exporter deployment |
| temp-media-fix.py | Repository root | Media page updater |
| temp-home-fix.py | Repository root | Home page updater |
| temp-glance-update.py | Repository root | Full dashboard updater |
| temp-container-monitoring.json | Repository root | Dashboard JSON source |
| temp-enhanced-container-dashboard.py | Repository root | Dashboard generation script |

## Home Page Configuration

> [!warning] Do Not Modify
> The Home page layout is finalized. Do not modify without explicit permission.

### Layout Structure

```
┌──────────────────┬──────────────────────────────────────────┬──────────────────┐
│   LEFT (small)   │              CENTER (full)                │  RIGHT (small)   │
├──────────────────┼──────────────────────────────────────────┼──────────────────┤
│ Chess.com Stats  │ Life Progress Widget                      │ Crypto Markets   │
│ Clock            │ GitHub Contributions (green, dark mode)   │ Stock Markets    │
│ Weather          │ Proxmox Cluster Monitor (2 nodes)         │ Tech News RSS    │
│ Sun Times        │ Storage Monitor                           │                  │
│ Calendar         │ Core Services Monitor                     │                  │
│ Daily Note       │ Media Services Monitor                    │                  │
│ Infrastructure   │ Monitoring Stack Monitor                  │                  │
│ Services         │                                           │                  │
└──────────────────┴──────────────────────────────────────────┴──────────────────┘
```

> **Note**: Kubernetes monitors were removed because Glance (VLAN 40) cannot reach K8s nodes (VLAN 20) due to firewall/routing rules.

### Left Column Widgets

| Widget | Configuration |
|--------|---------------|
| Chess.com Stats | Blitz & Rapid ratings (username: hrmsmrflrii) |
| Clock | 24h format, Asia/Manila timezone |
| Weather | Manila, Philippines, metric units |
| Sun Times | Sunrise/sunset via sunrise-sunset.org API |
| Calendar | Monday first day |
| Daily Note | Obsidian daily note via Local REST API |
| Infrastructure Bookmarks | Authentik, Omada Cloud, Proxmox, Traefik, OPNsense, Portainer, Synology NAS |
| Services Bookmarks | Media (8), Downloads (2), Productivity (4), Monitoring (5) |

### Chess.com Widget

Displays chess ratings using the public Chess.com API.

| Setting | Value |
|---------|-------|
| **Stats API** | `https://api.chess.com/pub/player/hrmsmrflrii/stats` |
| **Profile API** | `https://api.chess.com/pub/player/hrmsmrflrii` (for avatar) |
| **User-Agent** | Required - API blocks requests without it |
| **Template** | Direct path syntax: `{{ .JSON.Int "chess_blitz.last.rating" }}` |
| **Displays** | Profile photo, Blitz rating, Rapid rating, W/L records |

### Obsidian Daily Notes Widget

Displays today's daily note from the Obsidian vault on MacBook.

| Setting | Value |
|---------|-------|
| **API URL** | `http://100.90.207.58:27123/vault/05%20Periodic%20Notes/00%20Daily/YYYY-MM-DD.md` |
| **MacBook Tailscale IP** | 100.90.207.58 |
| **Port** | 27123 |
| **API Key** | See [[11 - Credentials]] |

**Requirements:**
1. Obsidian running on MacBook
2. Local REST API plugin installed and enabled
3. Plugin must bind to `0.0.0.0` (Settings > Local REST API > Network Interface)
4. MacBook connected to Tailscale

### Center Column Widgets

| Widget | Type | Endpoint |
|--------|------|----------|
| Life Progress | custom-api | http://192.168.40.13:5051/progress |
| GitHub Contributions | custom-api | https://api.github.com/users/herms14 |
| Proxmox Cluster | monitor | Node 01-02 on port 8006 |
| Storage | monitor | Synology NAS on VLAN 10 & 20, port 5001 |
| Core Services | monitor | Traefik, Authentik, GitLab, Immich, n8n, Paperless, Pi-hole, Karakeep, Lagident |
| Media Services | monitor | Jellyfin, Radarr, Sonarr, Lidarr, Prowlarr, Bazarr, Jellyseerr, Tdarr, Deluge, SABnzbd, Wizarr, Tracearr |
| Monitoring Stack | monitor | Uptime Kuma, Prometheus, Grafana, Jaeger, Glance, Speedtest |

### Right Column Widgets

| Widget | Configuration |
|--------|---------------|
| Crypto Markets | BTC-USD, ETH-USD, XRP-USD, BNB-USD, ADA-USD |
| Stock Markets | MSFT, AAPL, ORCL, NVDA, GOOGL, TSLA, NFLX, AMZN |
| Tech News RSS | r/homelab, r/selfhosted (horizontal cards, limit 5) |

### GitHub Contribution Graph

- **Service**: ghchart.rshah.org
- **Color**: `#40c463` (GitHub green)
- **Dark Mode**: CSS filter `invert(1) hue-rotate(180deg)`
- **Stats**: Repos, followers, following from GitHub API

### Health Check Endpoints

| Service | Endpoint | Port |
|---------|----------|------|
| Proxmox Nodes (2) | / | 8006 (HTTPS) |
| Synology NAS | / | 5001 (HTTPS) |
| Traefik | /ping | 8082 |
| Authentik | /-/health/ready/ | 9000 |
| Prometheus | /-/healthy | 9090 |
| Grafana | /api/health | 3030 |

### Deploy Home Page

```bash
# Copy update script to LXC and apply
scp temp-home-fix.py root@192.168.40.12:/tmp/
ssh root@192.168.40.12 "python3 /tmp/temp-home-fix.py && cd /opt/glance && docker compose restart"
```

## Sports Tab

> [!warning] Do Not Modify
> The Sports tab layout is finalized. Do not modify without explicit permission.

The Sports tab displays NBA data and Yahoo Fantasy league information using a custom NBA Stats API.

### Quick Reference

| Item | Value |
|------|-------|
| **API URL** | http://192.168.40.13:5060 |
| **Container** | nba-stats-api |
| **Files Location** | `/opt/nba-stats-api/` (on docker-vm-core-utilities-1) |
| **OAuth Token** | `/opt/nba-stats-api/data/yahoo_token.json` |

### Layout (3 columns, 7 widgets)

```
┌──────────────────┬───────────────────────────────────┬──────────────────┐
│  TODAY'S GAMES   │         NBA STANDINGS             │  FANTASY LEAGUE  │
│  (small column)  │         (full column)             │  (small column)  │
│                  │                                   │                  │
│  Live scores     │  Eastern      │     Western       │  League Standings│
│  with logos      │  Conference   │     Conference    │  W-L Records     │
├──────────────────┤  15 teams     │     15 teams      ├──────────────────┤
│  INJURY REPORT   │               │                   │  WEEK MATCHUPS   │
│  Player photos   │  Green = Playoff (1-6)            │  Current week    │
│  Status colors   │  Yellow = Play-in (7-10)          │  matchup scores  │
│  Out/Day-to-Day  ├───────────────────────────────────┼──────────────────┤
│                  │         NBA NEWS                  │  HOT PICKUPS     │
│                  │  Headlines with images            │  Top 10 available│
│                  │  6 latest articles                │  PTS/AST/REB     │
└──────────────────┴───────────────────────────────────┴──────────────────┘
```

### API Endpoints

| Endpoint | Cache | Description |
|----------|-------|-------------|
| `/health` | - | Health check |
| `/games` | 2m | Today's NBA games with team logos |
| `/standings` | 15m | NBA standings (East/West) with logos |
| `/injuries` | 15m | NBA injury report with player headshots |
| `/news` | 15m | NBA news headlines with images |
| `/fantasy` | 15m | Yahoo Fantasy league standings |
| `/fantasy/matchups` | 5m | Current week H2H matchups |
| `/fantasy/recommendations` | 30m | Top 10 available free agents with stats (PTS/AST/REB) |

### Player Headshots

Player photos are pulled from ESPN CDN:
```
https://a.espncdn.com/i/headshots/nba/players/full/{player_id}.png
```

### Injury Status Colors

| Status | Color |
|--------|-------|
| Out | Red (#ef4444) |
| Day-To-Day | Yellow (#f59e0b) |
| Other | Gray (#888) |

### Yahoo Fantasy Configuration

- **League ID**: `466.l.12095` (2024-25 NBA season)
- **League Type**: Head-to-Head Categories
- **Update Schedule**: Daily at 2pm (Asia/Manila timezone)
- **OAuth Token**: Auto-refreshes (stored in `/opt/nba-stats-api/data/yahoo_token.json`)

### Team Logos

Team logos are pulled dynamically from ESPN CDN - not stored locally.

### Ansible Playbook

```bash
ansible-playbook glance/deploy-nba-stats-api.yml
```

## Web Tab

The Web tab is a comprehensive tech news aggregator with collapsible sections for all categories.

### Layout (2 columns)

```
┌───────────────────────────────────────────────────────┬──────────────────┐
│                    MAIN (full)                         │  SIDEBAR (small) │
├───────────────────────────────────────────────────────┼──────────────────┤
│ Tech YouTube (7 channels, horizontal-cards)           │ Tech Stocks (8)  │
│ Tech News (The Verge, XDA, TechCrunch, Ars Technica) │ Crypto (5)       │
│ Android & Mobile (XDA Mobile, Google News, r/Android) │ Crypto News      │
│ AI & Machine Learning (TechCrunch AI, Reddit feeds)   │ Stock Market     │
│ Cloud & Enterprise (AWS, Azure, GCP, Oracle)          │ Quick Links      │
│ Big Tech (Microsoft, NVIDIA, Google, Apple, Meta)     │                  │
│ Gaming (r/gaming, r/pcgaming, Ars Gaming)             │                  │
│ PC Builds & Hardware (r/buildapc, r/pcmasterrace)     │                  │
│ Travel (r/travel, r/solotravel, r/TravelHacks)        │                  │
└───────────────────────────────────────────────────────┴──────────────────┘
```

### YouTube Channels

| Channel | Channel ID |
|---------|------------|
| MKBHD | UCBJycsmduvYEL83R_U4JriQ |
| Linus Tech Tips | UCXuqSBlHAE6Xw-yeJA0Tunw |
| Mrwhosetheboss | UCMiJRAwDNSNzuYeN2uWa0pA |
| Dave2D | UCVYamHliCI9rw1tHR1xbkfw |
| Austin Evans | UCXGgrKt94gR6lmN4aN3mYTg |
| JerryRigEverything | UCWFKCr40YwOZQx8FHU_ZqqQ |
| Fireship | UCsBjURrPoezykLs9EqgamOA |

### News Sources

| Category | Sources |
|----------|---------|
| Tech News | The Verge, XDA, TechCrunch, Ars Technica |
| AI/ML | TechCrunch AI, r/artificial, r/MachineLearning, r/LocalLLaMA, r/ChatGPT |
| Cloud | AWS Blog, r/aws, r/googlecloud, r/azure, r/oracle |
| Big Tech | r/microsoft, r/NVIDIA, r/google, r/apple, r/Meta |
| Gaming | r/gaming, r/pcgaming, r/Games, Ars Gaming |
| PC Builds | r/buildapc, r/pcmasterrace, r/hardware, XDA Computing |
| Travel | r/travel, r/solotravel, r/TravelHacks |

### Markets (Sidebar)

| Type | Symbols |
|------|---------|
| Tech Stocks | MSFT, NVDA, ORCL, AMZN, GOOGL, META, AAPL, BABA |
| Crypto | BTC-USD, ETH-USD, XRP-USD, SOL-USD, DOGE-USD |

### Configuration Script

`temp-glance-web-reddit-update.py`

## Reddit Tab

The Reddit tab provides a dynamic Reddit feed aggregator with thumbnails and native Reddit widgets.

### Layout (2 columns)

```
┌───────────────────────────────────────────────────────┬──────────────────┐
│                    MAIN (full)                         │  SIDEBAR (small) │
├───────────────────────────────────────────────────────┼──────────────────┤
│ Reddit Manager Dynamic Feed (16 subreddits)           │ r/technology     │
│ - Posts grouped by subreddit                          │ r/programming    │
│ - Thumbnails on posts                                 │ r/sysadmin       │
│ - Score and comment counts                            │ Subreddit Links  │
│ - Manage subreddits link                              │                  │
└───────────────────────────────────────────────────────┴──────────────────┘
```

### Reddit Manager API

| Item | Value |
|------|-------|
| **Web UI** | http://192.168.40.13:5053 |
| **API Endpoint** | http://192.168.40.13:5053/api/feed |

### Configured Subreddits (16 total)

| Category | Subreddits |
|----------|------------|
| Homelab | homelab, selfhosted, datahoarder |
| DevOps | linux, devops, kubernetes, docker |
| Tech | technology, programming, webdev, sysadmin, netsec |
| Hobby | gaming, pcmasterrace, buildapc, mechanicalkeyboards |

### Settings

- **Sort**: `hot` (options: hot, new, top)
- **View**: `grouped` (options: grouped, combined)

### Native Reddit Widgets (Sidebar)

- r/technology (hot, thumbnails, limit 8)
- r/programming (hot, thumbnails, limit 6)
- r/sysadmin (hot, thumbnails, limit 6)

### Deployment Playbook

```bash
ansible-playbook glance/deploy-web-reddit-update.yml
```

## Related Documentation

- [[07 - Deployed Services]] - All deployed services
- [[21 - Application Configurations]] - Detailed app configurations
- [[08 - Arr Media Stack]] - Radarr, Sonarr, and related services
- [[09 - Traefik Reverse Proxy]] - Reverse proxy configuration
- [[11 - Credentials]] - API keys and credentials
