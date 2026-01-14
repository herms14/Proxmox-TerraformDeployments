# Deployed Services

> **Internal Documentation** - Contains service URLs and access details.

Related: [[00 - Homelab Index]] | [[08 - Arr Media Stack]] | [[09 - Traefik Reverse Proxy]]

---

## Service Overview

All services deployed via Docker Compose, managed by Ansible from ansible-controller01.

| Category | Host | Services |
|----------|------|----------|
| Reverse Proxy | traefik-lxc (LXC 203, 192.168.40.20) | Traefik (with OTEL tracing) |
| Identity | authentik-lxc (LXC 204, 192.168.40.21) | Authentik |
| Photos | immich-vm01 | Immich |
| DevOps | gitlab-vm01 | GitLab CE |
| Media | docker-lxc-media (LXC 205, 192.168.40.11) | Arr Stack (14 services) |
| Smart Home | homeassistant-lxc (LXC 206, 192.168.40.25) | Home Assistant |
| Dashboard | docker-lxc-glance (LXC 200, 192.168.40.12) | Glance Dashboard, Media Stats API, Reddit Manager |
| Utilities | docker-vm-core-utilities01 | n8n, Paperless, Life Progress API, Speedtest Tracker |
| Productivity | docker-vm-core-utilities01 | BentoPDF, Reactive Resume, Karakeep |
| Network Tools | docker-vm-core-utilities01 | Edgeshark (container network inspector) |
| Media Tools | docker-vm-core-utilities01 | Wizarr, Tracearr |
| Monitoring | docker-vm-core-utilities01 | Uptime Kuma, Prometheus, Grafana |
| Observability | docker-vm-core-utilities01 | OTEL Collector, Jaeger, Demo App |
| Update Management | docker-vm-core-utilities01 + all hosts | Watchtower, Update Manager (Discord) |
| Discord Bots | docker-vm-core-utilities01 | Sentinel Bot (consolidated) |
| Container Metrics | Both Docker hosts | Docker Stats Exporter |

> **Note**: Traefik, Authentik, and Media services migrated from VMs to LXC containers on January 7, 2026. See [[30 - LXC Migration Tutorial]] for details.

---

## Service URLs (HTTPS)

### Infrastructure

| Service | URL | Backend |
|---------|-----|---------|
| Proxmox Cluster | https://proxmox.hrmsmrflrii.xyz | 192.168.20.21:8006 |
| Proxmox Node01 | https://node01.hrmsmrflrii.xyz | 192.168.20.20:8006 |
| Proxmox Node02 | https://node02.hrmsmrflrii.xyz | 192.168.20.21:8006 |
| Proxmox Node03 | https://node03.hrmsmrflrii.xyz | 192.168.20.22:8006 |
| Traefik Dashboard | https://traefik.hrmsmrflrii.xyz | localhost:8080 |
| Pi-hole | https://pihole.hrmsmrflrii.xyz | 192.168.90.53:80 |
| Omada Controller | https://omada.hrmsmrflrii.xyz | 192.168.0.103:443 |

### Core Services

| Service | URL | Backend |
|---------|-----|---------|
| Authentik (SSO) | https://auth.hrmsmrflrii.xyz | 192.168.40.21:9000 |
| Immich (Photos) | https://photos.hrmsmrflrii.xyz | 192.168.40.22:2283 |
| GitLab | https://gitlab.hrmsmrflrii.xyz | 192.168.40.23:80 |
| Home Assistant | https://ha.hrmsmrflrii.xyz | 192.168.40.25:8123 |

### Media Services

| Service | URL | Backend |
|---------|-----|---------|
| Jellyfin | https://jellyfin.hrmsmrflrii.xyz | 192.168.40.11:8096 |
| Radarr | https://radarr.hrmsmrflrii.xyz | 192.168.40.11:7878 |
| Sonarr | https://sonarr.hrmsmrflrii.xyz | 192.168.40.11:8989 |
| Lidarr | https://lidarr.hrmsmrflrii.xyz | 192.168.40.11:8686 |
| Prowlarr | https://prowlarr.hrmsmrflrii.xyz | 192.168.40.11:9696 |
| Bazarr | https://bazarr.hrmsmrflrii.xyz | 192.168.40.11:6767 |
| Overseerr | https://overseerr.hrmsmrflrii.xyz | 192.168.40.11:5055 |
| Jellyseerr | https://jellyseerr.hrmsmrflrii.xyz | 192.168.40.11:5056 |
| Tdarr | https://tdarr.hrmsmrflrii.xyz | 192.168.40.11:8265 |
| Autobrr | https://autobrr.hrmsmrflrii.xyz | 192.168.40.11:7474 |
| Deluge | https://deluge.hrmsmrflrii.xyz | 192.168.40.11:8112 |
| SABnzbd | https://sabnzbd.hrmsmrflrii.xyz | 192.168.40.11:8081 |
| MeTube | https://metube.hrmsmrflrii.xyz | 192.168.40.11:8082 |

### Utility Services

| Service          | URL                               | Backend            |
| ---------------- | --------------------------------- | ------------------ |
| Paperless-ngx    | https://paperless.hrmsmrflrii.xyz | 192.168.40.13:8000 |
| Glance Dashboard | https://glance.hrmsmrflrii.xyz    | 192.168.40.12:8080 |
| n8n Automation   | https://n8n.hrmsmrflrii.xyz       | 192.168.40.13:5678 |
| Speedtest Tracker | https://speedtest.hrmsmrflrii.xyz | 192.168.40.13:3000 |

### Productivity & Tools

| Service | URL | Backend |
|---------|-----|---------|
| BentoPDF | https://bentopdf.hrmsmrflrii.xyz | 192.168.40.13:5055 |
| Reactive Resume | https://resume.hrmsmrflrii.xyz | 192.168.40.13:5057 |
| Edgeshark | https://edgeshark.hrmsmrflrii.xyz | 192.168.40.13:5056 |
| Karakeep | https://karakeep.hrmsmrflrii.xyz | 192.168.40.13:3005 |

### Media Tools

| Service | URL | Backend |
|---------|-----|---------|
| Wizarr | https://wizarr.hrmsmrflrii.xyz | 192.168.40.13:5690 |
| Tracearr | https://tracearr.hrmsmrflrii.xyz | 192.168.40.13:3002 |

### Monitoring Services

| Service | URL | Backend |
|---------|-----|---------|
| Uptime Kuma | https://uptime.hrmsmrflrii.xyz | 192.168.40.13:3001 |
| Prometheus | https://prometheus.hrmsmrflrii.xyz | 192.168.40.13:9090 |
| Grafana | https://grafana.hrmsmrflrii.xyz | 192.168.40.13:3030 |

### Observability Services

| Service | URL | Backend |
|---------|-----|---------|
| Jaeger | https://jaeger.hrmsmrflrii.xyz | 192.168.40.13:16686 |
| OTEL Collector | Internal (gRPC/HTTP) | 192.168.40.13:4317/4318 |
| Demo App | https://demo.hrmsmrflrii.xyz | 192.168.40.13:8080 |

---

## Traefik Reverse Proxy

**Host**: traefik-vm01 (192.168.40.20)
**Status**: Deployed December 19, 2025

See [[09 - Traefik Reverse Proxy]] for detailed configuration.

---

## Authentik Identity Provider

**Host**: authentik-vm01 (192.168.40.21)
**Status**: Deployed December 18, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 9000 | http://192.168.40.21:9000 | Web interface & API |
| 9443 | https://192.168.40.21:9443 | Secure web interface |

### Initial Setup

1. Navigate to http://192.168.40.21:9000/if/flow/initial-setup/
2. Create admin account (default username: `akadmin`)

---

## Immich Photo Management

**Host**: immich-vm01 (192.168.40.22)
**Status**: Deployed December 19, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 2283 | http://192.168.40.22:2283 | Web interface & API |

### Mobile App Setup

- Server URL: `http://192.168.40.22:2283/api`

---

## GitLab CE DevOps Platform

**Host**: gitlab-vm01 (192.168.40.23)
**Status**: Deployed December 19, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 80 | http://192.168.40.23 | Web UI |
| 443 | https://192.168.40.23 | Secure web |
| 2222 | ssh://git@192.168.40.23:2222 | Git SSH |

### Initial Setup

Get initial root password:
```bash
ssh hermes-admin@192.168.40.23 "sudo docker exec gitlab grep 'Password:' /etc/gitlab/initial_root_password"
```

> Password file deleted after 24 hours!

---

## n8n Workflow Automation

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 19, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 5678 | http://192.168.40.13:5678 | Workflow editor |

---

## Speedtest Tracker

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 22, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 3000 | http://192.168.40.13:3000 | Web interface |

### Features

- Scheduled speed tests (Ookla Speedtest CLI)
- Historical results with graphs
- Download, upload, and ping tracking
- Multi-server support
- Dark theme interface
- SQLite database for lightweight storage

### Schedule

Tests run automatically every 6 hours (configurable via `SPEEDTEST_SCHEDULE` cron expression).

### Initial Setup

1. Navigate to https://speedtest.hrmsmrflrii.xyz
2. Default login: `admin@example.com` / `password`
3. Change credentials immediately in Settings

### Management

```bash
# View logs
ssh hermes-admin@192.168.40.13 "docker logs speedtest-tracker"

# Trigger manual test
ssh hermes-admin@192.168.40.13 "docker exec speedtest-tracker php artisan app:ookla-speedtest"
```

**GitHub**: https://github.com/alexjustesen/speedtest-tracker

---

## Glance Dashboard

**Host**: lxc-glance (192.168.40.12) - LXC Container 200
**Status**: Migrated to LXC December 30, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 8080 | http://192.168.40.12:8080 | Dashboard |

> **Note**: Glance runs on an LXC container with Docker. The docker-compose.yml requires `security_opt: apparmor=unconfined` due to AppArmor restrictions in LXC environments.

### Features

- Service health monitoring (all Proxmox nodes, K8s cluster)
- Stock market tracking (BTC, MSFT, AAPL, SPY)
- RSS feeds (r/homelab, r/selfhosted)
- Network device status
- Media stack monitoring
- **Life Progress Widget** - Year/Month/Day/Life progress bars with daily quotes

### Configuration

Config: `/opt/glance/config/glance.yml`
Assets: `/opt/glance/assets/`

> **Note**: Glance v0.7.0+ requires config directory mount (`./config:/app/config`), not single file mount.

---

## Life Progress API

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 22, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 5051 | http://192.168.40.13:5051/progress | Progress API |

### Features

- Calculates year/month/day/life progress percentages
- Serves daily motivational quotes (30 quotes, rotates by day)
- Used by Glance dashboard widget

### Configuration

Config: `/opt/life-progress/app.py`
- `BIRTH_DATE`: February 14, 1989
- `TARGET_AGE`: 75 years

**GitHub**: https://github.com/herms14/life-progress-api

See [[21 - Application Configurations]] for detailed setup and customization.

---

## Reddit Manager

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 22, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 5053 | http://192.168.40.13:5053 | Management UI & API |

### Purpose

Flask API that provides dynamic subreddit management for Glance dashboard. Allows adding/removing subreddits via web UI and fetches Reddit posts with thumbnails.

### Features

- Dynamic subreddit management (add/remove via UI)
- Thumbnail support for posts with images
- Grouped view by subreddit with headers
- Sort options: Hot, New, Top
- Parallel fetching for fast response (~2 seconds)
- 5-minute caching to reduce Reddit API calls

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Management UI |
| GET | `/api/subreddits` | List subreddits |
| POST | `/api/subreddits` | Add subreddit |
| DELETE | `/api/subreddits/<name>` | Remove subreddit |
| GET | `/api/settings` | Get sort/view settings |
| POST | `/api/settings` | Update settings |
| GET | `/api/feed` | Get feed (grouped or combined) |

### Default Subreddits

homelab, selfhosted, linux, devops, kubernetes, docker

### Troubleshooting

**Timeout errors in Glance**: Reddit Manager uses parallel fetching. Response should be ~2 seconds. Test with:
```bash
time curl http://192.168.40.13:5053/api/feed
```

**Ansible**: `~/ansible/reddit-manager/deploy-reddit-manager.yml`

---

## Monitoring Stack

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 21, 2025

Complete monitoring solution with uptime monitoring, metrics collection, and visualization.

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| Uptime Kuma | 3001 | http://192.168.40.13:3001 | Uptime monitoring & status pages |
| Prometheus | 9090 | http://192.168.40.13:9090 | Metrics collection & time-series DB |
| Grafana | 3030 | http://192.168.40.13:3030 | Metrics visualization & dashboards |

### Initial Setup

**Uptime Kuma**:
1. Navigate to https://uptime.hrmsmrflrii.xyz
2. Create admin account on first access

**Grafana**:
1. Navigate to https://grafana.hrmsmrflrii.xyz
2. Login: `admin` / `admin`
3. Change password immediately
4. Add Prometheus data source: `http://192.168.40.13:9090`

See [[17 - Monitoring Stack]] for detailed configuration.

---

## Observability Stack

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 21, 2025

Full OpenTelemetry distributed tracing with Jaeger visualization.

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| OTEL Collector | 4317/4318 | Internal | Trace receiver/processor |
| Jaeger | 16686 | http://192.168.40.13:16686 | Distributed tracing UI |
| Demo App | 8080 | http://192.168.40.13:8080 | OTEL testing application |

### Trace Flow

```
Traefik → OTEL Collector → Jaeger → Grafana
```

See [[18 - Observability Stack]] for detailed configuration.

---

## Argus SysAdmin Discord Bot

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 22, 2025

Discord bot for homelab infrastructure management via slash commands.

### Commands

| Command | Description |
|---------|-------------|
| `/status` | Get Proxmox cluster status |
| `/shutdown <node>` | Shutdown Proxmox node |
| `/reboot <target>` | Reboot VM or node |
| `/start <vm>` | Start a VM |
| `/stop <vm>` | Stop a VM |
| `/vms` | List all VMs with status |
| `/restart <container>` | Restart Docker container |
| `/logs <container>` | View container logs |
| `/containers <host>` | List containers on host |
| `/deploy <playbook>` | Run Ansible playbook |
| `/health` | System health check |
| `/disk` | Show disk usage |
| `/top` | Top resource consumers |
| `/request <type> <title>` | Request movie/show |
| `/media` | Media library stats |
| `/help` | Show all commands |

### Discord Channel

- **Channel**: `#argus-assistant`
- All commands and responses restricted to this channel

### Architecture

Uses SSH for all Proxmox operations (no API token required). Connects to nodes as `root` and VMs as `hermes-admin`.

---

## Download Monitor

**Host**: docker-vm-media01 (192.168.40.11)
**Status**: Deployed December 22, 2025

| Port | Purpose |
|------|---------|
| 5052 | Flask webhook receiver |

### Features

- Real-time download completion notifications
- Poster images embedded in Discord messages
- Supports Radarr (movies) and Sonarr (TV shows)

### Discord Channel

- **Channel**: `#media-downloads`

### Radarr/Sonarr Configuration

Add webhook:
- URL: `http://download-monitor:5052/webhook/radarr` or `/webhook/sonarr`
- Trigger: On Download / On Upgrade

---

## MeTube

**Host**: docker-vm-media01 (192.168.40.11)
**Status**: Deployed January 2, 2026

| Port | Purpose |
|------|---------|
| 8082 | Web UI |

### Features

- YouTube video/playlist downloader
- Web-based interface - paste URL and download
- Automatic playlist folder organization
- English subtitles auto-download
- MP4 output format (merged)

### Configuration

- Config: `/opt/metube/docker-compose.yml`
- Download Path: `/mnt/media/YouTube Videos` (NAS)
- URL: https://metube.hrmsmrflrii.xyz

### Usage

1. Open https://metube.hrmsmrflrii.xyz
2. Paste YouTube video or playlist URL
3. Click Add
4. Videos download to NAS automatically

---

## YouTube Stats API

**Host**: docker-vm-media01 (192.168.40.11)
**Status**: Deployed January 2, 2026

| Port | Purpose |
|------|---------|
| 5060 | REST API |

### Features

- Provides YouTube download statistics for Glance dashboard
- Scans MeTube download folder
- Groups videos by playlist folders

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `/api/stats` | Total videos, size, download status |
| `/api/recent` | Last 10 downloaded videos |
| `/api/queue` | Current download queue |
| `/api/playlists` | Videos grouped by playlist |
| `/health` | Health check |

### Glance Integration

The Media page displays:
- YouTube Downloads widget (stats)
- Recent YouTube Videos widget (last downloads)

---

## Docker Stats Exporter

**Hosts**: docker-vm-core-utilities-1, docker-vm-media01
**Status**: Deployed December 22, 2025

| Port | Purpose |
|------|---------|
| 9417 | Prometheus metrics endpoint |

### Metrics

- `container_cpu_usage_percent`
- `container_memory_usage_bytes`
- `container_network_rx_bytes` / `container_network_tx_bytes`
- `container_running` (1/0)

### Grafana Dashboard

Container metrics displayed in "Container Monitoring" dashboard.

---

## Karakeep (AI Bookmark Manager)

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 30, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 3005 | http://192.168.40.13:3005 | Web interface |

### Features

- AI-powered bookmark tagging and organization
- Full-text search with Meilisearch
- Automatic screenshot capture via headless Chrome
- Browser extension support
- RSS feed generation

### Architecture

Karakeep requires multiple containers:

| Container | Purpose |
|-----------|---------|
| karakeep | Main application (Next.js) |
| karakeep-meilisearch | Full-text search engine |
| karakeep-chrome | Headless Chrome for screenshots |

### Management

```bash
# View logs
ssh hermes-admin@192.168.40.13 "docker logs karakeep"

# Restart all containers
ssh hermes-admin@192.168.40.13 "cd /opt/karakeep && docker compose restart"
```

**Documentation**: https://docs.karakeep.app

---

## Wizarr (Media Server Invitations)

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 30, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 5690 | http://192.168.40.13:5690 | Web interface |

### Features

- Generate invitation links for Jellyfin/Plex users
- Customizable user onboarding flow
- Automatic library access configuration
- Expiring invitations with usage limits
- Discord integration for notifications

### Integration with Jellyfin

Wizarr connects to Jellyfin at `http://192.168.40.11:8096` to create users and assign library permissions.

### Management

```bash
# View logs
ssh hermes-admin@192.168.40.13 "docker logs wizarr"

# Restart
ssh hermes-admin@192.168.40.13 "cd /opt/wizarr && docker compose restart"
```

**Documentation**: https://docs.wizarr.dev

---

## Tracearr (Media Tracking)

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 30, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 3002 | http://192.168.40.13:3002 | Web interface |

### Features

- Media tracking and statistics for Jellyfin
- Watch history and analytics
- User activity monitoring
- Media consumption reports

### Management

```bash
# View logs
ssh hermes-admin@192.168.40.13 "docker logs tracearr"

# Restart
ssh hermes-admin@192.168.40.13 "cd /opt/tracearr && docker compose restart"
```

---

## Paperless-ngx (Document Management)

**Host**: docker-vm-core-utilities-1 (192.168.40.13)
**Status**: Deployed December 30, 2025

| Port | URL | Purpose |
|------|-----|---------|
| 8000 | http://192.168.40.13:8000 | Web interface |

### Features

- Automatic document scanning and OCR
- Full-text search across all documents
- Tagging and categorization
- Correspondent and document type management
- Email consumption for automatic import

### Architecture

Paperless requires Redis for caching and task queue:

| Container | Purpose |
|-----------|---------|
| paperless | Main application (Django) |
| paperless-redis | Redis cache and task queue |

### Folder Structure

| Path | Purpose |
|------|---------|
| `/opt/paperless/data` | Database and settings |
| `/opt/paperless/media` | Processed documents |
| `/opt/paperless/consume` | Drop folder for new documents |
| `/opt/paperless/export` | Backup export folder |

### Management

```bash
# View logs
ssh hermes-admin@192.168.40.13 "docker logs paperless"

# Create superuser
ssh hermes-admin@192.168.40.13 "docker exec -it paperless python3 manage.py createsuperuser"

# Restart
ssh hermes-admin@192.168.40.13 "cd /opt/paperless && docker compose restart"
```

---

## Related Documentation

- [[08 - Arr Media Stack]] - Media stack details
- [[09 - Traefik Reverse Proxy]] - SSL and routing
- [[17 - Monitoring Stack]] - Monitoring infrastructure
- [[18 - Observability Stack]] - Distributed tracing
- [[19 - Watchtower Updates]] - Interactive container updates
- [[06 - Ansible Automation]] - Deployment playbooks
- [[11 - Credentials]] - API keys and passwords
- [[15 - New Service Onboarding Guide]] - Adding new services

