# Docker Services Inventory

This document provides a comprehensive list of all Docker services running across the homelab infrastructure.

**Last Updated:** December 26, 2025

---

## docker-vm-core-utilities01 (192.168.40.13)

Primary host for utilities, monitoring, and web applications.

| Service | Container Name | Port | Internal Port | Purpose |
|---------|----------------|------|---------------|---------|
| Glance | glance | 8080 | 8080 | Dashboard homepage |
| Glance GitHub Graph | glance-github-graph | 8089 | 8080 | GitHub contribution graph widget |
| Grafana | grafana | 3030 | 3000 | Metrics visualization |
| Prometheus | prometheus | 9090 | 9090 | Metrics collection |
| n8n | n8n | 5678 | 5678 | Workflow automation |
| Uptime Kuma | uptime-kuma | 3001 | 3001 | Uptime monitoring |
| Paperless-ngx | paperless-ngx | 8000 | 8000 | Document management |
| Speedtest Tracker | speedtest-tracker | 3000 | 80 | Network speed monitoring |
| Karakeep | karakeep | 3005 | 3000 | Bookmark manager |
| Lagident | lagident | 9933 | 8080 | Container status dashboard |
| Wizarr | wizarr | 5690 | 5690 | Jellyfin invite management |
| Tracearr | tracearr | 3002 | 3000 | *arr stack monitoring |
| Reactive Resume | reactive-resume | 5057 | 3000 | Resume builder |
| BentoPDF | bentopdf | 5055 | 8080 | PDF tools |
| Ghostwire | ghostwire | 5056 | 5000 | Container discovery |
| Edgeshark | edgeshark | 5058 | 5001 | Network capture |
| Open Notebook | open-notebook | 8502, 5059 | 8502, 5055 | AI notebook |
| Update Manager | update-manager | 5050 | 5000 | Custom update dashboard |
| cAdvisor | cadvisor | 8081 | 8080 | Container metrics |
| **Custom APIs** | | | | |
| NBA Stats API | nba-stats-api | 5060 | 5060 | NBA scores for Glance Sports tab |
| Media Stats API | media-stats-api | 5054 | 5054 | Media statistics for Glance |
| Life Progress API | life-progress | 5051 | 5051 | Life progress widget |
| Reddit Manager | reddit-manager | 5053 | 5053 | Reddit monitoring |
| **Discord Bots** | | | | |
| Sysadmin Bot | sysadmin-bot | - | - | Discord infrastructure bot |
| Project Bot | project-bot | - | - | Discord project notifications |
| **Exporters** | | | | |
| Docker Exporter | docker-exporter | 9417 | 9417 | Docker metrics |
| SNMP Exporter | snmp-exporter | 9116 | 9116 | SNMP metrics (NAS) |
| PVE Exporter | pve-exporter | 9221 | 9221 | Proxmox metrics |
| OPNsense Exporter | opnsense-exporter | 9198 | 8080 | Firewall metrics |
| Omada Exporter | omada-exporter | - | - | Network controller metrics |
| **Background Services** | | | | |
| Watchtower | watchtower | - | - | Container auto-updates |
| Paperless DB | paperless-db | - | 5432 | PostgreSQL for Paperless |
| Paperless Redis | paperless-redis | - | 6379 | Redis cache |
| Karakeep Chrome | karakeep-chrome | - | - | Browser automation |
| Karakeep Meilisearch | karakeep-meilisearch | - | 7700 | Search engine |
| Reactive Resume DB | reactive-resume-db | - | 5432 | PostgreSQL |
| Reactive Resume Minio | reactive-resume-minio | - | 9000 | Object storage |

---

## docker-vm-media01 (192.168.40.11)

Primary host for media services and the *arr stack.

| Service | Container Name | Port | Internal Port | Purpose |
|---------|----------------|------|---------------|---------|
| **Media Server** | | | | |
| Jellyfin | jellyfin | 8096, 8920 | 8096, 8920 | Media streaming server |
| **Request Management** | | | | |
| Overseerr | overseerr | 5055 | 5055 | Media request management |
| Jellyseerr | jellyseerr | 5056 | 5055 | Jellyfin request management |
| ***arr Stack** | | | | |
| Sonarr | sonarr | 8989 | 8989 | TV show management |
| Radarr | radarr | 7878 | 7878 | Movie management |
| Lidarr | lidarr | 8686 | 8686 | Music management |
| Bazarr | bazarr | 6767 | 6767 | Subtitle management |
| Prowlarr | prowlarr | 9696 | 9696 | Indexer management |
| **Download Clients** | | | | |
| SABnzbd | sabnzbd | 8081 | 8080 | Usenet downloader |
| Deluge | deluge | 8112, 6881 | 8112, 6881 | Torrent client |
| Autobrr | autobrr | 7474 | 7474 | Torrent automation |
| **Transcoding** | | | | |
| Tdarr | tdarr | 8265, 8266 | 8265, 8266 | Media transcoding |
| **Monitoring** | | | | |
| cAdvisor | cadvisor | 8083 | 8080 | Container metrics |
| Docker Exporter | docker-exporter | 9417 | 9417 | Docker metrics |
| Download Monitor | download-monitor | - | - | Download status |
| **Background Services** | | | | |
| Watchtower | watchtower | - | - | Container auto-updates |

---

## Port Allocation Summary

### By Port Range

| Range | Usage |
|-------|-------|
| 3000-3099 | Web Applications (Grafana, Uptime, Speedtest, Karakeep, Tracearr) |
| 5050-5099 | Custom APIs and Tools |
| 5500-5699 | Media Request Services (Overseerr, Jellyseerr, Wizarr) |
| 6700-6999 | *arr Services (Bazarr, Lidarr) |
| 7400-7900 | *arr Services (Autobrr, Radarr) |
| 8000-8999 | Web UIs (Paperless, Jellyfin, Deluge, Sonarr, etc.) |
| 9000-9999 | Exporters and Metrics |

### Reserved Ports

| Port | Service | Host |
|------|---------|------|
| 5055 | BentoPDF (utilities), Overseerr (media) | Both |
| 5056 | Ghostwire (utilities), Jellyseerr (media) | Both |
| 8081 | cAdvisor (utilities), SABnzbd (media) | Both |
| 9417 | Docker Exporter | Both |

---

## Quick Access URLs

### docker-vm-core-utilities01 (192.168.40.13)

| Service | Local URL | External URL |
|---------|-----------|--------------|
| Glance | http://192.168.40.12:8080 | https://glance.hrmsmrflrii.xyz |
| Grafana | http://192.168.40.13:3030 | https://grafana.hrmsmrflrii.xyz |
| Prometheus | http://192.168.40.13:9090 | https://prometheus.hrmsmrflrii.xyz |
| n8n | http://192.168.40.13:5678 | https://n8n.hrmsmrflrii.xyz |
| Uptime Kuma | http://192.168.40.13:3001 | https://uptime.hrmsmrflrii.xyz |
| Paperless | http://192.168.40.13:8000 | https://paperless.hrmsmrflrii.xyz |
| Speedtest | http://192.168.40.13:3000 | https://speedtest.hrmsmrflrii.xyz |
| Karakeep | http://192.168.40.13:3005 | https://karakeep.hrmsmrflrii.xyz |
| Lagident | http://192.168.40.13:9933 | https://lagident.hrmsmrflrii.xyz |
| Wizarr | http://192.168.40.13:5690 | https://wizarr.hrmsmrflrii.xyz |
| Tracearr | http://192.168.40.13:3002 | https://tracearr.hrmsmrflrii.xyz |

### docker-vm-media01 (192.168.40.11)

| Service | Local URL | External URL |
|---------|-----------|--------------|
| Jellyfin | http://192.168.40.11:8096 | https://jellyfin.hrmsmrflrii.xyz |
| Overseerr | http://192.168.40.11:5055 | https://overseerr.hrmsmrflrii.xyz |
| Jellyseerr | http://192.168.40.11:5056 | https://jellyseerr.hrmsmrflrii.xyz |
| Sonarr | http://192.168.40.11:8989 | https://sonarr.hrmsmrflrii.xyz |
| Radarr | http://192.168.40.11:7878 | https://radarr.hrmsmrflrii.xyz |
| Lidarr | http://192.168.40.11:8686 | https://lidarr.hrmsmrflrii.xyz |
| Bazarr | http://192.168.40.11:6767 | https://bazarr.hrmsmrflrii.xyz |
| Prowlarr | http://192.168.40.11:9696 | https://prowlarr.hrmsmrflrii.xyz |
| SABnzbd | http://192.168.40.11:8081 | https://sabnzbd.hrmsmrflrii.xyz |
| Tdarr | http://192.168.40.11:8265 | https://tdarr.hrmsmrflrii.xyz |

---

## Notes

1. **Watchtower**: Runs on both hosts for automatic container updates
2. **cAdvisor**: Runs on both hosts for container metrics
3. **Docker Exporter**: Runs on both hosts for Prometheus metrics
4. **Background containers** (marked with `-`): Internal services not exposed externally
5. **Port conflicts**: Some ports (5055, 5056, 8081) are reused across hosts but not conflicting

---

## Maintenance

This document should be updated whenever:
- A new service is deployed
- A service is removed
- Port mappings change
- External URLs are added/modified

To get the current list of running containers:
```bash
# docker-utilities
ssh docker-utilities "docker ps --format '{{.Names}}\t{{.Ports}}' | sort"

# docker-media
ssh docker-media "docker ps --format '{{.Names}}\t{{.Ports}}' | sort"
```
