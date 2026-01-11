# Proxmox Backup Server Monitoring Tutorial

A comprehensive guide to setting up Prometheus monitoring for Proxmox Backup Server (PBS) with Grafana dashboards and Glance integration.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Architecture](#3-architecture)
4. [Part 1: PBS API Token Configuration](#part-1-pbs-api-token-configuration)
5. [Part 2: PBS Exporter Deployment](#part-2-pbs-exporter-deployment)
6. [Part 3: Prometheus Configuration](#part-3-prometheus-configuration)
7. [Part 4: Grafana Dashboard Creation](#part-4-grafana-dashboard-creation)
8. [Part 5: Glance Integration](#part-5-glance-integration)
9. [Metrics Reference](#6-metrics-reference)
10. [Troubleshooting](#7-troubleshooting)
11. [Appendix](#8-appendix)

---

## 1. Overview

### What You'll Build

This tutorial walks you through setting up complete monitoring for Proxmox Backup Server:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PBS Monitoring Stack                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │     PBS      │     │ PBS Exporter │     │  Prometheus  │                │
│  │   Server     │────>│  Container   │────>│              │                │
│  │ (LXC 100)    │     │  Port 9101   │     │  Port 9090   │                │
│  │              │     │              │     │              │                │
│  │ Datastores:  │     │ Metrics:     │     │ Scrape:      │                │
│  │ - daily      │     │ - pbs_up     │     │ - Every 60s  │                │
│  │ - main       │     │ - pbs_used   │     │ - Job: pbs   │                │
│  └──────────────┘     │ - pbs_size   │     └──────┬───────┘                │
│                       └──────────────┘            │                        │
│                                                   │                        │
│                                                   v                        │
│                       ┌──────────────────────────────────────┐             │
│                       │              Grafana                 │             │
│                       │     PBS Backup Status Dashboard      │             │
│                       │                                      │             │
│                       │  ┌────────────────────────────────┐  │             │
│                       │  │ Status | Storage | Snapshots  │  │             │
│                       │  │ ────── │ ─────── │ ────────── │  │             │
│                       │  │  UP    │ 95% /5% │    15      │  │             │
│                       │  └────────────────────────────────┘  │             │
│                       └──────────────────────────────────────┘             │
│                                          │                                 │
│                                          v                                 │
│                       ┌──────────────────────────────────────┐             │
│                       │              Glance                  │             │
│                       │         Backup Page                  │             │
│                       │   (Embedded Grafana Dashboard)       │             │
│                       └──────────────────────────────────────┘             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Why This Setup?

| Benefit | Description |
|---------|-------------|
| **Visibility** | Real-time insight into backup health |
| **Alerting** | Know immediately when backups fail |
| **Capacity Planning** | Track storage consumption trends |
| **Centralization** | All monitoring in one place (Grafana/Glance) |

---

## 2. Prerequisites

### Infrastructure Requirements

| Component | Minimum | This Tutorial |
|-----------|---------|---------------|
| PBS Server | Any version | v3.4 (LXC 100) |
| Docker Host | Any Linux | Ubuntu 22.04 |
| Prometheus | v2.x | v2.45+ |
| Grafana | v9.x | v12.3.1 |

### Network Requirements

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| Exporter | PBS Server | 8007 | API access |
| Prometheus | Exporter | 9101 | Metrics scrape |
| Grafana | Prometheus | 9090 | Query data |
| Browser | Grafana | 3030 | Dashboard access |

### Required Information

Before starting, gather:
- [ ] PBS server IP address (e.g., 192.168.20.50)
- [ ] PBS API user credentials
- [ ] Docker host SSH access
- [ ] Prometheus configuration location

---

## 3. Architecture

### Component Breakdown

```
                           PBS Server
                        192.168.20.50:8007
                              │
                              │ HTTPS API
                              │ (Authorization: PBSAPIToken=user@realm!token:secret)
                              │
                              v
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Docker Host (192.168.40.13)                             │
│                                                                             │
│   ┌─────────────────────────┐     ┌─────────────────────────┐              │
│   │    pbs-exporter         │     │      prometheus         │              │
│   │    ─────────────        │     │      ──────────         │              │
│   │                         │     │                         │              │
│   │  Listens: 0.0.0.0:10019 │     │  Listens: 0.0.0.0:9090  │              │
│   │  Exposed: 9101          │     │                         │              │
│   │                         │     │  Scrape Jobs:           │              │
│   │  ENV Variables:         │────>│  - pbs (60s interval)   │              │
│   │  - PBS_ENDPOINT         │     │                         │              │
│   │  - PBS_USERNAME         │     │  Data Retention: 15d    │              │
│   │  - PBS_API_TOKEN_NAME   │     │                         │              │
│   │  - PBS_API_TOKEN        │     │                         │              │
│   └─────────────────────────┘     └─────────────────────────┘              │
│                                                    │                        │
│   ┌────────────────────────────────────────────────────────────────────┐   │
│   │                         grafana                                    │   │
│   │                         ───────                                    │   │
│   │                                                                    │   │
│   │  Listens: 0.0.0.0:3030                                            │   │
│   │                                                                    │   │
│   │  Datasources:                                                      │   │
│   │  - Prometheus (http://prometheus:9090)                            │   │
│   │                                                                    │   │
│   │  Dashboards:                                                       │   │
│   │  - PBS Backup Status (uid: pbs-backup-status)                     │   │
│   └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│   Network: monitoring_monitoring                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Concepts Explained

| Term | Definition |
|------|------------|
| **PBS API Token** | Authentication credential for programmatic PBS access |
| **Exporter** | Program that exposes metrics in Prometheus format |
| **Scrape** | Prometheus pulling metrics from an endpoint |
| **Job** | Named group of scrape targets in Prometheus |
| **Dashboard** | Grafana visualization of Prometheus metrics |

---

## Part 1: PBS API Token Configuration

### Step 1.1: Access PBS Web Interface

1. Navigate to your PBS web interface:
   ```
   https://<PBS_IP>:8007
   ```

2. Log in with your root credentials (use "Linux PAM" realm)

### Step 1.2: Create API User

> **Note**: You may already have an API user. Skip to Step 1.3 if so.

1. Navigate to **Configuration** → **Access Control** → **Users**
2. Click **Add**
3. Fill in the form:

   | Field | Value | Explanation |
   |-------|-------|-------------|
   | User ID | `backup` | Username for the API user |
   | Realm | `pbs` | PBS authentication realm |
   | Password | (leave empty) | Not needed for API token auth |
   | Email | (optional) | Contact email |
   | Enable | ✓ | User must be enabled |

4. Click **Add**

### Step 1.3: Generate API Token

1. Navigate to **Configuration** → **Access Control** → **API Tokens**
2. Click **Add**
3. Fill in the form:

   | Field | Value | Explanation |
   |-------|-------|-------------|
   | User | `backup@pbs` | The user we created |
   | Token ID | `pve` | Name for this token |
   | Privilege Separation | ✓ | Token has separate permissions |

4. Click **Add**
5. **IMPORTANT**: Copy the token secret that appears - it's shown only once!

   ```
   Token: cae1be63-f700-4af6-9419-198f7cdf0330
   ```

### Step 1.4: Configure Token Permissions

The token needs read access to datastores and node status.

1. Navigate to **Configuration** → **Access Control** → **Permissions**
2. Click **Add** → **API Token Permission**

**Permission 1: Root-level audit (for listing datastores)**

| Field | Value |
|-------|-------|
| Path | `/` |
| API Token | `backup@pbs!pve` |
| Role | `Audit` |
| Propagate | ✓ |

**Permission 2: Datastore access (repeat for each datastore)**

| Field | Value |
|-------|-------|
| Path | `/datastore/daily` |
| API Token | `backup@pbs!pve` |
| Role | `DatastoreReader` |
| Propagate | ✓ |

| Field | Value |
|-------|-------|
| Path | `/datastore/main` |
| API Token | `backup@pbs!pve` |
| Role | `DatastoreReader` |
| Propagate | ✓ |

### Step 1.5: Verify API Access

Test the API token using curl:

```bash
# Replace with your actual values
PBS_IP="192.168.20.50"
TOKEN_ID="backup@pbs!pve"
TOKEN_SECRET="cae1be63-f700-4af6-9419-198f7cdf0330"

# Test API access (should return version info)
curl -sk \
  -H "Authorization: PBSAPIToken=${TOKEN_ID}:${TOKEN_SECRET}" \
  "https://${PBS_IP}:8007/api2/json/version"
```

**Expected output:**
```json
{"data":{"release":"8","repoid":"3c27db8a538196e41111fafd18fd9d80c419456d","version":"3.4"}}
```

**Line-by-Line Explanation:**

| Option | Purpose |
|--------|---------|
| `-s` | Silent mode (no progress bar) |
| `-k` | Allow insecure (self-signed cert) |
| `-H "Authorization: ..."` | Send API token in header |
| Format: `PBSAPIToken=user@realm!tokenname:secret` | PBS API auth format |

---

## Part 2: PBS Exporter Deployment

### Step 2.1: Create Directory Structure

SSH to your Docker host and create the exporter directory:

```bash
ssh hermes-admin@192.168.40.13

# Create directory
sudo mkdir -p /opt/pbs-exporter
cd /opt/pbs-exporter
```

### Step 2.2: Create Docker Compose File

Create the `docker-compose.yml` file:

```bash
sudo tee docker-compose.yml << 'EOF'
services:
  pbs-exporter:
    image: ghcr.io/natrontech/pbs-exporter:latest
    container_name: pbs-exporter
    restart: unless-stopped
    environment:
      # PBS Server URL (include https:// and port)
      PBS_ENDPOINT: "https://192.168.20.50:8007"

      # API user (format: username@realm)
      PBS_USERNAME: "backup@pbs"

      # Token name (just the token ID, not the full path)
      PBS_API_TOKEN_NAME: "pve"

      # Token secret (the long UUID you saved)
      PBS_API_TOKEN: "cae1be63-f700-4af6-9419-198f7cdf0330"

      # Skip TLS verification for self-signed certificates
      PBS_INSECURE: "true"

      # Timeout for API requests
      PBS_TIMEOUT: "30s"

      # Log level (debug/info/warn/error)
      PBS_LOGLEVEL: "info"
    ports:
      # Map external port 9101 to internal port 10019
      - "9101:10019"
    networks:
      - monitoring_monitoring

networks:
  monitoring_monitoring:
    external: true
EOF
```

**Configuration Explained:**

| Variable | Value | Purpose |
|----------|-------|---------|
| `PBS_ENDPOINT` | Full URL with port | Where to find PBS API |
| `PBS_USERNAME` | `backup@pbs` | User@Realm format |
| `PBS_API_TOKEN_NAME` | `pve` | Just the token ID |
| `PBS_API_TOKEN` | UUID secret | The actual token |
| `PBS_INSECURE` | `true` | Accept self-signed certs |
| `PBS_TIMEOUT` | `30s` | Max API wait time |

### Step 2.3: Deploy the Container

```bash
# Deploy
sudo docker compose up -d

# Check it's running
docker ps | grep pbs

# Expected output:
# CONTAINER ID   IMAGE                                    PORTS                     NAMES
# 61058d1fdf54   ghcr.io/natrontech/pbs-exporter:latest   0.0.0.0:9101->10019/tcp   pbs-exporter
```

### Step 2.4: Verify Metrics

Check the exporter is producing metrics:

```bash
# Fetch metrics
curl -s http://localhost:9101/metrics | grep pbs_up

# Expected output:
# # HELP pbs_up Was the last query of PBS successful.
# # TYPE pbs_up gauge
# pbs_up 1
```

If `pbs_up` shows `1`, the exporter is successfully connecting to PBS!

### Step 2.5: Troubleshoot if Needed

If `pbs_up` shows `0`, check logs:

```bash
docker logs pbs-exporter 2>&1 | tail -20
```

**Common errors:**

| Error | Cause | Solution |
|-------|-------|----------|
| `401 Unauthorized` | Wrong token format | Verify user@realm and token |
| `connection refused` | Wrong URL/port | Check PBS_ENDPOINT |
| `certificate error` | TLS issue | Set PBS_INSECURE=true |
| `invalid realm` | Wrong realm | Use `pbs` not `pam` |

---

## Part 3: Prometheus Configuration

### Step 3.1: Add Scrape Job

Edit your Prometheus configuration file:

```bash
# On docker host
sudo nano /opt/monitoring/prometheus/prometheus.yml
```

Add the PBS job at the end of `scrape_configs`:

```yaml
scrape_configs:
  # ... existing jobs ...

  - job_name: 'pbs'
    static_configs:
      - targets: ['192.168.40.13:9101']
        labels:
          instance: 'pbs-lxc100'
    scrape_interval: 60s
```

**Configuration Explained:**

| Field | Value | Purpose |
|-------|-------|---------|
| `job_name` | `pbs` | Identifier in Prometheus |
| `targets` | IP:port | Where to scrape |
| `labels.instance` | Custom label | Identify source in queries |
| `scrape_interval` | `60s` | How often to collect |

### Step 3.2: Reload Prometheus

```bash
# Restart Prometheus to load new config
cd /opt/monitoring
docker compose restart prometheus

# Wait for startup
sleep 10

# Verify config loaded
docker compose logs prometheus | tail -5
```

### Step 3.3: Verify Scrape Target

Check the target is up in Prometheus:

```bash
# Query targets API
curl -s 'http://localhost:9090/api/v1/targets' | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for t in data['data']['activeTargets']:
    if 'pbs' in t['labels'].get('job', ''):
        print(f\"Job: {t['labels']['job']}, Health: {t['health']}, Last: {t['lastScrape']}\")
"

# Expected output:
# Job: pbs, Health: up, Last: 2026-01-11T14:40:00.123Z
```

### Step 3.4: Test Queries

Verify data is flowing:

```bash
# Check pbs_up metric
curl -s 'http://localhost:9090/api/v1/query?query=pbs_up' | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['data']['result'], indent=2))"

# Expected output:
# [
#   {
#     "metric": {
#       "__name__": "pbs_up",
#       "instance": "pbs-lxc100",
#       "job": "pbs"
#     },
#     "value": [1736599200.123, "1"]
#   }
# ]
```

---

## Part 4: Grafana Dashboard Creation

### Step 4.1: Dashboard Overview

The dashboard is organized into sections:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PBS Backup Status Dashboard                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐│
│ │Connection│ │ Version  │ │  Uptime  │ │   CPU    │ │  Memory  │ │Load 5m ││
│ │   UP     │ │  v3.4    │ │  29m 15s │ │   6%     │ │   12%    │ │  0.48  ││
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └────────┘│
├─────────────────────────────────────────────────────────────────────────────┤
│        Datastore Storage                                                     │
│ ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐ ┌──────────────┐   │
│ │  Daily (NVMe)   │ │  Main (HDD)     │ │ Daily Usage  │ │ Main Usage   │   │
│ │    [Pie]        │ │    [Pie]        │ │   [Gauge]    │ │   [Gauge]    │   │
│ │  Used:259MB     │ │  Used:259MB     │ │     0%       │ │     0%       │   │
│ │  Free:869GB     │ │  Free:3.4TB     │ │              │ │              │   │
│ └─────────────────┘ └─────────────────┘ └──────────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────────────────────┤
│        Backup Snapshots                                                      │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐                 │
│ │  Daily Count    │ │  Main Count     │ │  Total Count    │                 │
│ │       0         │ │       0         │ │       0         │                 │
│ └─────────────────┘ └─────────────────┘ └─────────────────┘                 │
├─────────────────────────────────────────────────────────────────────────────┤
│        Storage Usage Over Time                 │  Snapshot Count Over Time  │
│ ┌─────────────────────────────────────────┐   │ ┌─────────────────────────┐ │
│ │         [Line Graph]                    │   │ │     [Line Graph]        │ │
│ │  Daily Used  Main Used                  │   │ │  Daily  Main            │ │
│ └─────────────────────────────────────────┘   │ └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│  PBS Host CPU & IO  │  PBS Host Memory  │  PBS Host Load Average           │
│ ┌─────────────────┐ │ ┌───────────────┐ │ ┌───────────────────────────────┐ │
│ │  [Line Graph]   │ │ │ [Line Graph]  │ │ │        [Line Graph]           │ │
│ │  CPU  IO Wait   │ │ │ Used  Total   │ │ │   1m    5m    15m             │ │
│ └─────────────────┘ │ └───────────────┘ │ └───────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Step 4.2: Create Dashboard JSON

The complete dashboard JSON is saved at:
```
dashboards/pbs-backup-status.json
```

### Step 4.3: Deploy Dashboard

**Option A: Copy to Provisioning Directory**

```bash
# Copy JSON to Grafana dashboards directory
sudo cp dashboards/pbs-backup-status.json \
  /opt/monitoring/grafana/dashboards/

# Restart Grafana to load
docker restart grafana
```

**Option B: Import via Grafana UI**

1. Open Grafana (https://grafana.hrmsmrflrii.xyz)
2. Click **Dashboards** → **Import**
3. Upload the JSON file or paste contents
4. Select **Prometheus** as datasource
5. Click **Import**

### Step 4.4: Verify Dashboard

1. Navigate to **Dashboards** → **Browse**
2. Search for "PBS"
3. Open "PBS Backup Status"
4. Verify panels show data (not "No data")

### Key Panel Queries

| Panel | PromQL Query |
|-------|-------------|
| Connection Status | `pbs_up` |
| Uptime | `pbs_host_uptime` |
| CPU Usage | `pbs_host_cpu_usage` |
| Memory Usage | `pbs_host_memory_used / pbs_host_memory_total` |
| Storage Used % | `pbs_used{datastore="daily"} / pbs_size{datastore="daily"}` |
| Snapshot Count | `sum(pbs_snapshot_count{datastore="daily"})` |

---

## Part 5: Glance Integration

### Step 5.1: Backup Current Config

```bash
ssh hermes-admin@192.168.40.12
sudo cp /opt/glance/config/glance.yml /opt/glance/config/glance.yml.bak
```

### Step 5.2: Add Backup Page

Add the Backup page configuration to glance.yml (after Storage, before Network):

```yaml
- name: Backup
  columns:
  - size: full
    widgets:
    - type: iframe
      title: Proxmox Backup Server
      source: https://grafana.hrmsmrflrii.xyz/d/pbs-backup-status/pbs-backup-status?orgId=1&kiosk&theme=transparent&refresh=1m
      height: 900
  - size: small
    widgets:
    - type: monitor
      title: Backup Services
      cache: 1m
      sites:
      - title: PBS Server
        url: https://192.168.20.50:8007
        icon: si:proxmox
        allow-insecure: true
    - type: bookmarks
      title: Quick Links
      groups:
      - title: Backup Management
        links:
        - title: PBS Web UI
          url: https://192.168.20.50:8007
          icon: si:proxmox
        - title: Grafana Dashboard
          url: https://grafana.hrmsmrflrii.xyz/d/pbs-backup-status
          icon: si:grafana
```

**Configuration Explained:**

| Element | Purpose |
|---------|---------|
| `type: iframe` | Embed Grafana dashboard |
| `&kiosk` | Hide Grafana navigation |
| `&theme=transparent` | Match Glance background |
| `type: monitor` | Show PBS server status |
| `allow-insecure: true` | Accept self-signed cert |

### Step 5.3: Apply Changes

```bash
# Restart Glance
docker restart glance

# Verify logs
docker logs glance --tail 5
```

### Step 5.4: Verify Integration

1. Open Glance (https://glance.hrmsmrflrii.xyz)
2. Click the **Backup** tab
3. Verify:
   - Grafana dashboard loads in iframe
   - PBS server status shows green
   - Quick links work

---

## 6. Metrics Reference

### Connection Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `pbs_up` | Gauge | 1 if connected, 0 if not |
| `pbs_version` | Info | PBS version (labels: version, release) |

### Datastore Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `pbs_size` | Gauge | datastore | Total size in bytes |
| `pbs_used` | Gauge | datastore | Used bytes |
| `pbs_available` | Gauge | datastore | Available bytes |
| `pbs_snapshot_count` | Gauge | datastore, namespace | Number of backups |

### Host Metrics

| Metric | Type | Unit | Description |
|--------|------|------|-------------|
| `pbs_host_cpu_usage` | Gauge | ratio (0-1) | CPU utilization |
| `pbs_host_io_wait` | Gauge | ratio | IO wait percentage |
| `pbs_host_memory_total` | Gauge | bytes | Total RAM |
| `pbs_host_memory_used` | Gauge | bytes | Used RAM |
| `pbs_host_memory_free` | Gauge | bytes | Free RAM |
| `pbs_host_load1` | Gauge | - | 1-minute load average |
| `pbs_host_load5` | Gauge | - | 5-minute load average |
| `pbs_host_load15` | Gauge | - | 15-minute load average |
| `pbs_host_uptime` | Gauge | seconds | System uptime |
| `pbs_host_disk_total` | Gauge | bytes | Root disk size |
| `pbs_host_disk_used` | Gauge | bytes | Root disk used |
| `pbs_host_swap_total` | Gauge | bytes | Total swap |
| `pbs_host_swap_used` | Gauge | bytes | Used swap |

---

## 7. Troubleshooting

### Issue: pbs_up = 0

**Symptoms**: Dashboard shows "DOWN", no datastore metrics

**Check 1: Exporter logs**
```bash
docker logs pbs-exporter 2>&1 | tail -20
```

**Check 2: API connectivity**
```bash
# From exporter host
curl -sk -H 'Authorization: PBSAPIToken=backup@pbs!pve:YOUR_SECRET' \
  https://192.168.20.50:8007/api2/json/version
```

**Common causes:**

| Error Message | Solution |
|---------------|----------|
| `401 Unauthorized` | Verify token ID and secret |
| `invalid realm in user id` | Use `backup@pbs` not `backup@pam` |
| `connection refused` | Check PBS IP and firewall |

### Issue: No Data in Prometheus

**Check target status:**
```bash
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep -A10 pbs
```

**Verify scrape job:**
```bash
grep -A5 'job_name.*pbs' /opt/monitoring/prometheus/prometheus.yml
```

### Issue: Dashboard Shows No Data

**Check 1: Time range**
- Ensure time range includes recent data
- Try "Last 1 hour" or "Last 5 minutes"

**Check 2: Datasource**
- Verify Prometheus datasource is configured
- Test datasource connectivity

**Check 3: Metric names**
```bash
# List available PBS metrics
curl -s http://localhost:9090/api/v1/label/__name__/values | grep pbs
```

### Issue: Glance Page Not Loading

**Check 1: Grafana embed settings**
```bash
# Verify Grafana allows embedding
docker exec grafana grep -i "allow_embedding" /etc/grafana/grafana.ini
```

Should show: `allow_embedding = true`

**Check 2: Iframe URL**
```bash
# Test Grafana dashboard URL directly
curl -I "https://grafana.hrmsmrflrii.xyz/d/pbs-backup-status/pbs-backup-status?kiosk"
```

---

## 8. Appendix

### A. Quick Reference Commands

| Task | Command |
|------|---------|
| Check exporter status | `docker ps \| grep pbs` |
| View exporter logs | `docker logs pbs-exporter` |
| Test metrics endpoint | `curl http://localhost:9101/metrics \| grep pbs_up` |
| Restart exporter | `docker restart pbs-exporter` |
| Reload Prometheus | `docker restart prometheus` |
| Test Prometheus query | `curl 'http://localhost:9090/api/v1/query?query=pbs_up'` |
| Restart Glance | `docker restart glance` |

### B. File Locations

| File | Location | Purpose |
|------|----------|---------|
| Exporter config | `/opt/pbs-exporter/docker-compose.yml` | Docker deployment |
| Prometheus config | `/opt/monitoring/prometheus/prometheus.yml` | Scrape configuration |
| Dashboard JSON | `dashboards/pbs-backup-status.json` | Grafana dashboard |
| Glance config | `/opt/glance/config/glance.yml` | Dashboard pages |

### C. Useful PromQL Queries

```promql
# Storage usage percentage per datastore
pbs_used / pbs_size * 100

# Total storage across all datastores
sum(pbs_size)

# Free storage remaining
sum(pbs_available)

# Average CPU over last hour
avg_over_time(pbs_host_cpu_usage[1h])

# Memory usage percentage
pbs_host_memory_used / pbs_host_memory_total * 100

# Storage growth rate (bytes per day)
rate(pbs_used[24h]) * 86400

# Days until datastore full (assuming linear growth)
pbs_available / rate(pbs_used[7d])
```

### D. Adding Alerts (Optional)

Example Prometheus alerting rules:

```yaml
groups:
- name: pbs_alerts
  rules:
  - alert: PBSDown
    expr: pbs_up == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "PBS server is down"

  - alert: PBSStorageLow
    expr: pbs_available / pbs_size < 0.1
    for: 1h
    labels:
      severity: warning
    annotations:
      summary: "PBS datastore {{ $labels.datastore }} has less than 10% free"

  - alert: NoRecentBackups
    expr: sum(pbs_snapshot_count) == 0
    for: 24h
    labels:
      severity: warning
    annotations:
      summary: "No backups found in PBS"
```

---

## Summary

You've successfully configured:

1. **PBS API Token** - Secure authentication for exporter
2. **PBS Exporter** - Converts PBS API to Prometheus metrics
3. **Prometheus Job** - Scrapes exporter every 60 seconds
4. **Grafana Dashboard** - Visualizes backup status and storage
5. **Glance Integration** - Centralized access via Backup page

The monitoring stack now provides real-time visibility into your Proxmox Backup Server health, storage consumption, and backup counts.

---

## References

- [PBS Exporter GitHub](https://github.com/natrontech/pbs-exporter)
- [Proxmox Backup Server Documentation](https://pbs.proxmox.com/docs/)
- [PBS API Documentation](https://pbs.proxmox.com/docs/api-viewer/index.html)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)
