# Watchtower - Interactive Container Updates

> **Internal Documentation** - Contains Discord bot configuration and credentials.

Related: [[00 - Homelab Index]] | [[07 - Deployed Services]] | [[12 - Troubleshooting]]

---

## Overview

Watchtower monitors all Docker containers for updates and sends interactive Discord notifications. Updates only proceed after user approval via emoji reactions.

| Setting | Value |
|---------|-------|
| Check Schedule | Daily at 3:00 AM (America/New_York) |
| Mode | Monitor-only (requires approval) |
| Notifications | Discord bot with reaction-based approval |
| Auto-cleanup | Old images removed after update |
| Webhook Endpoint | http://192.168.40.13:5050/webhook |

---

## Architecture

```
Docker Hosts (Watchtower)          Update Manager (192.168.40.13:5050)
┌─────────────────────┐            ┌─────────────────────────────────┐
│ .40.10 (utilities)  │            │  Flask Webhook + Discord.py    │
│ .40.11 (media)      │───────────►│                                 │
│ .40.20 (traefik)    │  Shoutrrr  │  Receives webhooks              │
│ .40.21 (authentik)  │  Webhook   │  Sends Discord notifications    │
│ .40.22 (immich)     │            │  Executes updates via SSH       │
│ .40.23 (gitlab)     │            └─────────────────────────────────┘
└─────────────────────┘                          │
                                                 ▼
                                    ┌─────────────────────────────────┐
                                    │      Discord Channel            │
                                    │                                 │
                                    │  "Hey Hermes! New update for    │
                                    │   sonarr..."                    │
                                    │                                 │
                                    │  👍 → Update    👎 → Skip       │
                                    └─────────────────────────────────┘
```

---

## Discord Bot Commands

| Command | Description |
|---------|-------------|
| `check versions` | Scan all services for available updates |
| `update all` | Update all services with pending updates |
| `update <service>` | Update specific service (e.g., `update sonarr`) |
| `help` | Show available commands |

### Notification Format

**Update Available:**
```
👋 Hey Hermes!

🆕 There is a new update available for **sonarr**
📦 Current: `current`
🚀 New: `lscr.io/linuxserver/sonarr (sha256:abc1...)`

React with 👍 to update or 👎 to skip!
```

**After Approval:**
```
🔄 Updating **sonarr**... Please wait, Master Hermes!
✅ **sonarr** has been updated to **lscr.io/linuxserver/sonarr:latest**, Master Hermes! 🎉
```

---

## Components

### Watchtower (All 6 Docker Hosts)

| Host | IP | Config |
|------|----|--------|
| docker-vm-core-utilities01 | 192.168.40.13 | `/opt/watchtower/docker-compose.yml` |
| docker-vm-media01 | 192.168.40.11 | `/opt/watchtower/docker-compose.yml` |
| traefik-vm01 | 192.168.40.20 | `/opt/watchtower/docker-compose.yml` |
| authentik-vm01 | 192.168.40.21 | `/opt/watchtower/docker-compose.yml` |
| immich-vm01 | 192.168.40.22 | `/opt/watchtower/docker-compose.yml` |
| gitlab-vm01 | 192.168.40.23 | `/opt/watchtower/docker-compose.yml` |

### Update Manager (192.168.40.13)

| Component | Location |
|-----------|----------|
| Service | `/opt/update-manager/` |
| Python App | `/opt/update-manager/update_manager.py` |
| Docker Compose | `/opt/update-manager/docker-compose.yml` |
| Credentials | `/opt/update-manager/.env` |

---

## Credentials

See [[11 - Credentials]] for Discord bot token and channel ID.

| Credential | Location |
|------------|----------|
| Discord Bot Token | `/opt/update-manager/.env` |
| Discord Channel ID | `/opt/update-manager/.env` |

---

## Container to Host Mapping

The Update Manager knows which container runs on which host:

**Utilities (192.168.40.13):**
- uptime-kuma, prometheus, grafana, glance, n8n, paperless-ngx, openspeedtest

**Media (192.168.40.11):**
- jellyfin, radarr, sonarr, lidarr, prowlarr, bazarr, overseerr, jellyseerr, tdarr, autobrr

**Infrastructure:**
- traefik (192.168.40.20)
- authentik-server, authentik-worker (192.168.40.21)
- immich-server, immich-ml (192.168.40.22)
- gitlab (192.168.40.23)

---

## Configuration

### Watchtower (Monitor-Only Mode)

```yaml
name: watchtower

services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    environment:
      DOCKER_API_VERSION: "1.44"
      WATCHTOWER_SCHEDULE: "0 0 3 * * *"
      WATCHTOWER_CLEANUP: "true"
      WATCHTOWER_INCLUDE_STOPPED: "false"
      WATCHTOWER_MONITOR_ONLY: "true"
      WATCHTOWER_NOTIFICATIONS: "shoutrrr"
      WATCHTOWER_NOTIFICATION_URL: "generic+http://192.168.40.13:5050/webhook"
      TZ: "America/New_York"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

**Key Settings:**
- `WATCHTOWER_MONITOR_ONLY: "true"` - Does NOT auto-update
- `generic+http://` - MUST use this format (not `generic://`)

### Update Manager

```yaml
name: update-manager

services:
  update-manager:
    build: .
    container_name: update-manager
    restart: unless-stopped
    ports:
      - "5050:5000"
    environment:
      - DISCORD_TOKEN=${DISCORD_TOKEN}
      - DISCORD_CHANNEL_ID=${DISCORD_CHANNEL_ID}
      - SSH_KEY_PATH=/root/.ssh/homelab_ed25519
      - TZ=America/New_York
    volumes:
      - /home/hermes-admin/.ssh:/root/.ssh:ro
```

---

## Common Commands

### Check Status

```bash
# Update Manager
ssh hermes-admin@192.168.40.13 "docker ps --filter name=update-manager"

# Watchtower on all hosts
for ip in 192.168.40.13 192.168.40.11 192.168.40.20 192.168.40.21 192.168.40.22 192.168.40.23; do
  echo -n "$ip: "
  ssh hermes-admin@$ip "docker ps --filter name=watchtower --format '{{.Status}}'"
done
```

### Trigger Manual Check

```bash
ssh hermes-admin@192.168.40.11 "docker exec watchtower /watchtower --run-once"
```

### View Logs

```bash
# Update Manager
ssh hermes-admin@192.168.40.13 "docker logs update-manager --tail 50"

# Watchtower
ssh hermes-admin@192.168.40.11 "docker logs watchtower --tail 50"
```

### Rebuild After Code Changes

```bash
ssh hermes-admin@192.168.40.13 "cd /opt/update-manager && sudo docker compose down && sudo docker compose build --no-cache && sudo docker compose up -d"
```

### Test Webhook

```bash
curl -X POST -d 'Found new lscr.io/linuxserver/sonarr image (sha256:test)' http://192.168.40.13:5050/webhook
```

---

## Adding New Containers

When deploying a new service, add it to the Update Manager:

1. Edit `/opt/update-manager/update_manager.py` on 192.168.40.13
2. Add to `CONTAINER_HOSTS` dictionary:
   ```python
   CONTAINER_HOSTS = {
       "new-service": "192.168.40.XX",
       # ... existing containers
   }
   ```
3. Rebuild:
   ```bash
   cd /opt/update-manager && sudo docker compose build --no-cache && sudo docker compose up -d
   ```

---

## Excluding Containers

Add this label to exclude a container from updates:

```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=false"
```

---

## Troubleshooting

See [[12 - Troubleshooting]] for detailed issue resolutions.

### Quick Fixes

**Bot not responding:**
```bash
ssh hermes-admin@192.168.40.13 "docker logs update-manager 2>&1 | grep 'logged in'"
```

**Update fails - "Could not find compose directory":**
```bash
# Copy SSH key and restart
scp ~/.ssh/homelab_ed25519 hermes-admin@192.168.40.13:/home/hermes-admin/.ssh/
ssh hermes-admin@192.168.40.13 "cd /opt/update-manager && sudo docker compose restart"
```

**Webhook TLS error:**
- Ensure webhook URL uses `generic+http://` (not `generic://`)

---

## Related Documentation

- [[07 - Deployed Services]] - All services
- [[12 - Troubleshooting]] - Issue resolutions
- [[15 - New Service Onboarding Guide]] - Adding new services
- [[11 - Credentials]] - Discord bot credentials
