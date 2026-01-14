# Arr Media Stack

> **Internal Documentation** - Contains API keys and configuration details.

Related: [[00 - Homelab Index]] | [[07 - Deployed Services]] | [[11 - Credentials]]

---

## Overview

All Arr services run on **docker-vm-media01** (192.168.40.11) via Docker Compose.

---

## Services

| Service    | Port | URL                                | Purpose             |
| ---------- | ---- | ---------------------------------- | ------------------- |
| Jellyfin   | 8096 | https://jellyfin.hrmsmrflrii.xyz   | Media server        |
| Radarr     | 7878 | https://radarr.hrmsmrflrii.xyz     | Movie management    |
| Sonarr     | 8989 | https://sonarr.hrmsmrflrii.xyz     | TV series           |
| Lidarr     | 8686 | https://lidarr.hrmsmrflrii.xyz     | Music               |
| Prowlarr   | 9696 | https://prowlarr.hrmsmrflrii.xyz   | Indexer manager     |
| Bazarr     | 6767 | https://bazarr.hrmsmrflrii.xyz     | Subtitles           |
| Overseerr  | 5055 | https://overseerr.hrmsmrflrii.xyz  | Requests (Plex)     |
| Jellyseerr | 5056 | https://jellyseerr.hrmsmrflrii.xyz | Requests (Jellyfin) |
| Tdarr      | 8265 | https://tdarr.hrmsmrflrii.xyz      | Transcoding         |
| Autobrr    | 7474 | https://autobrr.hrmsmrflrii.xyz    | Torrent automation  |
| Deluge     | 8112 | https://deluge.hrmsmrflrii.xyz     | BitTorrent client   |
| SABnzbd    | 8081 | https://sabnzbd.hrmsmrflrii.xyz    | Usenet client       |

---

## API Keys

| Service | API Key |
|---------|---------|
| **Radarr** | `21f807cf286941158e11ba6477853821` |
| **Sonarr** | `50c598d01b294f929e5ecf36ae42ad2e` |
| **Lidarr** | `13fe89b5dbdb45d48418e0879781ff3b` |
| **Prowlarr** | `e5f64c69e6c04bd8ba5eb8952ed25dbc` |
| **Bazarr** | `6c0037b075a3ee20f9818c14a3c35e7d` |

---

## Download Clients

> [!info] Unified Path Structure (December 23, 2025)
> All arr-stack services now use unified `/data` mount for hardlink support. Download clients and *arrs share the same path structure.

### Deluge (BitTorrent)

**URL**: https://deluge.hrmsmrflrii.xyz

| Port | Protocol | Purpose |
|------|----------|---------|
| 8112 | TCP | Web UI |
| 6881 | TCP/UDP | Incoming connections |

**Download Paths** (unified `/data` mount):
| Setting | Container Path | Host Path |
|---------|----------------|-----------|
| Download to | `/data/Downloading` | `/mnt/media/Downloading` |
| Move completed to | `/data/Completed` | `/mnt/media/Completed` |

**Initial Setup**:
1. Default password: `deluge` (change immediately)
2. Enable label plugin for category support
3. Configure download paths using unified `/data` mount

**Arr Integration**:
- Settings → Download Clients → Add → Deluge
- Host: `deluge` (container name)
- Port: `8112`
- Category: `radarr` / `sonarr` / `lidarr`
- **Remote Path Mapping**: NOT needed (same unified paths)

### SABnzbd (Usenet)

**URL**: https://sabnzbd.hrmsmrflrii.xyz

| Port | Protocol | Purpose |
|------|----------|---------|
| 8081 | TCP | Web UI |

**Download Paths** (unified `/data` mount):
| Setting | Container Path | Host Path |
|---------|----------------|-----------|
| Temporary Download Folder | `/data/Incomplete` | `/mnt/media/Incomplete` |
| Completed Download Folder | `/data/Completed` | `/mnt/media/Completed` |

**Hostname Whitelist**:
SABnzbd requires external hostnames to be whitelisted. Configured in `/opt/arr-stack/sabnzbd/sabnzbd.ini`:
```ini
host_whitelist = sabnzbd.hrmsmrflrii.xyz, <container_id>,
```

**Initial Setup**:
1. Complete wizard on first access
2. Add Usenet server credentials
3. Get API key from Config → General → Security
4. Configure categories: `radarr`, `sonarr`, `lidarr`

**Arr Integration**:
- Settings → Download Clients → Add → SABnzbd
- Host: `sabnzbd` (container name)
- Port: `8080` (internal)
- API Key: (from Config → General → Security)
- Category: `radarr` / `sonarr` / `lidarr`
- **Remote Path Mapping**: NOT needed (same unified paths)

---

## Inter-Application Connections

### Prowlarr → *Arrs (Configured)
```
Prowlarr syncs indexers to:
├── Radarr (Full Sync, Movies categories)
├── Sonarr (Full Sync, TV categories)
└── Lidarr (Full Sync, Audio categories)
```

### Bazarr → *Arrs (Configured)
```
Bazarr connects to:
├── Radarr: radarr:7878 (container network)
└── Sonarr: sonarr:8989 (container network)
```

### Jellyseerr → Services (Needs Setup)
```
Jellyseerr needs manual setup:
├── Connect to Jellyfin (after Jellyfin wizard)
├── Add Radarr server
└── Add Sonarr server
```

---

## Storage Configuration

### Local Config
```
/opt/arr-stack/
├── jellyfin/config/
├── radarr/
├── sonarr/
├── lidarr/
├── prowlarr/
├── bazarr/
├── jellyseerr/
├── tdarr/
├── autobrr/
├── deluge/
└── sabnzbd/
```

### NFS Media Mount (Unified Paths)

> [!tip] Why Unified Paths?
> All services mount `/mnt/media` as `/data`. This enables **hardlinks** for instant imports and saves disk space.

```
Mount: /mnt/media (NFS from 192.168.20.31)
├── /Completed       # Download clients put finished files here
├── /Downloading     # Active downloads
├── /Incomplete      # Partial downloads
├── /Movies          # Radarr organizes movies here
├── /Series          # Sonarr organizes TV here
└── /Music           # Lidarr organizes music here
```

### Container Path Reference

| Service | Volume Mount | Root Folder | Downloads |
|---------|--------------|-------------|-----------|
| Radarr | `/mnt/media:/data` | `/data/Movies` | `/data/Completed` |
| Sonarr | `/mnt/media:/data` | `/data/Series` | `/data/Completed` |
| Lidarr | `/mnt/media:/data` | `/data/Music` | `/data/Completed` |
| Bazarr | `/mnt/media:/data` | `/data/Movies`, `/data/Series` | N/A |
| Deluge | `/mnt/media:/data` | N/A | `/data/Completed` |
| SABnzbd | `/mnt/media:/data` | N/A | `/data/Completed` |

---

## Manual Setup Required

### Radarr
1. Navigate to https://radarr.hrmsmrflrii.xyz
2. Settings → Media Management → Root Folder: `/data/Movies`
3. Settings → Download Clients → Add Deluge/SABnzbd (no remote path mapping needed)

### Sonarr
1. Navigate to https://sonarr.hrmsmrflrii.xyz
2. Settings → Media Management → Root Folder: `/data/Series`
3. Settings → Download Clients → Add Deluge/SABnzbd (no remote path mapping needed)

### Lidarr
1. Navigate to https://lidarr.hrmsmrflrii.xyz
2. Settings → Media Management → Root Folder: `/data/Music`
3. Settings → Download Clients → Add Deluge/SABnzbd (no remote path mapping needed)

### Jellyfin
1. Navigate to http://192.168.40.11:8096
2. Complete startup wizard
3. Add media libraries:
   - Movies: `/data/movies`
   - TV Shows: `/data/tvshows`

### Bazarr
1. Go to Settings → Languages
2. Create language profile

### Jellyseerr
1. Complete setup wizard at http://192.168.40.11:5056
2. Connect to Jellyfin
3. Add Radarr: `radarr:7878` with API key
4. Add Sonarr: `sonarr:8989` with API key

---

## Connection Diagram

```
                         ┌─────────────────┐
                         │    PROWLARR     │
                         │     :9696       │
                         │ (Indexer Mgr)   │
                         └────────┬────────┘
                                  │ Full Sync
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
             ┌──────────┐  ┌──────────┐  ┌──────────┐
             │  RADARR  │  │  SONARR  │  │  LIDARR  │
             │  :7878   │  │  :8989   │  │  :8686   │
             │ (Movies) │  │   (TV)   │  │ (Music)  │
             └────┬─────┘  └────┬─────┘  └──────────┘
                  │             │
                  └──────┬──────┘
                         ▼
                  ┌──────────┐
                  │  BAZARR  │
                  │  :6767   │
                  │(Subtitles)│
                  └──────────┘

             ┌──────────┐
             │ JELLYFIN │ ◄─── After setup, connects to:
             │  :8096   │
             │(Streaming)│      ┌──────────────┐
             └──────────┘      │  JELLYSEERR  │
                               │    :5056     │
                               │  (Requests)  │
                               └──────────────┘
```

---

## Management Commands

```bash
# SSH to host
ssh hermes-admin@192.168.40.11

# View logs
cd /opt/arr-stack && sudo docker compose logs -f

# Restart all services
cd /opt/arr-stack && sudo docker compose restart

# Update all containers
cd /opt/arr-stack && sudo docker compose pull && sudo docker compose up -d
```

---

## Related Documentation

- [[07 - Deployed Services]] - All services overview
- [[11 - Credentials]] - API keys and passwords
- [[03 - Storage Architecture]] - NFS media storage
- [[09 - Traefik Reverse Proxy]] - External access
