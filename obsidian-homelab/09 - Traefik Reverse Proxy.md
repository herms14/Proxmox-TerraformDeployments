# Traefik Reverse Proxy

> **Internal Documentation** - Contains SSL configuration and Cloudflare API details.

Related: [[00 - Homelab Index]] | [[07 - Deployed Services]] | [[11 - Credentials]] | [[18 - Observability Stack]]

---

## Overview

**Host**: traefik-vm01 (192.168.40.20)
**Version**: Traefik v3.2
**Status**: Deployed December 19, 2025

| Port | Purpose |
|------|---------|
| 80 | HTTP (redirects to HTTPS) |
| 443 | HTTPS traffic |
| 8080 | Dashboard |
| 8082 | Prometheus metrics |

---

## SSL Configuration

### Let's Encrypt via Cloudflare DNS-01

| Setting | Value |
|---------|-------|
| Domain | `hrmsmrflrii.xyz` |
| Certificate Type | Wildcard (*.hrmsmrflrii.xyz) |
| Challenge | DNS-01 via Cloudflare API |
| Email | herms14@gmail.com |
| Storage | `/opt/traefik/certs/acme.json` |

### Cloudflare Configuration

- **Account**: herms14@gmail.com
- **API Token**: *(stored in Traefik config)*
- **Zone**: hrmsmrflrii.xyz

---

## Storage Layout

```
/opt/traefik/
├── docker-compose.yml
├── config/
│   ├── traefik.yml          # Static config
│   └── dynamic/
│       └── services.yml      # Dynamic service routes
├── certs/
│   └── acme.json            # Let's Encrypt certificates
└── logs/
    └── traefik.log
```

---

## OpenTelemetry Tracing

**Status**: Enabled December 21, 2025

Traefik sends distributed traces to the OTEL Collector for visualization in Jaeger.

### Configuration

```yaml
# In traefik.yml static config
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

### Trace Flow

```
User Request → Traefik → OTEL Collector → Jaeger
                 ↓
            Prometheus (metrics)
```

### Viewing Traces

1. Navigate to https://jaeger.hrmsmrflrii.xyz
2. Select "traefik" from service dropdown
3. Click "Find Traces"
4. Click on a trace to see span details

### Metrics Endpoint

Prometheus scrapes Traefik metrics at: `http://192.168.40.20:8082/metrics`

> See [[18 - Observability Stack]] for complete observability configuration.

---

## Pre-configured Routes

| Hostname | Backend Service |
|----------|----------------|
| auth.hrmsmrflrii.xyz | Authentik (192.168.40.21:9000) |
| photos.hrmsmrflrii.xyz | Immich (192.168.40.22:2283) |
| gitlab.hrmsmrflrii.xyz | GitLab (192.168.40.23:80) |
| jellyfin.hrmsmrflrii.xyz | Jellyfin (192.168.40.11:8096) |
| radarr.hrmsmrflrii.xyz | Radarr (192.168.40.11:7878) |
| sonarr.hrmsmrflrii.xyz | Sonarr (192.168.40.11:8989) |
| lidarr.hrmsmrflrii.xyz | Lidarr (192.168.40.11:8686) |
| prowlarr.hrmsmrflrii.xyz | Prowlarr (192.168.40.11:9696) |
| bazarr.hrmsmrflrii.xyz | Bazarr (192.168.40.11:6767) |
| n8n.hrmsmrflrii.xyz | n8n (192.168.40.13:5678) |
| proxmox.hrmsmrflrii.xyz | Proxmox (192.168.20.21:8006) |
| uptime.hrmsmrflrii.xyz | Uptime Kuma (192.168.40.13:3001) |
| prometheus.hrmsmrflrii.xyz | Prometheus (192.168.40.13:9090) |
| grafana.hrmsmrflrii.xyz | Grafana (192.168.40.13:3030) |
| jaeger.hrmsmrflrii.xyz | Jaeger (192.168.40.13:16686) |
| demo.hrmsmrflrii.xyz | Demo App (192.168.40.12:8080) |

---

## Adding New Services

Edit `/opt/traefik/config/dynamic/services.yml`:

```yaml
http:
  routers:
    new-service:
      rule: "Host(`newservice.hrmsmrflrii.xyz`)"
      service: new-service
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

  services:
    new-service:
      loadBalancer:
        servers:
          - url: "http://192.168.40.XX:PORT"
```

Changes auto-reload (no restart needed).

---

## Management Commands

```bash
# SSH to Traefik host
ssh hermes-admin@192.168.40.20

# View logs
cd /opt/traefik && sudo docker compose logs -f

# Restart Traefik
cd /opt/traefik && sudo docker compose restart

# Update Traefik
cd /opt/traefik && sudo docker compose pull && sudo docker compose up -d
```

---

## Ansible Deployment

Playbook: `~/ansible/traefik/deploy-traefik.yml`

```bash
# From ansible-controller01
ansible-playbook traefik/deploy-traefik.yml
```

---

## Related Documentation

- [[18 - Observability Stack]] - Distributed tracing with Jaeger
- [[17 - Monitoring Stack]] - Prometheus and Grafana
- [[07 - Deployed Services]] - All service URLs
- [[01 - Network Architecture]] - DNS configuration
- [[06 - Ansible Automation]] - Deployment playbooks
- [[11 - Credentials]] - Cloudflare API token

