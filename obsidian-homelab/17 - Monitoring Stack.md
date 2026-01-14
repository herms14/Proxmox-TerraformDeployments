# Monitoring Stack

> **Internal Documentation** - Contains monitoring credentials and configuration.

Related: [[00 - Homelab Index]] | [[07 - Deployed Services]] | [[09 - Traefik Reverse Proxy]]

---

## Monitoring Overview

**Status**: Deployed December 21, 2025

Complete monitoring stack deployed on docker-vm-core-utilities01 (192.168.40.13) with three integrated services:
- **Uptime Kuma** - Service uptime monitoring and status pages
- **Prometheus** - Metrics collection and time-series database
- **Grafana** - Metrics visualization and dashboarding

> **See also**: [[18 - Observability Stack]] for distributed tracing with OpenTelemetry and Jaeger.

---

## Service URLs

### HTTPS (via Traefik)

| Service | URL | Purpose |
|---------|-----|---------|
| Uptime Kuma | https://uptime.hrmsmrflrii.xyz | Uptime monitoring dashboard |
| Prometheus | https://prometheus.hrmsmrflrii.xyz | Metrics database and query interface |
| Grafana | https://grafana.hrmsmrflrii.xyz | Metrics visualization and dashboards |

### Direct Access (HTTP)

| Service | URL | Backend Port |
|---------|-----|--------------|
| Uptime Kuma | http://192.168.40.13:3001 | 3001 |
| Prometheus | http://192.168.40.13:9090 | 9090 |
| Grafana | http://192.168.40.13:3030 | 3030 |

---

## Uptime Kuma

**Status monitoring and alerting platform**

### Features

- Real-time service uptime monitoring
- HTTP/HTTPS endpoint checks
- TCP port monitoring
- Status pages for external sharing
- Multi-channel notifications (Discord, email, Slack, etc.)
- Response time tracking
- Certificate expiration monitoring

### Configuration

| Setting | Value |
|---------|-------|
| Host | docker-vm-core-utilities01 |
| IP | 192.168.40.13 |
| Port | 3001 |
| Storage | `/opt/monitoring/uptime-kuma/data` |
| URL | https://uptime.hrmsmrflrii.xyz |

### Initial Setup

1. Navigate to https://uptime.hrmsmrflrii.xyz
2. Create admin account on first access
3. Add monitors for homelab services

### Common Monitors

Add these monitors to track homelab infrastructure:

| Monitor Name | Type | Target | Check Interval |
|--------------|------|--------|----------------|
| Proxmox Node01 | HTTPS | https://node01.hrmsmrflrii.xyz | 60s |
| Proxmox Node02 | HTTPS | https://node02.hrmsmrflrii.xyz | 60s |
| Proxmox Node03 | HTTPS | https://node03.hrmsmrflrii.xyz | 60s |
| Traefik | HTTPS | https://traefik.hrmsmrflrii.xyz | 60s |
| Authentik | HTTPS | https://auth.hrmsmrflrii.xyz | 60s |
| GitLab | HTTPS | https://gitlab.hrmsmrflrii.xyz | 120s |
| Jellyfin | HTTPS | https://jellyfin.hrmsmrflrii.xyz | 60s |

---

## Prometheus

**Metrics collection and time-series database**

### Features

- Time-series metrics storage
- Powerful query language (PromQL)
- Service discovery
- Alert rules engine
- Pull-based metric collection
- Integration with Grafana

### Configuration

| Setting | Value |
|---------|-------|
| Host | docker-vm-core-utilities01 |
| IP | 192.168.40.13 |
| Port | 9090 |
| Config | `/opt/monitoring/prometheus/prometheus.yml` |
| Data | `/opt/monitoring/prometheus/data` |
| URL | https://prometheus.hrmsmrflrii.xyz |

### Scrape Targets

Configure Prometheus to scrape metrics from:

```yaml
# Example prometheus.yml configuration
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - '192.168.20.20:9100'  # node01
        - '192.168.20.21:9100'  # node02
        - '192.168.20.22:9100'  # node03

  - job_name: 'docker-hosts'
    static_configs:
      - targets:
        - '192.168.40.13:9100'  # docker-vm-core-utilities01
        - '192.168.40.11:9100'  # docker-vm-media01

  - job_name: 'kubernetes'
    static_configs:
      - targets:
        - '192.168.20.32:10250'  # k8s-controller01
        - '192.168.20.33:10250'  # k8s-controller02
        - '192.168.20.34:10250'  # k8s-controller03

  # Observability Stack (See [[18 - Observability Stack]])
  - job_name: 'traefik'
    static_configs:
      - targets: ['192.168.40.20:8082']

  - job_name: 'otel-collector'
    static_configs:
      - targets: ['192.168.40.13:8888', '192.168.40.13:8889']

  - job_name: 'jaeger'
    static_configs:
      - targets: ['192.168.40.13:14269']

  - job_name: 'demo-app'
    static_configs:
      - targets: ['192.168.40.13:5000']
```

### Useful Queries (PromQL)

```promql
# CPU usage percentage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))

# Disk usage percentage
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)

# Network traffic (bytes received)
rate(node_network_receive_bytes_total[5m])
```

---

## Grafana

**Metrics visualization and dashboarding**

### Features

- Interactive dashboards
- Multiple data source support (Prometheus, InfluxDB, etc.)
- Custom visualizations (graphs, gauges, tables)
- Alert notifications
- User management and permissions
- Dashboard sharing and templates

### Configuration

| Setting | Value |
|---------|-------|
| Host | docker-vm-core-utilities01 |
| IP | 192.168.40.13 |
| Port | 3030 |
| Config | `/opt/monitoring/grafana/config` |
| Data | `/opt/monitoring/grafana/data` |
| URL | https://grafana.hrmsmrflrii.xyz |

### Initial Setup

1. Navigate to https://grafana.hrmsmrflrii.xyz
2. Login with default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
3. Change password immediately
4. Add Prometheus data source:
   - **URL**: `http://192.168.40.13:9090`
   - **Access**: Server (default)

### Recommended Dashboards

Import these community dashboards (Dashboard ID):

| Dashboard | ID | Purpose |
|-----------|-----|---------|
| Node Exporter Full | 1860 | Complete system metrics |
| Proxmox VE | 10347 | Proxmox cluster monitoring |
| Docker Container & Host Metrics | 179 | Docker monitoring |
| Kubernetes Cluster Monitoring | 7249 | K8s cluster overview |
| Traefik 2.2 | 11462 | Traefik reverse proxy |

### Data Source Configuration

**Prometheus Data Source**:
```
Name: Prometheus
Type: Prometheus
URL: http://192.168.40.13:9090
Access: Server (default)
Scrape interval: 15s
```

**Jaeger Data Source** (for distributed tracing):
```
Name: Jaeger
Type: Jaeger
URL: http://192.168.40.13:16686
Access: Server (default)
```

> See [[18 - Observability Stack]] for Jaeger configuration and trace visualization.

---

## Docker Compose Configuration

### Directory Structure

```
/opt/monitoring/
├── docker-compose.yml
├── prometheus/
│   ├── prometheus.yml
│   └── data/
├── grafana/
│   ├── config/
│   └── data/
└── uptime-kuma/
    └── data/
```

### Docker Compose File

```yaml
version: '3.8'

services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    volumes:
      - ./uptime-kuma/data:/app/data
    ports:
      - "3001:3001"
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.uptime.rule=Host(`uptime.hrmsmrflrii.xyz`)"
      - "traefik.http.services.uptime.loadbalancer.server.port=3001"

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    ports:
      - "9090:9090"
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.hrmsmrflrii.xyz`)"
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    volumes:
      - ./grafana/data:/var/lib/grafana
      - ./grafana/config:/etc/grafana
    environment:
      - GF_SERVER_HTTP_PORT=3030
      - GF_SECURITY_ADMIN_PASSWORD=admin
    ports:
      - "3030:3030"
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.hrmsmrflrii.xyz`)"
      - "traefik.http.services.grafana.loadbalancer.server.port=3030"
```

---

## DNS Configuration

### OPNsense Host Overrides

DNS records added to OPNsense (192.168.91.30) for monitoring services:

| Hostname | Domain | IP Address | Description |
|----------|--------|------------|-------------|
| uptime | hrmsmrflrii.xyz | 192.168.40.20 | Uptime Kuma (via Traefik) |
| prometheus | hrmsmrflrii.xyz | 192.168.40.20 | Prometheus (via Traefik) |
| grafana | hrmsmrflrii.xyz | 192.168.40.20 | Grafana (via Traefik) |

---

## Traefik Integration

### Dynamic Configuration

Monitoring services are routed through Traefik reverse proxy (192.168.40.20).

**Traefik Configuration**: `/opt/traefik/config/dynamic/services.yml`

```yaml
http:
  routers:
    uptime:
      rule: "Host(`uptime.hrmsmrflrii.xyz`)"
      service: uptime
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare

    prometheus:
      rule: "Host(`prometheus.hrmsmrflrii.xyz`)"
      service: prometheus
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare

    grafana:
      rule: "Host(`grafana.hrmsmrflrii.xyz`)"
      service: grafana
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare

  services:
    uptime:
      loadBalancer:
        servers:
          - url: "http://192.168.40.13:3001"

    prometheus:
      loadBalancer:
        servers:
          - url: "http://192.168.40.13:9090"

    grafana:
      loadBalancer:
        servers:
          - url: "http://192.168.40.13:3030"
```

---

## Ansible Deployment

### Playbook

Monitoring stack deployed via Ansible playbook on ansible-controller01.

**Playbook**: `~/ansible/monitoring/deploy-monitoring-stack.yml`

```bash
# Deploy monitoring stack
ssh ansible-controller01
cd ~/ansible
ansible-playbook monitoring/deploy-monitoring-stack.yml
```

---

## Management Commands

### View Logs

```bash
# All services
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose logs -f"

# Specific service
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose logs -f uptime-kuma"
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose logs -f prometheus"
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose logs -f grafana"
```

### Restart Services

```bash
# All services
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose restart"

# Specific service
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose restart uptime-kuma"
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose restart prometheus"
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose restart grafana"
```

### Update Services

```bash
# Pull latest images
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose pull"

# Recreate containers with new images
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose up -d"
```

### Check Status

```bash
# Container status
ssh docker-vm-core-utilities01 "cd /opt/monitoring && sudo docker compose ps"

# Resource usage
ssh docker-vm-core-utilities01 "docker stats uptime-kuma prometheus grafana --no-stream"
```

---

## Alerting Configuration

### Uptime Kuma Notifications

Configure notifications in Uptime Kuma dashboard:

**Discord Webhook** (recommended):
1. Settings → Notifications → Add New Notification
2. Type: Discord
3. Webhook URL: `https://discord.com/api/webhooks/YOUR_WEBHOOK`
4. Save and test

### Grafana Alerts

Configure alert rules in Grafana:

**Example Alert** (High CPU):
```
Alert Name: High CPU Usage
Query: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
Condition: WHEN avg() OF query(A, 5m, now) IS ABOVE 80
```

---

## Monitoring Metrics

### System Metrics (Node Exporter)

To collect system metrics, deploy node_exporter on all hosts:

```bash
# Deploy node_exporter to all hosts
ansible-playbook monitoring/deploy-node-exporter.yml
```

**Metrics collected**:
- CPU usage (per core and total)
- Memory usage (used, available, cached)
- Disk I/O (reads, writes, throughput)
- Network traffic (bytes, packets, errors)
- Filesystem usage (size, available, used)
- System load average
- Process counts

### Docker Metrics (cAdvisor)

For container metrics, deploy cAdvisor:

```bash
# Deploy cAdvisor to Docker hosts
ansible-playbook monitoring/deploy-cadvisor.yml
```

**Metrics collected**:
- Container CPU usage
- Container memory usage
- Container network I/O
- Container filesystem usage

---

## Access Credentials

### Default Credentials

| Service | Username | Default Password | Notes |
|---------|----------|------------------|-------|
| Uptime Kuma | (created on first login) | N/A | Admin account created on first access |
| Prometheus | N/A | N/A | No authentication by default |
| Grafana | `admin` | `admin` | Change immediately after first login |

> **Security Note**: Change all default passwords after initial setup. Store credentials in [[11 - Credentials]].

---

## Backup Configuration

### Data Locations

| Service | Data Path | Backup Priority |
|---------|-----------|-----------------|
| Uptime Kuma | `/opt/monitoring/uptime-kuma/data` | High |
| Prometheus | `/opt/monitoring/prometheus/data` | Medium |
| Grafana | `/opt/monitoring/grafana/data` | High |

### Backup Script

```bash
#!/bin/bash
# Backup monitoring data
BACKUP_DIR="/mnt/appdata/backups/monitoring"
DATE=$(date +%Y%m%d)

# Stop services
cd /opt/monitoring && docker compose stop

# Create backup
tar -czf "$BACKUP_DIR/monitoring-$DATE.tar.gz" /opt/monitoring

# Start services
cd /opt/monitoring && docker compose start
```

---

## Troubleshooting

### Services Not Accessible

```bash
# Check if containers are running
ssh docker-vm-core-utilities01 "docker ps | grep -E 'uptime|prometheus|grafana'"

# Check Traefik logs for routing issues
ssh traefik-vm01 "cd /opt/traefik && docker compose logs -f | grep -E 'uptime|prometheus|grafana'"

# Verify DNS resolution
nslookup uptime.hrmsmrflrii.xyz
nslookup prometheus.hrmsmrflrii.xyz
nslookup grafana.hrmsmrflrii.xyz
```

### Prometheus Not Scraping Targets

```bash
# Check Prometheus targets page
# Navigate to: https://prometheus.hrmsmrflrii.xyz/targets

# Verify network connectivity
ssh docker-vm-core-utilities01 "docker exec prometheus wget -O- http://192.168.20.20:9100/metrics"

# Check Prometheus config
ssh docker-vm-core-utilities01 "cat /opt/monitoring/prometheus/prometheus.yml"
```

### Grafana Cannot Connect to Prometheus

```bash
# Test connection from Grafana container
ssh docker-vm-core-utilities01 "docker exec grafana wget -O- http://192.168.40.13:9090/api/v1/query?query=up"

# Check Grafana data source configuration
# Navigate to: Configuration → Data Sources → Prometheus
```

---

## Future Enhancements

### Planned Additions

- [ ] Node Exporter deployment on all hosts
- [ ] cAdvisor for container metrics
- [ ] AlertManager for advanced alerting
- [ ] Loki for log aggregation
- [ ] Thanos for long-term Prometheus storage
- [ ] Custom Grafana dashboards for homelab
- [ ] Integration with n8n for automation workflows

### Completed

- [x] **OpenTelemetry Tracing** - See [[18 - Observability Stack]]
- [x] **Jaeger Integration** - Distributed tracing visualization
- [x] **Traefik OTEL Integration** - Full request tracing

---

## Related Documentation

- [[18 - Observability Stack]] - Distributed tracing with Jaeger and OTEL
- [[07 - Deployed Services]] - All deployed services
- [[09 - Traefik Reverse Proxy]] - Reverse proxy configuration
- [[06 - Ansible Automation]] - Deployment playbooks
- [[11 - Credentials]] - Service credentials
- [[12 - Troubleshooting]] - Common issues
- [[15 - New Service Onboarding Guide]] - Adding new services

---

*Last updated: December 21, 2025*
