# Discord Bots

#homelab #discord #automation #bots #sentinel

This document describes the Discord bot infrastructure for homelab automation and notifications.

## Overview

The homelab uses a single consolidated Discord bot called **Sentinel** that replaces the previous 4 separate bots (Argus, Chronos, Mnemosyne, Athena).

| Bot | Host | Purpose |
|-----|------|---------|
| **Sentinel** | docker-vm-core-utilities01 (192.168.40.13) | Unified homelab management |

---

## Sentinel - Unified Homelab Bot

**Location**: `/opt/sentinel-bot/`
**Container**: `sentinel-bot`
**Webhook Port**: 5050
**Status**: Deployed January 2026

### Architecture

```
Discord Server
     │
     ▼
Sentinel Bot (discord.py 2.3+)
├── Core
│   ├── bot.py           → Main SentinelBot class
│   ├── database.py      → Async SQLite (aiosqlite)
│   ├── channel_router.py → Notification routing
│   └── progress.py      → Progress bar utilities
│
├── Cogs (8 modules)
│   ├── homelab.py       → Proxmox cluster management
│   ├── updates.py       → Container updates + reaction approvals
│   ├── media.py         → Download monitoring + Jellyseerr
│   ├── gitlab.py        → GitLab issue management
│   ├── tasks.py         → Claude task queue
│   ├── onboarding.py    → Service verification
│   ├── scheduler.py     → Daily reports (7pm, 9am)
│   └── power.py         → Cluster power management (WoL, shutdown)
│
├── Webhooks (Quart on port 5050)
│   ├── /webhook/watchtower  → Container update notifications
│   ├── /webhook/jellyseerr  → Media request notifications
│   └── /api/tasks           → Claude task queue REST API
│
└── Services (API integrations)
    ├── proxmox.py      → Prometheus + SSH
    ├── radarr.py       → Radarr v3 API
    ├── sonarr.py       → Sonarr v3 API
    └── jellyseerr.py   → Jellyseerr API
```

### Channel Routing

| Cog | Channel | Purpose |
|-----|---------|---------|
| **Homelab** | `#homelab-infrastructure` | Proxmox status, VM/LXC/node management |
| **Updates** | `#container-updates` | Container updates with reaction approvals |
| **Media** | `#media-downloads` | Download progress, failed download alerts, library stats |
| **GitLab** | `#project-management` | Issue creation and tracking |
| **Tasks** | `#claude-tasks` | Claude task queue management |
| **Onboarding** | `#new-service-onboarding-workflow` | Service verification checks |
| **Scheduler** | Various | Daily reports, download monitoring |
| **Power** | `#announcements` | Cluster power management (shutdown/startup) |

### Commands

#### Homelab (`#homelab-infrastructure`)

| Command | Description |
|---------|-------------|
| `/help` | Show all Sentinel commands in a formatted embed |
| `/insight` | Health check: memory usage, container errors, storage, failed downloads |
| `/homelab status` | Cluster overview with resource bars |
| `/homelab uptime` | Uptime for all nodes/VMs/LXCs |
| `/node <name> status` | Detailed status for a node |
| `/node <name> vms` | List VMs on a node |
| `/node <name> lxc` | List LXC containers on a node |
| `/node <name> restart` | Restart Proxmox node (with confirmation) |
| `/vm <id> status` | Get VM status |
| `/vm <id> start/stop/restart` | Control a VM |
| `/lxc <id> status` | Get LXC container status |
| `/lxc <id> start/stop/restart` | Control an LXC container |

#### Updates (`#container-updates`)

| Command | Description |
|---------|-------------|
| `/check` | Scan all containers for updates |
| `/update <container>` | Update specific container |
| `/updateall` | Update all with pending updates |
| `/updateall-except <list>` | Update all except specified |
| `/containers` | List monitored containers |

#### Media (`#media-downloads`)

| Command | Description |
|---------|-------------|
| `/downloads` | Current download queue with visual progress bars |
| `/download <title>` | Search & add via Jellyseerr |
| `/search <query>` | Search without downloading |
| `/library movies` | Movie library statistics |
| `/library shows` | TV library statistics |
| `/recent` | Recently added media |

**`/downloads` Output Format** (Updated January 2026):
```
📥 Download Queue

🎬 Movies (2)
`[████████░░]`  80.5% | Interstellar.2014.2160p.UHD
`[██░░░░░░░░]`  20.0% | The.Matrix.1999.4K

📺 TV Shows (8)
`[██████████]` 100.0% | House.of.the.Dragon.S02E05
`[█████░░░░░]`  50.0% | The.Sandman.S02E01
```

#### GitLab (`#project-management`)

| Command | Description |
|---------|-------------|
| `/todo <description>` | Create GitLab issue |
| `/issues` | List open issues |
| `/close <id>` | Close an issue |
| `/quick <tasks>` | Bulk create (semicolon-separated) |
| `/project` | Show project info |

#### Tasks (`#claude-tasks`)

| Command | Description |
|---------|-------------|
| `/task <description>` | Submit new task to queue |
| `/queue` | View pending tasks |
| `/status` | Claude instance status |
| `/done` | Completed tasks |
| `/cancel <id>` | Cancel pending task |
| `/taskstats` | Queue statistics |

#### Onboarding (`#new-service-onboarding-workflow`)

| Command | Description |
|---------|-------------|
| `/onboard <service>` | Check single service config |
| `/onboard-all` | Check all services (table) |
| `/onboard-services` | List discovered services |

#### Power (`#announcements`)

| Command | Description |
|---------|-------------|
| `/shutdownall` | Shutdown ALL VMs, LXCs, and Proxmox nodes |
| `/shutdown-nodns` | Shutdown all except Pi-hole (LXC 202) and node01 |
| `/startall` | Wake nodes via WoL, start all LXCs and VMs |

> **Confirmation Required**: All power commands require ⚠️ reaction to confirm (60-second timeout). The shutdown order is VMs → LXCs → Nodes for safety.

**Wake-on-LAN Configuration:**

| Node | MAC Address |
|------|-------------|
| node01 | `38:05:25:32:82:76` |
| node02 | `84:47:09:4d:7a:ca` |
| node03 | `d8:43:ae:a8:4c:a7` |

### Webhook Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/webhook/watchtower` | POST | Container update notifications |
| `/webhook/jellyseerr` | POST | Media request notifications |
| `/api/tasks` | GET/POST | Claude task queue |
| `/api/tasks/<id>/claim` | POST | Claim task for processing |
| `/api/tasks/<id>/complete` | POST | Mark task complete |

### Update Approval Flow

Sentinel uses reaction-based approvals for container updates:

1. Watchtower detects updates → posts embed to `#container-updates`
2. User reacts with :thumbsup: to approve ALL updates
3. Number emojis (1️⃣, 2️⃣, etc.) for individual updates
4. Bot executes approved updates via SSH
5. Completion notification with status

### Database Schema

```sql
-- Claude task queue
CREATE TABLE tasks (
    id INTEGER PRIMARY KEY,
    description TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    priority TEXT DEFAULT 'medium',
    submitted_by TEXT,
    instance_id TEXT,
    instance_name TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Download progress tracking
CREATE TABLE download_tracking (
    id TEXT PRIMARY KEY,
    media_type TEXT,
    title TEXT,
    notified_milestones TEXT DEFAULT '[]',
    completed_at TIMESTAMP
);

-- Update history
CREATE TABLE update_history (
    id INTEGER PRIMARY KEY,
    container_name TEXT,
    host_ip TEXT,
    update_status TEXT,
    updated_by TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Scheduled Tasks

| Task | Time | Channel |
|------|------|---------|
| Update Availability Report | 7:00 PM daily | `#container-updates` |
| Onboarding Status Report | 9:00 AM daily | `#new-service-onboarding-workflow` |
| Download Completion Check | Every 60 seconds | `#media-downloads` |
| Failed Download Check | Every 5 minutes | `#media-downloads` |
| Stale Task Cleanup | Every 30 minutes | (internal) |

> **Note** (January 2026): Download notifications now only trigger at 100% completion to reduce spam. Uses in-memory cache instead of database tracking.

### Failed Download Notifications

The bot checks Radarr/Sonarr queues every 5 minutes for failed downloads:
- Sends notification with error details to `#media-downloads`
- Includes :wastebasket: reaction to remove from queue
- One-click removal via API when user reacts

### Environment Variables

```bash
# Discord
DISCORD_TOKEN=your_bot_token
DISCORD_GUILD_ID=your_guild_id

# Channels
CHANNEL_CONTAINER_UPDATES=container-updates
CHANNEL_MEDIA_DOWNLOADS=media-downloads
CHANNEL_ONBOARDING=new-service-onboarding-workflow
CHANNEL_ARGUS=homelab-infrastructure
CHANNEL_PROJECT_MANAGEMENT=project-management
CHANNEL_CLAUDE_TASKS=claude-tasks

# APIs
RADARR_URL=http://192.168.40.11:7878
RADARR_API_KEY=your_key
SONARR_URL=http://192.168.40.11:8989
SONARR_API_KEY=your_key
JELLYSEERR_URL=http://192.168.40.11:5056
GITLAB_URL=https://gitlab.hrmsmrflrii.xyz
GITLAB_TOKEN=your_token
GITLAB_PROJECT_ID=2
PROMETHEUS_URL=http://192.168.40.13:9090

# Webhook
WEBHOOK_PORT=5050
```

### Management

```bash
# View bot logs
ssh hermes-admin@192.168.40.13 "docker logs sentinel-bot --tail 50"

# Restart bot
ssh hermes-admin@192.168.40.13 "cd /opt/sentinel-bot && sudo docker compose restart"

# Rebuild after code changes
ssh hermes-admin@192.168.40.13 "cd /opt/sentinel-bot && sudo docker compose build --no-cache && sudo docker compose up -d"

# Check webhook health
curl http://192.168.40.13:5050/health

# View database
ssh hermes-admin@192.168.40.13 "docker exec sentinel-bot sqlite3 /app/data/sentinel.db '.tables'"
```

### Deployment

```bash
# Deploy via Ansible
cd ~/ansible
ansible-playbook sentinel-bot/deploy-sentinel-bot.yml
```

---

## File Structure

```
/opt/sentinel-bot/
├── sentinel.py              # Entry point
├── config.py                # Configuration loader
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
├── .env                     # Environment variables
│
├── core/
│   ├── __init__.py
│   ├── bot.py               # SentinelBot class
│   ├── database.py          # Async SQLite wrapper
│   ├── channel_router.py    # Notification routing
│   ├── progress.py          # Progress bar utilities
│   └── ssh_manager.py       # Async SSH (asyncssh)
│
├── cogs/
│   ├── __init__.py
│   ├── homelab.py
│   ├── updates.py
│   ├── media.py
│   ├── gitlab.py
│   ├── tasks.py
│   ├── onboarding.py
│   ├── scheduler.py
│   └── power.py
│
├── webhooks/
│   ├── __init__.py
│   └── server.py            # Quart async HTTP
│
└── data/
    └── sentinel.db          # SQLite database
```

---

## Migration from Legacy Bots

Sentinel consolidates these previous bots:

| Old Bot | Replaced By | Migration Notes |
|---------|-------------|-----------------|
| Argus | `updates.py` cog | Same commands, reaction approvals added |
| Mnemosyne | `media.py` cog | Download tracking with milestone dedup |
| Chronos | `gitlab.py` cog | Same GitLab integration |
| Athena | `tasks.py` cog | Claude task queue preserved |

The old bots have been stopped and removed:
- Argus: Was on docker-vm-core-utilities01 → Now Sentinel
- Mnemosyne: Was on docker-media → **STOPPED** (use Sentinel on utils01)
- Chronos: Was on docker-vm-core-utilities01 → Now Sentinel
- Athena: Was on docker-lxc-bots → Now Sentinel

---

## Troubleshooting

### Bot not responding
1. Check container is running: `docker ps | grep sentinel`
2. Check logs: `docker logs sentinel-bot --tail 100`
3. Verify correct channel names in `.env`

### Commands not syncing
1. Discord slash commands take up to 1 hour to propagate
2. Restart bot to force sync
3. Check logs for "Slash commands synced" message

### Token issues
1. Regenerate token in Discord Developer Portal
2. Update `.env` with new token
3. Recreate container: `docker compose down && docker compose up -d`

### Download notifications repeating
**Fixed January 2026**: The scheduler now uses in-memory cache and only notifies on 100% completion.

If issues persist:
1. Restart the bot to clear the in-memory cache:
   ```bash
   cd /opt/sentinel-bot && sudo docker compose restart
   ```
2. The `_download_cache` is cleared when bot restarts, preventing duplicate notifications.

### Webhook not receiving updates
1. Verify Watchtower has correct URL: `http://192.168.40.13:5050/webhook/watchtower`
2. Test webhook: `curl http://192.168.40.13:5050/health`
3. Check firewall allows port 5050

---

## Related Documents

- [[07 - Deployed Services|Deployed Services]]
- [[19 - Watchtower Updates|Watchtower Updates]]
- [[20 - GitLab CI-CD Automation|GitLab CI/CD]]
- [[08 - Arr Media Stack|Arr Media Stack]]
- [[22 - Service Onboarding Workflow|Service Onboarding]]

---

*Created: December 26, 2025*
*Updated: January 13, 2026*
*Bot: Sentinel (consolidated)*
