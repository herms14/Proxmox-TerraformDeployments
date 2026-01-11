# Proxmox Backup Server (PBS) Monitoring

This document covers the setup and configuration of Prometheus monitoring for Proxmox Backup Server.

## Overview

PBS monitoring provides visibility into:
- Backup job status (success/failure)
- Datastore storage usage
- Snapshot counts per datastore
- PBS host resource utilization (CPU, memory, load)

## Architecture

```
+------------------+     +------------------+     +------------------+
|       PBS        |     |   PBS Exporter   |     |    Prometheus    |
| 192.168.20.50    |<--->| 192.168.40.13    |<--->| 192.168.40.13    |
| LXC 100 (node03) |     | Port 9101        |     | Port 9090        |
+------------------+     +------------------+     +------------------+
                                                         |
                                                         v
                                              +------------------+
                                              |     Grafana      |
                                              | 192.168.40.13    |
                                              | Port 3030        |
                                              +------------------+
                                                         |
                                                         v
                                              +------------------+
                                              |      Glance      |
                                              | 192.168.40.12    |
                                              | Backup Page      |
                                              +------------------+
```

## Components

### PBS Server (LXC 100)

| Property | Value |
|----------|-------|
| Host | 192.168.20.50 |
| Node | node03 |
| Web UI | https://192.168.20.50:8007 |
| Version | 3.4 |

### Datastores

| Datastore | Storage Type | Capacity | Purpose |
|-----------|-------------|----------|---------|
| `daily` | Kingston 1TB NVMe | ~1TB | Daily backups (fast restore) |
| `main` | Seagate 4TB HDD | ~4TB | Weekly/monthly backups |

### PBS Exporter

| Property | Value |
|----------|-------|
| Container | `pbs-exporter` |
| Image | `ghcr.io/natrontech/pbs-exporter:latest` |
| Host | docker-vm-core-utilities01 (192.168.40.13) |
| Port | 9101 (external) -> 10019 (internal) |
| Config | `/opt/pbs-exporter/docker-compose.yml` |

## Configuration

### PBS API Token

The exporter authenticates using a PBS API token:

```
User: backup@pbs
Token Name: pve
Token ID: backup@pbs!pve
```

### Docker Compose Configuration

Location: `/opt/pbs-exporter/docker-compose.yml`

```yaml
services:
  pbs-exporter:
    image: ghcr.io/natrontech/pbs-exporter:latest
    container_name: pbs-exporter
    restart: unless-stopped
    environment:
      PBS_ENDPOINT: "https://192.168.20.50:8007"
      PBS_USERNAME: "backup@pbs"
      PBS_API_TOKEN_NAME: "pve"
      PBS_API_TOKEN: "<token-secret>"
      PBS_INSECURE: "true"
      PBS_TIMEOUT: "30s"
    ports:
      - "9101:10019"
    networks:
      - monitoring_monitoring

networks:
  monitoring_monitoring:
    external: true
```

### Prometheus Scrape Configuration

Added to `/opt/monitoring/prometheus/prometheus.yml`:

```yaml
  - job_name: 'pbs'
    static_configs:
      - targets: ['192.168.40.13:9101']
        labels:
          instance: 'pbs-lxc100'
    scrape_interval: 60s
```

## Available Metrics

### Connection Status

| Metric | Description |
|--------|-------------|
| `pbs_up` | 1 if exporter can connect to PBS, 0 otherwise |
| `pbs_version` | PBS version info (labels: version, release, repoid) |

### Datastore Storage

| Metric | Description | Labels |
|--------|-------------|--------|
| `pbs_size` | Total size of datastore in bytes | datastore |
| `pbs_used` | Used bytes in datastore | datastore |
| `pbs_available` | Available bytes in datastore | datastore |

### Backup Snapshots

| Metric | Description | Labels |
|--------|-------------|--------|
| `pbs_snapshot_count` | Number of backup snapshots | datastore, namespace |

### Host Metrics

| Metric | Description |
|--------|-------------|
| `pbs_host_cpu_usage` | CPU usage (0-1) |
| `pbs_host_io_wait` | IO wait percentage |
| `pbs_host_memory_total` | Total memory bytes |
| `pbs_host_memory_used` | Used memory bytes |
| `pbs_host_memory_free` | Free memory bytes |
| `pbs_host_load1` | 1-minute load average |
| `pbs_host_load5` | 5-minute load average |
| `pbs_host_load15` | 15-minute load average |
| `pbs_host_uptime` | Uptime in seconds |
| `pbs_host_disk_total` | Root disk total bytes |
| `pbs_host_disk_used` | Root disk used bytes |
| `pbs_host_disk_available` | Root disk available bytes |
| `pbs_host_swap_total` | Total swap bytes |
| `pbs_host_swap_used` | Used swap bytes |
| `pbs_host_swap_free` | Free swap bytes |

## Grafana Dashboard

| Property | Value |
|----------|-------|
| Dashboard | PBS Backup Status |
| UID | `pbs-backup-status` |
| URL | https://grafana.hrmsmrflrii.xyz/d/pbs-backup-status |
| JSON | `dashboards/pbs-backup-status.json` |

### Dashboard Sections

1. **PBS Status Overview** - Connection status, version, uptime, CPU, memory, load
2. **Datastore Storage** - Pie charts and gauges showing storage usage per datastore
3. **Backup Snapshots** - Snapshot counts for daily and main datastores
4. **Storage Usage Over Time** - Time series of storage usage
5. **PBS Host Metrics** - CPU, memory, and load graphs

## Glance Integration

The Backup page in Glance displays:
- Embedded Grafana dashboard (PBS Backup Status)
- Monitor widget for PBS server health
- Quick links to PBS Web UI and Grafana

Access: https://glance.hrmsmrflrii.xyz → Backup tab

## Useful PromQL Queries

### Storage Usage Percentage

```promql
pbs_used{datastore="daily"} / pbs_size{datastore="daily"} * 100
```

### Total Backup Count

```promql
sum(pbs_snapshot_count)
```

### PBS Memory Usage Percentage

```promql
pbs_host_memory_used / pbs_host_memory_total * 100
```

## Troubleshooting

### Exporter Not Connecting (pbs_up = 0)

1. Check exporter logs:
   ```bash
   docker logs pbs-exporter
   ```

2. Verify PBS API access:
   ```bash
   curl -sk -H 'Authorization: PBSAPIToken=backup@pbs!pve:<secret>' \
     https://192.168.20.50:8007/api2/json/version
   ```

3. Common issues:
   - Wrong API token format (user@realm!tokenname:secret)
   - Network connectivity between exporter and PBS
   - TLS certificate issues (use PBS_INSECURE=true for self-signed)

### No Metrics in Prometheus

1. Check Prometheus targets:
   ```bash
   curl -s 'http://localhost:9090/api/v1/targets' | grep pbs
   ```

2. Test metrics endpoint:
   ```bash
   curl -s http://192.168.40.13:9101/metrics | grep pbs_up
   ```

### Dashboard Shows No Data

1. Verify Prometheus datasource in Grafana
2. Check time range (metrics only available after first scrape)
3. Verify metric names match the exporter output

## Maintenance

### Updating PBS Exporter

```bash
cd /opt/pbs-exporter
docker compose pull
docker compose up -d
```

### Verifying Metrics Collection

```bash
# Check exporter is running
docker ps | grep pbs

# Check metrics endpoint
curl -s http://localhost:9101/metrics | grep -i pbs

# Verify Prometheus scrape
curl -s 'http://localhost:9090/api/v1/query?query=pbs_up'
```

## References

- [PBS Exporter GitHub](https://github.com/natrontech/pbs-exporter)
- [Proxmox Backup Server Documentation](https://pbs.proxmox.com/docs/)
- [PBS API Documentation](https://pbs.proxmox.com/docs/api-viewer/index.html)
