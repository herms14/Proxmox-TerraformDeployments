# PBS Monitoring

> Prometheus monitoring for Proxmox Backup Server with Grafana dashboards and Glance integration.

Related: [[00 - Homelab Index]] | [[18 - Observability Stack]] | [[03 - Storage Architecture]]

---

## Overview

PBS monitoring provides visibility into:
- Backup job status and snapshot counts
- Datastore storage usage (daily/main)
- PBS host resource utilization

## Architecture

```
PBS (192.168.20.50)
        ↓ API (port 8007)
PBS Exporter (192.168.40.13:9101)
        ↓ Scrape
Prometheus (192.168.40.13:9090)
        ↓ Query
Grafana Dashboard + Glance Backup Page
```

## Components

### PBS Server

| Property | Value |
|----------|-------|
| LXC | 100 on node03 |
| IP | 192.168.20.50 |
| Web UI | https://192.168.20.50:8007 |
| Version | 3.4 |

### Datastores

| Datastore | Storage | Capacity | Purpose |
|-----------|---------|----------|---------|
| `daily` | Kingston NVMe | 1TB | Fast daily backups |
| `main` | Seagate HDD | 4TB | Weekly/monthly archives |

### PBS Exporter

| Property | Value |
|----------|-------|
| Container | pbs-exporter |
| Image | ghcr.io/natrontech/pbs-exporter:latest |
| Host | docker-vm-core-utilities01 |
| Port | 9101 |
| Config | /opt/pbs-exporter/docker-compose.yml |

## Configuration

### Docker Compose

```yaml
services:
  pbs-exporter:
    image: ghcr.io/natrontech/pbs-exporter:latest
    container_name: pbs-exporter
    environment:
      PBS_ENDPOINT: "https://192.168.20.50:8007"
      PBS_USERNAME: "backup@pbs"
      PBS_API_TOKEN_NAME: "pve"
      PBS_API_TOKEN: "<secret>"
      PBS_INSECURE: "true"
    ports:
      - "9101:10019"
```

### Prometheus Job

```yaml
- job_name: 'pbs'
  static_configs:
    - targets: ['192.168.40.13:9101']
      labels:
        instance: 'pbs-lxc100'
  scrape_interval: 60s
```

## Key Metrics

| Metric | Description |
|--------|-------------|
| `pbs_up` | Connection status (1=connected) |
| `pbs_size{datastore}` | Total size in bytes |
| `pbs_used{datastore}` | Used bytes |
| `pbs_available{datastore}` | Available bytes |
| `pbs_snapshot_count{datastore}` | Backup count |
| `pbs_host_cpu_usage` | CPU usage (0-1) |
| `pbs_host_memory_*` | Memory metrics |
| `pbs_host_load*` | Load averages |

## Access

| Resource | URL |
|----------|-----|
| PBS Web UI | https://192.168.20.50:8007 |
| Grafana Dashboard | https://grafana.hrmsmrflrii.xyz/d/pbs-backup-status |
| Glance Backup Page | https://glance.hrmsmrflrii.xyz (Backup tab) |
| Metrics Endpoint | http://192.168.40.13:9101/metrics |

## Useful Queries

```promql
# Storage usage percentage
pbs_used{datastore="daily"} / pbs_size{datastore="daily"} * 100

# Total backup count
sum(pbs_snapshot_count)

# Memory usage percentage
pbs_host_memory_used / pbs_host_memory_total * 100
```

## Troubleshooting

### pbs_up = 0

1. Check exporter logs: `docker logs pbs-exporter`
2. Verify API access works with curl
3. Check network connectivity to PBS

### No Data in Dashboard

1. Verify Prometheus target is up
2. Check time range in Grafana
3. Test metrics endpoint directly

## Files

| Location | Purpose |
|----------|---------|
| /opt/pbs-exporter/docker-compose.yml | Exporter config |
| /opt/monitoring/prometheus/prometheus.yml | Scrape config |
| dashboards/pbs-backup-status.json | Dashboard JSON |

## Administration (Updated January 12, 2026)

### Root Password

| Field | Value |
|-------|-------|
| Username | `root` (select "Linux PAM" realm) |
| Password | `NewPBS2025` |

> **Note**: Enter `root` in username field (not `root@pam`). The realm dropdown adds the suffix.

### ACL Permissions

| Principal | Path | Role |
|-----------|------|------|
| `backup@pbs` | `/` | Audit |
| `backup@pbs` | `/datastore/main` | DatastoreAdmin |
| `backup@pbs` | `/datastore/daily` | DatastoreAdmin |
| `backup@pbs!pve` | `/datastore/daily` | DatastoreBackup |

### Subscription Nag Removal

Edit `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js` and flip the condition from `!== 'active'` to `=== 'active'`.

## Drive Health Monitoring

SMART health monitoring for PBS storage drives via custom API on node03.

| Property | Value |
|----------|-------|
| Endpoint | http://192.168.20.22:9101/health |
| Service | `smart-health-api.service` on node03 |
| Drives | Seagate 4TB HDD (main), Kingston 1TB NVMe (daily) |

The Drive Health Status widget is displayed on the Glance Backup page.

## NAS Backup Status API (Updated January 21, 2026)

Custom API that monitors PBS-to-NAS backup sync and lists backups stored on Synology NAS.

| Property | Value |
|----------|-------|
| Host | docker-vm-core-utilities01 (192.168.40.13) |
| Port | 9102 |
| Container | `nas-backup-status-api` |
| Config | `/opt/nas-backup-status-api/` |

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `/status` | Sync status, last sync time, datastore sizes, **job durations** |
| `/backups` | List of all VMs/CTs backed up on NAS |
| `/job-status` | Individual job status with durations |
| `/refresh` | Force cache refresh |
| `/health` | Health check |

### Duration Calculation (Fixed January 21, 2026)

The API calculates backup job duration by grouping contiguous backups:

1. Collects all backup timestamps from PBS datastores
2. Sorts timestamps descending (most recent first)
3. Groups backups within **1 hour** of each other as a single job
4. Returns duration of the most recent job only

**Why This Matters**: When multiple backup jobs run on the same day (e.g., morning and afternoon), the old algorithm incorrectly reported the span of the entire day (7+ hours) instead of the actual job duration (~38 minutes).

```python
# Key algorithm in get_backup_job_status()
job_timestamps = [timestamps[0]]
for i in range(1, len(timestamps)):
    if (job_timestamps[-1] - timestamps[i]).total_seconds() < 3600:
        job_timestamps.append(timestamps[i])
    else:
        break  # Gap found, stop
```

### Test Commands

```bash
curl http://192.168.40.13:9102/status
curl http://192.168.40.13:9102/backups
```

### Glance Widgets

Two widgets on the Backup page use this API:
- **NAS Backup Sync** - Shows sync status with color indicator
- **Backups on NAS** - Lists all protected VMs/CTs with backup dates

### Deployment

```bash
ansible-playbook glance/deploy-nas-backup-status-api.yml
```

## Credentials

See [[11 - Credentials]] for PBS API token details.
