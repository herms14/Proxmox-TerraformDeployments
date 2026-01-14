# Observability Stack

> **Internal Documentation** - Contains observability configuration and endpoints.

Related: [[00 - Homelab Index]] | [[17 - Monitoring Stack]] | [[09 - Traefik Reverse Proxy]] | [[07 - Deployed Services]]

---

## Overview

**Status**: Deployed December 21, 2025

Full end-to-end observability stack with OpenTelemetry distributed tracing, enabling visibility into every request flowing through the homelab infrastructure.

| Component | Purpose | Host |
|-----------|---------|------|
| **OTEL Collector** | Central trace/metrics receiver | docker-vm-core-utilities01 |
| **Jaeger** | Distributed tracing visualization | docker-vm-core-utilities01 |
| **Traefik** | Trace source (instrumented) | traefik-vm01 |
| **Demo App** | OTEL testing application | docker-vm-core-utilities01 |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Observability Architecture                           │
│                                                                          │
│  ┌─────────────────┐                                                    │
│  │  User Request   │                                                    │
│  └────────┬────────┘                                                    │
│           │                                                              │
│           ▼                                                              │
│  ┌─────────────────┐     ┌─────────────────┐                           │
│  │    Traefik      │────►│   OTEL Traces   │                           │
│  │  192.168.40.20  │     │   (OTLP HTTP)   │                           │
│  │                 │     └────────┬────────┘                           │
│  │  • Routes       │              │                                     │
│  │  • SSL          │              ▼                                     │
│  │  • OTEL Traces  │     ┌─────────────────┐     ┌─────────────────┐   │
│  │  • Metrics      │     │ OTEL Collector  │────►│     Jaeger      │   │
│  └────────┬────────┘     │  192.168.40.13  │     │  192.168.40.13  │   │
│           │              │                 │     │                 │   │
│           │              │  • Receivers    │     │  • Trace Store  │   │
│           │              │  • Processors   │     │  • Query API    │   │
│           │              │  • Exporters    │     │  • Jaeger UI    │   │
│           │              └─────────────────┘     └────────┬────────┘   │
│           │                                               │             │
│           │         ┌────────────────────────────────────┘             │
│           │         │                                                   │
│           ▼         ▼                                                   │
│  ┌─────────────────────────────────────────────────────────┐           │
│  │                     Grafana                              │           │
│  │                  192.168.40.13:3030                      │           │
│  │                                                          │           │
│  │  ┌──────────────────┐    ┌──────────────────┐           │           │
│  │  │   Prometheus     │    │     Jaeger       │           │           │
│  │  │   Datasource     │    │   Datasource     │           │           │
│  │  └──────────────────┘    └──────────────────┘           │           │
│  └─────────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Service URLs

### HTTPS (via Traefik with Authentik ForwardAuth)

| Service | URL | Purpose |
|---------|-----|---------|
| Jaeger | https://jaeger.hrmsmrflrii.xyz | Distributed tracing UI |
| Demo App | https://demo.hrmsmrflrii.xyz | OTEL testing application |
| Prometheus | https://prometheus.hrmsmrflrii.xyz | Metrics collection |
| Grafana | https://grafana.hrmsmrflrii.xyz | Dashboards (traces + metrics) |

### Direct Access (Internal)

| Service | URL | Port |
|---------|-----|------|
| Jaeger UI | http://192.168.40.13:16686 | 16686 |
| OTEL Collector (gRPC) | http://192.168.40.13:4317 | 4317 |
| OTEL Collector (HTTP) | http://192.168.40.13:4318 | 4318 |
| OTEL Collector Metrics | http://192.168.40.13:8888 | 8888 |
| OTEL Pipeline Metrics | http://192.168.40.13:8889 | 8889 |
| Jaeger Metrics | http://192.168.40.13:14269 | 14269 |
| Demo App | http://192.168.40.12:8080 | 8080 |
| Demo App Metrics | http://192.168.40.13:5000 | 5000 |

---

## OpenTelemetry Collector

**Purpose**: Central hub receiving traces from Traefik and forwarding to Jaeger.

### Configuration

| Setting | Value |
|---------|-------|
| Host | docker-vm-core-utilities01 |
| IP | 192.168.40.13 |
| gRPC Port | 4317 |
| HTTP Port | 4318 |
| Config | `/opt/observability/otel-collector-config.yaml` |

### Receivers

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"
      http:
        endpoint: "0.0.0.0:4318"
```

### Processors

```yaml
processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
```

### Exporters

```yaml
exporters:
  otlp/jaeger:
    endpoint: "jaeger:4317"
    tls:
      insecure: true
```

---

## Jaeger

**Purpose**: Distributed tracing visualization and storage.

### Configuration

| Setting | Value |
|---------|-------|
| Host | docker-vm-core-utilities01 |
| IP | 192.168.40.13 |
| UI Port | 16686 |
| OTLP gRPC | 4317 |
| OTLP HTTP | 4318 |
| Metrics | 14269 |
| Storage | In-memory (default) |

### Using Jaeger

1. Navigate to https://jaeger.hrmsmrflrii.xyz
2. Authenticate via Authentik (Google SSO)
3. Select service from dropdown (e.g., `traefik`)
4. Click "Find Traces"
5. Click on a trace to see span details

### Trace Anatomy

```
Trace ID: abc123...
├── traefik (root span)
│   ├── Duration: 150ms
│   ├── HTTP Method: GET
│   ├── HTTP URL: /api/resource
│   └── Status Code: 200
```

---

## Traefik OTEL Configuration

Traefik is configured to send traces to the OTEL Collector.

### Static Configuration

```yaml
tracing:
  otlp:
    http:
      endpoint: "http://192.168.40.13:4318/v1/traces"
  serviceName: "traefik"
  sampleRate: 1.0  # 100% sampling

metrics:
  prometheus:
    buckets: [0.1, 0.3, 1.2, 5.0]
    addEntryPointsLabels: true
    addRoutersLabels: true
    addServicesLabels: true
    entryPoint: metrics

entryPoints:
  metrics:
    address: ":8082"
```

### Traefik Metrics Endpoint

| Endpoint | URL | Purpose |
|----------|-----|---------|
| Prometheus Metrics | http://192.168.40.20:8082/metrics | Scraped by Prometheus |

---

## Demo Application

**Purpose**: OTEL-instrumented Flask app for testing the tracing pipeline.

### Features

- Automatic trace propagation
- Custom spans for business logic
- Simulated database queries
- Simulated external API calls
- Health check endpoint

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Homepage with trace example |
| `/health` | GET | Health check |

### Sample Trace

When accessing the demo app, you'll see traces like:

```
demo-app (root span)
├── process_data (custom span) - 50ms
├── database_query (simulated) - 100ms
└── external_api_call (simulated) - 200ms
```

---

## Prometheus Scrape Targets

The observability stack adds these scrape targets to Prometheus:

```yaml
scrape_configs:
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

---

## Grafana Integration

### Jaeger Datasource

Add Jaeger as a datasource in Grafana for unified observability:

```
Name: Jaeger
Type: Jaeger
URL: http://192.168.40.13:16686
Access: Server (default)
```

### Trace to Metrics Correlation

With both Prometheus and Jaeger datasources:
- View metrics in Grafana dashboards
- Click to drill down into traces
- Correlate latency spikes with specific requests

---

## Docker Compose Configuration

### Directory Structure

```
/opt/observability/
├── docker-compose.yml
├── otel-collector-config.yaml
└── demo-app/
    └── app.py
```

### Docker Compose File

```yaml
version: '3.8'

services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    container_name: otel-collector
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml:ro
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "8888:8888"   # Prometheus metrics
      - "8889:8889"   # Pipeline metrics
    restart: unless-stopped

  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    ports:
      - "16686:16686"  # Jaeger UI
      - "14269:14269"  # Metrics
    restart: unless-stopped

  demo-app:
    build: ./demo-app
    container_name: demo-app
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
      - OTEL_SERVICE_NAME=demo-app
    ports:
      - "8080:8080"    # App (Flask via gunicorn)
      - "5000:5000"    # Metrics
    restart: unless-stopped
    depends_on:
      - otel-collector
```

---

## Authentik ForwardAuth

All observability endpoints are protected by Authentik ForwardAuth:

### Protected Services

| Service | Authentik Application |
|---------|----------------------|
| Jaeger | jaeger-app |
| Demo App | demo-app |
| Prometheus | prometheus-app |
| Grafana | grafana-app |

### Adding ForwardAuth

In Traefik dynamic configuration:

```yaml
http:
  routers:
    jaeger:
      rule: "Host(`jaeger.hrmsmrflrii.xyz`)"
      service: jaeger
      entryPoints:
        - websecure
      middlewares:
        - authentik-auth  # ForwardAuth middleware
      tls:
        certResolver: letsencrypt
```

---

## Ansible Deployment

### Deploy Observability Stack

```bash
# SSH to Ansible controller
ssh hermes-admin@192.168.20.30
cd ~/ansible

# Deploy observability stack
ansible-playbook ~/ansible-playbooks/monitoring/deploy-observability-stack.yml

# Update Traefik with OTEL tracing
ansible-playbook traefik/deploy-traefik-ssl.yml

# Add DNS records
ansible-playbook opnsense/add-observability-dns.yml
```

### Deployment Order

1. Monitoring stack (Prometheus, Grafana, Uptime Kuma)
2. Observability stack (OTEL Collector, Jaeger, Demo App)
3. Traefik update (OTEL configuration)
4. DNS records (OPNsense)

---

## Management Commands

### View Logs

```bash
# All observability services
ssh docker-vm-core-utilities01 "cd /opt/observability && sudo docker compose logs -f"

# OTEL Collector
ssh docker-vm-core-utilities01 "docker logs otel-collector -f"

# Jaeger
ssh docker-vm-core-utilities01 "docker logs jaeger -f"

# Demo App
ssh docker-vm-core-utilities01 "docker logs demo-app -f"
```

### Restart Services

```bash
# All services
ssh docker-vm-core-utilities01 "cd /opt/observability && sudo docker compose restart"

# Specific service
ssh docker-vm-core-utilities01 "docker restart otel-collector"
```

### Check Status

```bash
# Container status
ssh docker-vm-core-utilities01 "cd /opt/observability && sudo docker compose ps"

# Traefik OTEL connectivity
ssh docker-vm-core-utilities01 "curl -I http://192.168.40.13:4318/v1/traces"
```

---

## Troubleshooting

### No Traces Appearing in Jaeger

1. **Check Traefik logs:**
   ```bash
   ssh traefik-vm01 "docker logs traefik 2>&1 | grep -i otel"
   ```

2. **Check OTEL Collector:**
   ```bash
   ssh docker-vm-core-utilities01 "docker logs otel-collector"
   ```

3. **Verify connectivity:**
   ```bash
   curl -v http://192.168.40.13:4318/v1/traces
   ```

4. **Check Jaeger receiving traces:**
   Navigate to https://jaeger.hrmsmrflrii.xyz and check "traefik" service

### Jaeger UI Not Loading

1. **Check container status:**
   ```bash
   ssh docker-vm-core-utilities01 "docker ps | grep jaeger"
   ```

2. **Check Traefik route:**
   ```bash
   curl -I https://jaeger.hrmsmrflrii.xyz
   ```

3. **Test direct access:**
   ```bash
   curl http://192.168.40.13:16686
   ```

### OTEL Collector Not Receiving Traces

1. **Check receiver endpoints:**
   ```bash
   curl http://192.168.40.13:4318/v1/traces -d '{}' -H "Content-Type: application/json"
   ```

2. **Check collector metrics:**
   ```bash
   curl http://192.168.40.13:8888/metrics | grep otelcol_receiver
   ```

---

## Metrics Available

### Traefik Metrics

| Metric | Description |
|--------|-------------|
| `traefik_entrypoint_requests_total` | Total requests per entrypoint |
| `traefik_router_requests_total` | Requests per router |
| `traefik_service_requests_total` | Requests per service |
| `traefik_entrypoint_request_duration_seconds` | Request latency |

### OTEL Collector Metrics

| Metric | Description |
|--------|-------------|
| `otelcol_receiver_accepted_spans` | Spans received |
| `otelcol_exporter_sent_spans` | Spans exported |
| `otelcol_processor_batch_batch_send_size` | Batch sizes |

### Jaeger Metrics

| Metric | Description |
|--------|-------------|
| `jaeger_collector_spans_received_total` | Spans received |
| `jaeger_query_requests_total` | Query requests |

---

## DNS Configuration

### OPNsense Host Overrides

| Hostname | Domain | IP Address | Description |
|----------|--------|------------|-------------|
| jaeger | hrmsmrflrii.xyz | 192.168.40.20 | Jaeger UI (via Traefik) |
| demo | hrmsmrflrii.xyz | 192.168.40.20 | Demo App (via Traefik) |

---

## Security Notes

- All external endpoints protected by Authentik ForwardAuth
- Users authenticate via Google SSO or username/password
- Internal OTEL ports (4317, 4318) not exposed externally
- Traefik metrics port (8082) internal only

---

## Proxmox Temperature Monitoring

Hardware temperature monitoring for all Proxmox nodes via node_exporter (added January 11, 2026).

### Node Exporter

Each Proxmox node runs node_exporter v1.7.0 for hardware metrics:

| Node | Endpoint | Metrics |
|------|----------|---------|
| node01 | 192.168.20.20:9100 | CPU temp, NVMe temp, disk, memory |
| node02 | 192.168.20.21:9100 | CPU temp, NVMe temp, disk, memory |
| node03 | 192.168.20.22:9100 | CPU temp, NVMe temp, disk, memory |

**Collectors enabled**: hwmon, thermal_zone, cpu, meminfo, filesystem, loadavg, netdev

### Prometheus Scrape Job

```yaml
- job_name: 'proxmox-nodes'
  static_configs:
    - targets: [192.168.20.20:9100, 192.168.20.21:9100, 192.168.20.22:9100]
```

### Cluster Health Dashboard

The Proxmox Cluster Health Grafana dashboard (`proxmox-cluster-health`) displays:

| Panel | Description |
|-------|-------------|
| Cluster Status | Quorum, nodes online, VM/LXC counts |
| CPU Temperature | Per-node gauges with color thresholds |
| Temperature History | 24-hour chart for all nodes |
| Drive Temperatures | NVMe and GPU temps |
| Resource Usage | Top VMs by CPU/Memory |
| Storage | Pool usage bar gauges |

**Temperature Thresholds**: Green (<60°C), Yellow (60-80°C), Red (>80°C)

**Access**: https://grafana.hrmsmrflrii.xyz/d/proxmox-cluster-health or via Glance Compute tab

---

## Network Utilization Monitoring

Network bandwidth monitoring dashboard for the Proxmox cluster and Synology NAS (added January 13, 2026).

### Purpose

Monitor network utilization to determine if upgrading to a 2.5GbE switch would be beneficial.

### Data Sources

| Source | Metrics | Description |
|--------|---------|-------------|
| **node_exporter** | `node_network_*_bytes_total` | Per-node RX/TX bandwidth |
| **SNMP Exporter** | `ifHCInOctets`, `ifHCOutOctets` | NAS eth0/eth1 traffic (64-bit) |

### SNMP Configuration

The SNMP exporter was updated with IF-MIB OIDs for NAS interface monitoring:
- `ifHCInOctets` (OID: 1.3.6.1.2.1.31.1.1.1.6) - Inbound bytes
- `ifHCOutOctets` (OID: 1.3.6.1.2.1.31.1.1.1.10) - Outbound bytes
- `ifHighSpeed` (OID: 1.3.6.1.2.1.31.1.1.1.15) - Interface speed

**NAS Interface Mapping:**
| Interface | ifIndex | Speed |
|-----------|---------|-------|
| eth0 | 3 | 1Gbps |
| eth1 | 4 | 1Gbps |

### Dashboard Panels

The Network Utilization Grafana dashboard (`network-utilization`) includes:

| Panel | Type | Description |
|-------|------|-------------|
| Total Cluster Bandwidth | stat | Combined RX+TX for all Proxmox nodes |
| Cluster Utilization | gauge | % of 1Gbps capacity |
| Peak (24h) | stat | Maximum bandwidth in 24 hours |
| Avg (24h) | stat | Average bandwidth in 24 hours |
| Synology NAS | stat | eth0+eth1 combined bandwidth |
| NAS Utilization | gauge | % of 2Gbps bonded capacity |
| Per-Node Stats | stat | node01, node02, node03 individual |
| Cluster Bandwidth Timeline | timeseries | Per-node RX/TX with 1Gbps reference |
| NAS Bandwidth Timeline | timeseries | eth0/eth1 RX/TX |
| Combined Bandwidth | timeseries | Cluster + NAS totals |

### Utilization Thresholds

| Range | Color | Recommendation |
|-------|-------|----------------|
| < 50% | Green | 1GbE sufficient |
| 50-80% | Yellow | Monitor closely |
| > 80% | Red | Consider 2.5GbE upgrade |

### Access

| Method | URL |
|--------|-----|
| Grafana Direct | https://grafana.hrmsmrflrii.xyz/d/network-utilization |
| Glance (embedded) | Network tab (iframe height: 1100px) |

### Files

- Dashboard JSON: `dashboards/network-utilization.json`
- Ansible Playbook: `ansible/playbooks/monitoring/deploy-network-utilization-dashboard.yml`

---

## Related Documentation

- [[17 - Monitoring Stack]] - Prometheus, Grafana, Uptime Kuma
- [[09 - Traefik Reverse Proxy]] - Reverse proxy configuration
- [[07 - Deployed Services]] - All deployed services
- [[14 - Authentik Google SSO Setup]] - SSO configuration
- [[06 - Ansible Automation]] - Deployment playbooks
- [[02 - Proxmox Cluster]] - Node_exporter installation details

---

*Last updated: January 13, 2026*
