---
tags:
  - homelab
  - gitops
  - gitlab
  - tutorial
  - deployment
created: 2025-12-30
updated: 2025-12-30
status: active
---

# GitOps Deployment Tutorial

A step-by-step guide to deploying a new service using the GitOps pipeline.

---

## Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT FLOW                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. CREATE     → Write service YAML in services/ directory      │
│        ↓                                                         │
│  2. VALIDATE   → Run local validation (optional but recommended)│
│        ↓                                                         │
│  3. COMMIT     → git add, commit, push to main/master           │
│        ↓                                                         │
│  4. PIPELINE   → GitLab CI/CD automatically runs                │
│        ↓                                                         │
│  5. VERIFY     → Check service is accessible                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **Git Access** | Clone access to the homelab-services repository |
| **Text Editor** | VS Code, Vim, or any YAML-aware editor |
| **Docker Image** | Know the Docker image for your service |
| **Port Assignment** | Choose an unused port on target host |
| **Network Info** | Know which Docker host to deploy to |

### Target Hosts Reference

| Host Name | IP Address | Purpose | User |
|-----------|------------|---------|------|
| `docker-media` | 192.168.40.11 | Media services | hermes-admin |
| `docker-vm-core-utilities01` | 192.168.40.13 | Core utilities | hermes-admin |
| `docker-lxc-glance` | 192.168.40.12 | Glance dashboard | root |
| `docker-lxc-bots` | 192.168.40.14 | Discord bots | root |

---

## Part 1: Service YAML Structure

Every service YAML file has these sections:

```yaml
# Required sections
service:      # Service metadata (name, description, category)
deployment:   # Docker deployment configuration

# Optional sections
traefik:      # Reverse proxy configuration
dns:          # DNS record creation
authentik:    # SSO/authentication
glance:       # Dashboard integration
watchtower:   # Auto-update configuration
notifications: # Discord notifications
metadata:     # Additional information
```

---

## Part 2: Complete Example (MeTube)

```yaml
# services/downloads/metube.yml

service:
  name: "metube"
  display_name: "MeTube"
  description: "YouTube video downloader"
  category: "downloads"
  icon: "si:youtube"
  version: "latest"

deployment:
  target_host: "docker-media"
  port: 8082
  container_port: 8081
  image: "ghcr.io/alexta69/metube:latest"
  install_path: "/opt/metube"
  restart_policy: "unless-stopped"
  volumes:
    - host: "/opt/metube/downloads"
      container: "/downloads"
  environment:
    TZ: "America/New_York"
    DOWNLOAD_DIR: "/downloads"
  healthcheck:
    endpoint: "/"
    expected_status: [200]

traefik:
  enabled: true
  subdomain: "metube"
  tls:
    enabled: true
    cert_resolver: "letsencrypt"

dns:
  enabled: true
  hostname: "metube"
  ip: "192.168.40.20"

authentik:
  enabled: true
  method: "forward_auth"
  authorization_flow: "default-provider-authorization-implicit-consent"

glance:
  enabled: true
  page: "home"
  bookmark:
    enabled: true
    group: "Downloads"
    description: "YouTube downloader"
  monitor:
    enabled: true
    widget: "Media Services"

watchtower:
  enabled: true
  container_name: "metube"

metadata:
  maintainer: "hermes-admin"
  repository: "https://github.com/alexta69/metube"
```

---

## Part 3: Deploy via GitOps

### Step 1: Stage Your Changes

```bash
git status
git add services/downloads/metube.yml
git diff --staged
```

### Step 2: Commit

```bash
git commit -m "Add MeTube YouTube downloader service

- Deploy to docker-media:8082
- Enable Traefik HTTPS at metube.hrmsmrflrii.xyz
- Add Authentik SSO protection
- Add to Glance dashboard"
```

### Step 3: Push to Trigger Pipeline

```bash
git push origin master
```

### Step 4: Monitor Pipeline

1. Open GitLab: `https://gitlab.hrmsmrflrii.xyz/homelab/homelab-services`
2. Go to CI/CD → Pipelines
3. Watch each stage

---

## Part 4: Verify Deployment

### Check Container Status

```bash
ssh hermes-admin@192.168.40.11 "docker ps | grep metube"
```

### Test Direct Access

```bash
curl -I http://192.168.40.11:8082
# Expected: HTTP/1.1 200 OK
```

### Test via Traefik

```bash
curl -I https://metube.hrmsmrflrii.xyz
# Expected: HTTP/2 200 (or 401 if Authentik enabled)
```

### Verify DNS

```bash
nslookup metube.hrmsmrflrii.xyz
# Expected: 192.168.40.20
```

---

## Quick Reference Templates

### Minimal Service YAML

```yaml
service:
  name: "myservice"
  display_name: "My Service"
  description: "Description here"
  category: "productivity"

deployment:
  target_host: "docker-media"
  port: 8080
  image: "myimage:latest"
```

### Service Categories

| Category | Services | Directory |
|----------|----------|-----------|
| `media` | Jellyfin, Radarr | `services/media/` |
| `downloads` | Deluge, MeTube | `services/downloads/` |
| `productivity` | n8n, Paperless | `services/productivity/` |
| `monitoring` | Grafana | `services/monitoring/` |
| `infrastructure` | Traefik | `services/infrastructure/` |

---

## SSH Commands Cheat Sheet

```bash
# Check container status
ssh hermes-admin@<host> "docker ps | grep <name>"

# View container logs
ssh hermes-admin@<host> "docker logs <name> --tail 100"

# Restart container
ssh hermes-admin@<host> "cd /opt/<name> && docker compose restart"

# Check used ports
ssh hermes-admin@<host> "docker ps --format 'table {{.Names}}\t{{.Ports}}'"
```

---

## Related Documents

- [[32 - GitOps Architecture]] - Architecture overview
- [[33 - GitOps Pipeline Walkthrough]] - Pipeline details
- [[35 - GitOps Troubleshooting]] - Common issues and solutions

---

*Last updated: December 30, 2025*
