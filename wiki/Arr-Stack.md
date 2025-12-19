# Arr Stack

> **TL;DR**: Complete media automation stack with 10 services for movies, TV, music, and streaming - all running on docker-vm-media01.

## Stack Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Arr Stack Architecture                                    │
│                    docker-vm-media01 (192.168.40.11)                        │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         Prowlarr                                     │   │
│   │                     (Indexer Manager)                                │   │
│   │                         :9696                                        │   │
│   └────────────────────────────┬────────────────────────────────────────┘   │
│                                │                                             │
│            ┌───────────────────┼───────────────────┐                        │
│            │                   │                   │                        │
│            ▼                   ▼                   ▼                        │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                 │
│   │   Radarr     │    │   Sonarr     │    │   Lidarr     │                 │
│   │   (Movies)   │    │    (TV)      │    │   (Music)    │                 │
│   │    :7878     │    │    :8989     │    │    :8686     │                 │
│   └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                 │
│          │                   │                   │                          │
│          └───────────────────┼───────────────────┘                          │
│                              │                                               │
│                              ▼                                               │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         Bazarr                                       │   │
│   │                      (Subtitles)                                     │   │
│   │                         :6767                                        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                               │
│                              ▼                                               │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                        Jellyfin                                      │   │
│   │                     (Media Server)                                   │   │
│   │                         :8096                                        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                              ▲                                               │
│                              │                                               │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                      Jellyseerr                                      │   │
│   │                   (Media Requests)                                   │   │
│   │                         :5056                                        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Additional Services:                                                       │
│   ┌────────────┐  ┌────────────┐  ┌────────────┐                           │
│   │   Tdarr    │  │  Autobrr   │  │ Overseerr  │                           │
│   │ (Transcode)│  │ (Automate) │  │  (Plex)    │                           │
│   │   :8265    │  │   :7474    │  │   :5055    │                           │
│   └────────────┘  └────────────┘  └────────────┘                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Service Reference

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| **Jellyfin** | 8096 | https://jellyfin.hrmsmrflrii.xyz | Media streaming |
| **Radarr** | 7878 | https://radarr.hrmsmrflrii.xyz | Movie management |
| **Sonarr** | 8989 | https://sonarr.hrmsmrflrii.xyz | TV series management |
| **Lidarr** | 8686 | https://lidarr.hrmsmrflrii.xyz | Music management |
| **Prowlarr** | 9696 | https://prowlarr.hrmsmrflrii.xyz | Indexer manager |
| **Bazarr** | 6767 | https://bazarr.hrmsmrflrii.xyz | Subtitle management |
| **Overseerr** | 5055 | https://overseerr.hrmsmrflrii.xyz | Requests (Plex) |
| **Jellyseerr** | 5056 | https://jellyseerr.hrmsmrflrii.xyz | Requests (Jellyfin) |
| **Tdarr** | 8265 | https://tdarr.hrmsmrflrii.xyz | Transcoding |
| **Autobrr** | 7474 | https://autobrr.hrmsmrflrii.xyz | Torrent automation |

---

## Storage Configuration

### NFS Mount

Media files stored on Synology NAS:

```
NAS: 192.168.20.31:/volume2/Proxmox-Media
  │
  └── Mounted at: /mnt/media (on docker-vm-media01)
      │
      ├── Movies/
      ├── Series/
      ├── Music/
      └── Downloads/
```

### Docker Volume Mapping

```yaml
volumes:
  # Config directories (local)
  - /opt/arr-stack/jellyfin:/config
  - /opt/arr-stack/radarr:/config
  # ...

  # Media directories (NFS)
  - /mnt/media/Movies:/movies
  - /mnt/media/Series:/series
  - /mnt/media/Music:/music
  - /mnt/media/Downloads:/downloads
```

---

## Deployment

### docker-compose.yml

**Path**: `/opt/arr-stack/docker-compose.yml`

```yaml
version: "3.8"

services:
  # ==========================================================================
  # MEDIA SERVER
  # ==========================================================================
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/arr-stack/jellyfin:/config
      - /mnt/media/Movies:/movies:ro
      - /mnt/media/Series:/series:ro
      - /mnt/media/Music:/music:ro
    ports:
      - "8096:8096"
    restart: unless-stopped

  # ==========================================================================
  # MEDIA MANAGEMENT
  # ==========================================================================
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/arr-stack/radarr:/config
      - /mnt/media/Movies:/movies
      - /mnt/media/Downloads:/downloads
    ports:
      - "7878:7878"
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/arr-stack/sonarr:/config
      - /mnt/media/Series:/series
      - /mnt/media/Downloads:/downloads
    ports:
      - "8989:8989"
    restart: unless-stopped

  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: lidarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/arr-stack/lidarr:/config
      - /mnt/media/Music:/music
      - /mnt/media/Downloads:/downloads
    ports:
      - "8686:8686"
    restart: unless-stopped

  # ==========================================================================
  # INDEXER & SUBTITLES
  # ==========================================================================
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/arr-stack/prowlarr:/config
    ports:
      - "9696:9696"
    restart: unless-stopped

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/arr-stack/bazarr:/config
      - /mnt/media/Movies:/movies
      - /mnt/media/Series:/series
    ports:
      - "6767:6767"
    restart: unless-stopped

  # ==========================================================================
  # REQUEST MANAGEMENT
  # ==========================================================================
  overseerr:
    image: lscr.io/linuxserver/overseerr:latest
    container_name: overseerr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/arr-stack/overseerr:/config
    ports:
      - "5055:5055"
    restart: unless-stopped

  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    environment:
      - TZ=America/New_York
    volumes:
      - /opt/arr-stack/jellyseerr:/app/config
    ports:
      - "5056:5055"
    restart: unless-stopped

  # ==========================================================================
  # AUTOMATION
  # ==========================================================================
  tdarr:
    image: ghcr.io/haveagitgat/tdarr:latest
    container_name: tdarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - serverIP=0.0.0.0
      - serverPort=8266
      - webUIPort=8265
      - internalNode=true
      - inContainer=true
    volumes:
      - /opt/arr-stack/tdarr/server:/app/server
      - /opt/arr-stack/tdarr/configs:/app/configs
      - /opt/arr-stack/tdarr/logs:/app/logs
      - /mnt/media:/media
      - /tmp/tdarr:/temp
    ports:
      - "8265:8265"
      - "8266:8266"
    restart: unless-stopped

  autobrr:
    image: ghcr.io/autobrr/autobrr:latest
    container_name: autobrr
    environment:
      - TZ=America/New_York
    volumes:
      - /opt/arr-stack/autobrr:/config
    ports:
      - "7474:7474"
    restart: unless-stopped
```

---

## Initial Configuration

### 1. Prowlarr (Indexers)

**URL**: https://prowlarr.hrmsmrflrii.xyz

1. Add indexers (torrent/usenet)
2. Configure sync to Radarr, Sonarr, Lidarr
3. Settings → Apps → Add applications

### 2. Radarr (Movies)

**URL**: https://radarr.hrmsmrflrii.xyz

1. Settings → Media Management → Root Folder: `/movies`
2. Settings → Indexers (auto-synced from Prowlarr)
3. Settings → Download Clients → Add client

### 3. Sonarr (TV)

**URL**: https://sonarr.hrmsmrflrii.xyz

1. Settings → Media Management → Root Folder: `/series`
2. Settings → Indexers (auto-synced from Prowlarr)
3. Settings → Download Clients → Add client

### 4. Lidarr (Music)

**URL**: https://lidarr.hrmsmrflrii.xyz

1. Settings → Media Management → Root Folder: `/music`
2. Settings → Indexers (auto-synced from Prowlarr)
3. Settings → Download Clients → Add client

### 5. Bazarr (Subtitles)

**URL**: https://bazarr.hrmsmrflrii.xyz

1. Settings → Sonarr → Add server (API key from Sonarr)
2. Settings → Radarr → Add server (API key from Radarr)
3. Settings → Providers → Add subtitle providers

### 6. Jellyfin (Media Server)

**URL**: https://jellyfin.hrmsmrflrii.xyz

1. Initial setup wizard
2. Add libraries:
   - Movies → `/movies`
   - TV Shows → `/series`
   - Music → `/music`

### 7. Jellyseerr (Requests)

**URL**: https://jellyseerr.hrmsmrflrii.xyz

1. Connect to Jellyfin server
2. Connect to Radarr (API key)
3. Connect to Sonarr (API key)

---

## API Keys

### Obtaining API Keys

Each *arr application has an API key for integration:

**Radarr**: Settings → General → API Key
**Sonarr**: Settings → General → API Key
**Lidarr**: Settings → General → API Key
**Prowlarr**: Settings → General → API Key

### Integration Matrix

| From | To | Purpose |
|------|-----|---------|
| Prowlarr | Radarr, Sonarr, Lidarr | Sync indexers |
| Bazarr | Radarr, Sonarr | Get movie/show info |
| Jellyseerr | Radarr, Sonarr | Send requests |
| Jellyseerr | Jellyfin | User auth |

---

## Operations

### Check Status

```bash
# SSH to host
ssh hermes-admin@192.168.40.11

# View all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check specific service
docker logs jellyfin --tail 50
```

### Restart Services

```bash
# Single service
docker restart radarr

# All services
cd /opt/arr-stack
docker compose restart

# Full recreate
docker compose down
docker compose up -d
```

### Update Services

```bash
cd /opt/arr-stack

# Pull latest images
docker compose pull

# Recreate with new images
docker compose up -d

# Clean up old images
docker image prune -f
```

### Backup Configuration

```bash
# Stop services (optional but recommended)
cd /opt/arr-stack
docker compose stop

# Backup config directories
tar -czvf arr-stack-backup-$(date +%Y%m%d).tar.gz /opt/arr-stack/

# Restart
docker compose start
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check logs
docker logs radarr

# Check container status
docker inspect radarr | jq '.[0].State'

# Common fix: permission issues
sudo chown -R 1000:1000 /opt/arr-stack/radarr
```

### NFS Mount Issues

```bash
# Check mount
df -h | grep media

# Remount if needed
sudo mount -a

# Check NFS access
ls -la /mnt/media/
```

### Can't Connect to Services

```bash
# Verify port is listening
ss -tlnp | grep 7878

# Test from host
curl http://localhost:7878

# Check firewall (if applicable)
sudo ufw status
```

### Import Failures

**Radarr/Sonarr can't import**:
- Check PUID/PGID match between containers
- Verify path mapping is correct
- Check file permissions on NFS

---

## Ansible Deployment

```bash
# From ansible-controller01
cd ~/ansible
ansible-playbook docker/deploy-arr-stack.yml
```

**Playbook tasks**:
1. Install NFS client
2. Create NFS mount
3. Create config directories
4. Deploy docker-compose.yml
5. Start containers

---

## What's Next?

- **[Traefik](Traefik)** - Reverse proxy configuration
- **[Services Overview](Services-Overview)** - All services
- **[Storage Architecture](Storage-Architecture)** - NFS setup

---

*The Arr stack: automated media management done right.*
