# Docker Services Reference

Complete documentation for all Docker services running on the homelab infrastructure.

---

## Table of Contents

1. [Overview](#overview)
2. [Core Utilities Host](#core-utilities-host-19216840-13)
3. [Media Host](#media-host-192168401-1)
4. [Service Categories](#service-categories)
5. [Quick Reference](#quick-reference)

---

## Overview

### Host Summary

| Host | IP Address | Purpose | Container Count |
|------|------------|---------|-----------------|
| **docker-vm-core-utilities01** | 192.168.40.13 | Monitoring, Utilities, APIs | 21 |
| **docker-lxc-media** | 192.168.40.11 | Media Stack, Downloads | 12 |

### Access Information

| Host | SSH Access |
|------|------------|
| Core Utilities | `ssh hermes-admin@192.168.40.13` |
| Media | `ssh hermes-admin@192.168.40.11` |

---

## Core Utilities Host (192.168.40.13)

**Host**: docker-vm-core-utilities01
**Purpose**: Monitoring, observability, automation, and utility services
**Location**: Proxmox Node 01

### Monitoring Stack

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Grafana** | grafana/grafana:latest | 3030 | https://grafana.hrmsmrflrii.xyz | Visualization and dashboards |
| **Prometheus** | prom/prometheus:latest | 9090 | http://192.168.40.13:9090 | Metrics collection and storage |
| **Uptime Kuma** | louislam/uptime-kuma:latest | 3001 | https://uptime.hrmsmrflrii.xyz | Uptime monitoring |
| **Jaeger** | jaegertracing/all-in-one:latest | 16686 | http://192.168.40.13:16686 | Distributed tracing |
| **cAdvisor** | gcr.io/cadvisor/cadvisor:latest | 8081 | http://192.168.40.13:8081 | Container metrics |

#### Grafana

**Web UI**: https://grafana.hrmsmrflrii.xyz

```yaml
Container: grafana
Image: grafana/grafana:latest
Port: 3030 → 3000
Status: Running
```

**Key Dashboards**:
- Container Status History
- Synology NAS Storage
- Omada Network Overview
- Proxmox Cluster
- PBS Backup Status

**Configuration Path**: `/opt/grafana/`

#### Prometheus

**Web UI**: http://192.168.40.13:9090

```yaml
Container: prometheus
Image: prom/prometheus:latest
Port: 9090
Status: Running
```

**Scrape Targets**:
- Node exporters (all hosts)
- cAdvisor (container metrics)
- SNMP exporter (network devices)
- PBS exporter (backup metrics)
- PVE exporter (Proxmox metrics)

**Configuration Path**: `/opt/prometheus/`

#### Uptime Kuma

**Web UI**: https://uptime.hrmsmrflrii.xyz

```yaml
Container: uptime-kuma
Image: louislam/uptime-kuma:latest
Port: 3001
Status: Running (healthy)
```

**Monitors**:
- All homelab services (HTTP/HTTPS)
- Infrastructure endpoints
- External URLs

**Configuration Path**: `/opt/uptime-kuma/`

---

### Prometheus Exporters

| Exporter | Image | Port | Purpose |
|----------|-------|------|---------|
| **pve-exporter** | prompve/prometheus-pve-exporter:latest | 9221 | Proxmox VE metrics |
| **pbs-exporter** | ghcr.io/natrontech/pbs-exporter:latest | 9101 | Proxmox Backup Server metrics |
| **snmp-exporter** | prom/snmp-exporter:latest | 9116 | Network device SNMP metrics |
| **cAdvisor** | gcr.io/cadvisor/cadvisor:latest | 8081 | Container metrics |

#### PVE Exporter

```yaml
Container: pve-exporter
Image: prompve/prometheus-pve-exporter:latest
Port: 9221
Purpose: Exposes Proxmox VE cluster metrics to Prometheus
```

**Metrics Exported**:
- Node CPU/Memory/Storage usage
- VM/Container status
- Cluster quorum status

#### PBS Exporter

```yaml
Container: pbs-exporter
Image: ghcr.io/natrontech/pbs-exporter:latest
Port: 9101
Purpose: Exposes Proxmox Backup Server metrics
```

**Metrics Exported**:
- Backup job status
- Datastore usage
- Snapshot counts
- Verification status

#### SNMP Exporter

```yaml
Container: snmp-exporter
Image: prom/snmp-exporter:latest
Port: 9116
Purpose: Queries network devices via SNMP
```

**Monitored Devices**:
- TP-Link Omada switches (SG3210, SG2210P)
- ER605 Router
- Synology NAS

---

### Utility Services

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Paperless-ngx** | ghcr.io/paperless-ngx/paperless-ngx:latest | 8000 | https://paperless.hrmsmrflrii.xyz | Document management |
| **n8n** | n8nio/n8n:latest | - | https://n8n.hrmsmrflrii.xyz | Workflow automation |
| **Speedtest Tracker** | lscr.io/linuxserver/speedtest-tracker:latest | 3000 | https://speedtest.hrmsmrflrii.xyz | Internet speed monitoring |

#### Paperless-ngx

**Web UI**: https://paperless.hrmsmrflrii.xyz

```yaml
Container: paperless
Image: ghcr.io/paperless-ngx/paperless-ngx:latest
Port: 8000
Status: Running (healthy)
Dependencies: paperless-redis
```

**Features**:
- Document OCR and indexing
- Full-text search
- Automatic tagging
- Correspondent matching

**Configuration Path**: `/opt/paperless/`

**Supporting Container**:
```yaml
Container: paperless-redis
Image: redis:7-alpine
Port: 6379 (internal)
Purpose: Caching and task queue
```

#### n8n

**Web UI**: https://n8n.hrmsmrflrii.xyz

```yaml
Container: n8n
Image: n8nio/n8n:latest
Port: Internal (via Traefik)
Status: Running
```

**Use Cases**:
- Discord webhook processing
- API integrations
- Scheduled tasks
- Data transformations

**Configuration Path**: `/opt/n8n/`

---

### Custom APIs & Bots

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Sentinel Bot** | sentinel-bot:latest | 5050 | - | Discord bot for media notifications |
| **Life Progress API** | life-progress-life-progress | 5051 | - | Life progress tracking API |
| **NAS Backup Status API** | nas-backup-status-api | 9102 | - | NAS backup monitoring API |
| **Homelab Chronicle** | homelab-chronicle | 3010 | https://chronicle.hrmsmrflrii.xyz | Homelab activity logging |

#### Sentinel Bot

```yaml
Container: sentinel-bot
Image: sentinel-bot:latest
Port: 5050
Status: Running (healthy)
```

**Features**:
- Discord notifications for new media
- Integration with Radarr/Sonarr
- Download notifications
- Command interface

**Configuration Path**: `/opt/sentinel-bot/`

#### Life Progress API

```yaml
Container: life-progress
Image: life-progress-life-progress
Port: 5051
Status: Running
```

**Purpose**: API for life progress metrics and tracking

**Configuration Path**: `/opt/life-progress/`

#### NAS Backup Status API

```yaml
Container: nas-backup-status-api
Image: nas-backup-status-api
Port: 9102
Status: Running
```

**Purpose**: Provides backup status metrics for Prometheus/Grafana

**Configuration Path**: `/opt/nas-backup-status-api/`

#### Homelab Chronicle

```yaml
Container: homelab-chronicle
Image: homelab-chronicle
Port: 3010 → 3000
Status: Running
```

**Purpose**: Logs and displays homelab activities and changes

**Configuration Path**: `/opt/homelab-chronicle/`

---

### Media Management Tools

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Wizarr** | ghcr.io/wizarrrr/wizarr:latest | 5690 | https://wizarr.hrmsmrflrii.xyz | Media server invitation management |
| **Tracearr** | ghcr.io/connorgallopo/tracearr:supervised | 3002 | https://tracearr.hrmsmrflrii.xyz | *arr stack monitoring |
| **Karakeep** | ghcr.io/karakeep-app/karakeep:release | 3005 | https://karakeep.hrmsmrflrii.xyz | Bookmark/link management |

#### Wizarr

**Web UI**: https://wizarr.hrmsmrflrii.xyz

```yaml
Container: wizarr
Image: ghcr.io/wizarrrr/wizarr:latest
Port: 5690
Status: Running
```

**Features**:
- Generate invitation links for Jellyfin/Plex
- User management
- Request management integration

**Configuration Path**: `/opt/wizarr/`

#### Tracearr

**Web UI**: https://tracearr.hrmsmrflrii.xyz

```yaml
Container: tracearr
Image: ghcr.io/connorgallopo/tracearr:supervised
Port: 3002 → 3000
Status: Running (healthy)
```

**Features**:
- Monitor *arr stack download progress
- Unified view of all downloads
- Integration with Radarr/Sonarr

**Configuration Path**: `/opt/tracearr/`

#### Karakeep

**Web UI**: https://karakeep.hrmsmrflrii.xyz

```yaml
Container: karakeep
Image: ghcr.io/karakeep-app/karakeep:release
Port: 3005 → 3000
Status: Running
Dependencies: karakeep-chrome, karakeep-meilisearch
```

**Features**:
- Bookmark management
- Full-text search
- Screenshot capture
- Tag organization

**Supporting Containers**:
```yaml
Container: karakeep-chrome
Image: gcr.io/zenika-hub/alpine-chrome:123
Purpose: Screenshot rendering

Container: karakeep-meilisearch
Image: getmeili/meilisearch:v1.11
Port: 7700 (internal)
Purpose: Search indexing
```

**Configuration Path**: `/opt/karakeep/`

---

## Media Host (192.168.40.11)

**Host**: docker-lxc-media
**Purpose**: Media server, content management, and download automation
**Location**: Proxmox Node 01 (LXC Container)

### Media Server

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Jellyfin** | jellyfin/jellyfin:latest | 8096 | https://jellyfin.hrmsmrflrii.xyz | Media streaming server |

#### Jellyfin

**Web UI**: https://jellyfin.hrmsmrflrii.xyz

```yaml
Container: jellyfin
Image: jellyfin/jellyfin:latest
Ports:
  - 8096 (Web UI)
  - 8920 (HTTPS)
  - 7359/udp (Client discovery)
  - 1900/udp (DLNA)
Status: Running
```

**Libraries**:
- Movies: `/mnt/media/Movies`
- TV Shows: `/mnt/media/Series`

**Features**:
- Hardware transcoding (Intel QuickSync)
- Multi-user support
- Mobile apps
- DLNA/Chromecast support

**Configuration Path**: `/opt/arr-stack/jellyfin/`

---

### Content Management (*arr Stack)

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Radarr** | lscr.io/linuxserver/radarr:latest | 7878 | https://radarr.hrmsmrflrii.xyz | Movie management |
| **Sonarr** | lscr.io/linuxserver/sonarr:latest | 8989 | https://sonarr.hrmsmrflrii.xyz | TV series management |
| **Lidarr** | lscr.io/linuxserver/lidarr:latest | 8686 | https://lidarr.hrmsmrflrii.xyz | Music management |
| **Prowlarr** | lscr.io/linuxserver/prowlarr:latest | 9696 | https://prowlarr.hrmsmrflrii.xyz | Indexer manager |
| **Bazarr** | lscr.io/linuxserver/bazarr:latest | 6767 | https://bazarr.hrmsmrflrii.xyz | Subtitle management |

#### Radarr

**Web UI**: https://radarr.hrmsmrflrii.xyz

```yaml
Container: radarr
Image: lscr.io/linuxserver/radarr:latest
Port: 7878
Status: Running
```

**Features**:
- Automatic movie downloading
- Quality profiles
- Custom formats
- Integration with download clients

**Paths**:
- Config: `/opt/arr-stack/radarr/`
- Movies: `/mnt/media/Movies`

#### Sonarr

**Web UI**: https://sonarr.hrmsmrflrii.xyz

```yaml
Container: sonarr
Image: lscr.io/linuxserver/sonarr:latest
Port: 8989
Status: Running
```

**Features**:
- Automatic TV episode downloading
- Season pack support
- Episode renaming
- Calendar view

**Paths**:
- Config: `/opt/arr-stack/sonarr/`
- TV Shows: `/mnt/media/Series`

#### Lidarr

**Web UI**: https://lidarr.hrmsmrflrii.xyz

```yaml
Container: lidarr
Image: lscr.io/linuxserver/lidarr:latest
Port: 8686
Status: Running
```

**Features**:
- Music library management
- Automatic album downloading
- Metadata fetching

**Paths**:
- Config: `/opt/arr-stack/lidarr/`
- Music: `/mnt/media/Music`

#### Prowlarr

**Web UI**: https://prowlarr.hrmsmrflrii.xyz

```yaml
Container: prowlarr
Image: lscr.io/linuxserver/prowlarr:latest
Port: 9696
Status: Running
```

**Features**:
- Centralized indexer management
- Sync indexers to all *arr apps
- Statistics and health monitoring

**Configuration Path**: `/opt/arr-stack/prowlarr/`

#### Bazarr

**Web UI**: https://bazarr.hrmsmrflrii.xyz

```yaml
Container: bazarr
Image: lscr.io/linuxserver/bazarr:latest
Port: 6767
Status: Running
```

**Features**:
- Automatic subtitle downloading
- Multiple language support
- Sync with Radarr/Sonarr

**Configuration Path**: `/opt/arr-stack/bazarr/`

---

### Request Management

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Overseerr** | lscr.io/linuxserver/overseerr:latest | 5055 | https://overseerr.hrmsmrflrii.xyz | Plex requests |
| **Jellyseerr** | fallenbagel/jellyseerr:latest | 5056 | https://jellyseerr.hrmsmrflrii.xyz | Jellyfin requests |

#### Overseerr

**Web UI**: https://overseerr.hrmsmrflrii.xyz

```yaml
Container: overseerr
Image: lscr.io/linuxserver/overseerr:latest
Port: 5055
Status: Running
```

**Features**:
- User request interface for Plex
- Integration with Radarr/Sonarr
- User management

**Configuration Path**: `/opt/arr-stack/overseerr/`

#### Jellyseerr

**Web UI**: https://jellyseerr.hrmsmrflrii.xyz

```yaml
Container: jellyseerr
Image: fallenbagel/jellyseerr:latest
Port: 5056 → 5055
Status: Running
```

**Features**:
- User request interface for Jellyfin
- Integration with Radarr/Sonarr
- User management

**Configuration Path**: `/opt/arr-stack/jellyseerr/`

---

### Download Clients

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Deluge** | lscr.io/linuxserver/deluge:latest | 8112 | http://192.168.40.11:8112 | BitTorrent client |
| **SABnzbd** | lscr.io/linuxserver/sabnzbd:latest | 8081 | http://192.168.40.11:8081 | Usenet client |

#### Deluge

**Web UI**: http://192.168.40.11:8112

```yaml
Container: deluge
Image: lscr.io/linuxserver/deluge:latest
Ports:
  - 8112 (Web UI)
  - 6881 (Incoming connections)
  - 6881/udp
Status: Running
Default Password: deluge (change immediately!)
```

**Configuration Path**: `/opt/arr-stack/deluge/`

#### SABnzbd

**Web UI**: http://192.168.40.11:8081

```yaml
Container: sabnzbd
Image: lscr.io/linuxserver/sabnzbd:latest
Port: 8081 → 8080
Status: Running
```

**Configuration Path**: `/opt/arr-stack/sabnzbd/`

---

### Automation & Transcoding

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Autobrr** | ghcr.io/autobrr/autobrr:latest | 7474 | http://192.168.40.11:7474 | IRC automation |
| **Tdarr** | ghcr.io/haveagitgat/tdarr:latest | 8265 | http://192.168.40.11:8265 | Transcoding automation |

#### Autobrr

**Web UI**: http://192.168.40.11:7474

```yaml
Container: autobrr
Image: ghcr.io/autobrr/autobrr:latest
Port: 7474
Status: Running
```

**Features**:
- IRC announce channel monitoring
- Instant release detection
- Filter rules

**Configuration Path**: `/opt/arr-stack/autobrr/`

#### Tdarr

**Web UI**: http://192.168.40.11:8265

```yaml
Container: tdarr
Image: ghcr.io/haveagitgat/tdarr:latest
Ports:
  - 8265 (Web UI)
  - 8266 (Server)
Status: Running
```

**Features**:
- Automated transcoding
- Media health checking
- H.265 conversion
- Distributed processing

**Configuration Path**: `/opt/arr-stack/tdarr/`

---

## Service Categories

### By Category

```
MONITORING
├── Grafana (192.168.40.13:3030)
├── Prometheus (192.168.40.13:9090)
├── Uptime Kuma (192.168.40.13:3001)
├── Jaeger (192.168.40.13:16686)
└── cAdvisor (192.168.40.13:8081)

EXPORTERS
├── PVE Exporter (192.168.40.13:9221)
├── PBS Exporter (192.168.40.13:9101)
└── SNMP Exporter (192.168.40.13:9116)

UTILITIES
├── Paperless-ngx (192.168.40.13:8000)
├── n8n (via Traefik)
├── Speedtest Tracker (192.168.40.13:3000)
└── Karakeep (192.168.40.13:3005)

CUSTOM APPS
├── Sentinel Bot (192.168.40.13:5050)
├── Life Progress API (192.168.40.13:5051)
├── NAS Backup Status API (192.168.40.13:9102)
└── Homelab Chronicle (192.168.40.13:3010)

MEDIA SERVER
└── Jellyfin (192.168.40.11:8096)

MEDIA MANAGEMENT
├── Radarr (192.168.40.11:7878)
├── Sonarr (192.168.40.11:8989)
├── Lidarr (192.168.40.11:8686)
├── Prowlarr (192.168.40.11:9696)
└── Bazarr (192.168.40.11:6767)

REQUEST MANAGEMENT
├── Overseerr (192.168.40.11:5055)
├── Jellyseerr (192.168.40.11:5056)
├── Wizarr (192.168.40.13:5690)
└── Tracearr (192.168.40.13:3002)

DOWNLOAD CLIENTS
├── Deluge (192.168.40.11:8112)
└── SABnzbd (192.168.40.11:8081)

AUTOMATION
├── Autobrr (192.168.40.11:7474)
└── Tdarr (192.168.40.11:8265)
```

---

## Quick Reference

### All Services by Port

#### Core Utilities (192.168.40.13)

| Port | Service | Protocol |
|------|---------|----------|
| 3000 | Speedtest Tracker | HTTP |
| 3001 | Uptime Kuma | HTTP |
| 3002 | Tracearr | HTTP |
| 3005 | Karakeep | HTTP |
| 3010 | Homelab Chronicle | HTTP |
| 3030 | Grafana | HTTP |
| 4317 | Jaeger (OTLP gRPC) | gRPC |
| 4318 | Jaeger (OTLP HTTP) | HTTP |
| 5050 | Sentinel Bot | HTTP |
| 5051 | Life Progress API | HTTP |
| 5690 | Wizarr | HTTP |
| 8000 | Paperless-ngx | HTTP |
| 8081 | cAdvisor | HTTP |
| 9090 | Prometheus | HTTP |
| 9101 | PBS Exporter | HTTP |
| 9102 | NAS Backup Status API | HTTP |
| 9116 | SNMP Exporter | HTTP |
| 9221 | PVE Exporter | HTTP |
| 16686 | Jaeger UI | HTTP |

#### Media (192.168.40.11)

| Port | Service | Protocol |
|------|---------|----------|
| 5055 | Overseerr | HTTP |
| 5056 | Jellyseerr | HTTP |
| 6767 | Bazarr | HTTP |
| 6881 | Deluge (P2P) | TCP/UDP |
| 7474 | Autobrr | HTTP |
| 7878 | Radarr | HTTP |
| 8081 | SABnzbd | HTTP |
| 8096 | Jellyfin | HTTP |
| 8112 | Deluge Web | HTTP |
| 8265 | Tdarr | HTTP |
| 8266 | Tdarr Server | HTTP |
| 8686 | Lidarr | HTTP |
| 8920 | Jellyfin (HTTPS) | HTTPS |
| 8989 | Sonarr | HTTP |
| 9696 | Prowlarr | HTTP |

### Docker Commands

```bash
# Core Utilities - List all containers
ssh hermes-admin@192.168.40.13 "docker ps -a"

# Media - List all containers
ssh hermes-admin@192.168.40.11 "docker ps -a"

# View container logs
docker logs <container_name> --tail 100

# Restart a container
docker restart <container_name>

# View container stats
docker stats --no-stream

# Enter container shell
docker exec -it <container_name> /bin/bash
```

### Configuration Paths

| Host | Base Path | Purpose |
|------|-----------|---------|
| Core Utilities | `/opt/<service>/` | Individual service configs |
| Media | `/opt/arr-stack/` | All media services |
| Media | `/mnt/media/` | NFS-mounted media storage |

### Traefik-Exposed Services

All services with `https://*.hrmsmrflrii.xyz` URLs are exposed via Traefik reverse proxy at 192.168.40.20.

---

## Related Documents

- [[17 - Glance Dashboard]] - Dashboard configuration
- [[19 - Monitoring Stack]] - Prometheus/Grafana details
- [[22 - Media Server Setup]] - Jellyfin and *arr stack
- [[23 - Traefik Reverse Proxy]] - Traefik configuration
- [[11 - Credentials]] - Service credentials

---

*Last updated: January 14, 2026*
*Core Utilities: 21 containers*
*Media: 12 containers*
