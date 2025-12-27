# Active Tasks

> Check this file BEFORE starting any work to avoid conflicts with other sessions.
> Update this file IMMEDIATELY when starting or completing work.

---

## Currently In Progress

*No active tasks*

---

## Recently Completed (Last 24 Hours)

## Grafana Iframe Fix for Glance Dashboard
**Completed**: 2025-12-27 ~17:40 UTC+8
**Session**: MacBook via Tailscale
**Changes**:
- Fixed Traefik services.yml structure (middlewares were incorrectly under serversTransports)
- Removed Authentik auth from Grafana route to allow iframe embedding
- Updated Grafana ROOT_URL to HTTPS (grafana.hrmsmrflrii.xyz)
- Changed Glance iframe URLs from HTTP to HTTPS to fix mixed content blocking
- Fixed empty Host() rule for open-notebook route (was matching all traffic)
**Root Cause**: YAML structure error in Traefik config - middlewares section was under serversTransports instead of http.middlewares
**Files Modified**:
- `/opt/traefik/config/dynamic/services.yml` (Traefik VM @ 192.168.40.20)
- `/opt/monitoring/docker-compose.yml` (Core Utilities VM @ 192.168.40.13)

## Grafana Dashboards & API Fixes
**Completed**: 2025-12-27 ~17:00 UTC+8
**Session**: MacBook via Tailscale
**Changes**:
- Imported Proxmox Cluster Overview dashboard to Grafana (UID: `proxmox-compute`)
- All 4 Grafana dashboards now working: containers-modern, omada-network, proxmox-compute, synology-nas-modern
- Verified all APIs working: Media Stats (5054), Reddit (5053), NBA Stats (5060)
- Fixed broken RSS feeds in Glance (XDA and Google News)
- All 10 Prometheus targets UP: cadvisor, cadvisor-media, docker-stats-media, omada, prometheus, proxmox (3), synology, traefik
**Grafana Dashboards**:
| Dashboard | UID | URL |
|-----------|-----|-----|
| Container Monitoring | containers-modern | /d/containers-modern/container-monitoring |
| Omada Network | omada-network | /d/omada-network/omada-network-overview |
| Proxmox Cluster | proxmox-compute | /d/proxmox-compute/proxmox-cluster-overview |
| Synology NAS | synology-nas-modern | /d/synology-nas-modern/synology-nas-storage |
**API Verification**:
| API | URL | Status |
|-----|-----|--------|
| Media Stats | localhost:5054/api/stats | Working |
| Reddit | localhost:5053/api/feed | Working |
| NBA Stats | localhost:5060/games | Working |
| Injuries | localhost:5060/injuries | Working |
| News | localhost:5060/news | Working |

## Discord Bots Migration to LXC
**Completed**: 2025-12-27 ~21:00 UTC+8
**Session**: MacBook via Tailscale
**Changes**:
- Created LXC 201 (`docker-lxc-bots`) on node01 at 192.168.40.14
- Deployed Argus bot (container updates, Watchtower webhooks)
- Deployed Chronos bot (GitLab project management)
- Redeployed Mnemosyne bot on docker-media (192.168.40.11)
- Created comprehensive deployment tutorial: `docs/DISCORD_BOT_DEPLOYMENT_TUTORIAL.md`
- Updated DISCORD_BOTS.md with new architecture and IPs
- Updated context.md with new LXC and bot locations
**LXC 201 Configuration**:
- 2GB RAM, 2 vCPU, 8GB disk
- Features: nesting=1, fuse=1, keyctl=1
- Docker with `--security-opt apparmor=unconfined`
**Bots Deployed**:
| Bot | Host | Port | Channel |
|-----|------|------|---------|
| Argus | LXC 201 (192.168.40.14) | 5050 | #container-updates |
| Chronos | LXC 201 (192.168.40.14) | - | #project-management |
| Mnemosyne | docker-media (192.168.40.11) | - | #media-downloads |
**Files Created**:
- docs/DISCORD_BOT_DEPLOYMENT_TUTORIAL.md (complete tutorial)
- /opt/argus-bot/* (on LXC 201)
- /opt/chronos-bot/* (on LXC 201)

## Full Monitoring Stack Deployment + Glance Fixes
**Completed**: 2025-12-27 ~10:00 UTC+8
**Session**: MacBook via Tailscale
**Changes**:
- Fixed Prometheus with all required exporters (synology, omada, traefik, docker-stats-media, cadvisor, proxmox)
- Fixed Traefik metrics port (8082→8083)
- Deployed PVE Exporter with new token (terraform-deployment-user@pve!tf01)
- Deployed Life Progress API on core-utilities VM (192.168.40.13:5051)
- Deployed n8n workflow automation (192.168.40.13:5678)
- Deployed Jaeger tracing (192.168.40.13:16686)
- Imported 3 Grafana dashboards: synology-nas-modern, omada-network, containers-modern
- Updated Glance iframes to use direct Grafana IP (http://192.168.40.13:3030)
- Updated Traefik routes to point to new VM (192.168.40.10 -> 192.168.40.13)
- Ran initial Speedtest (498 Mbps down, 288 Mbps up)
**Current Running Services on 192.168.40.13**:
- Prometheus (9090), Grafana (3030), Uptime Kuma (3001)
- Speedtest Tracker (3000), cAdvisor (8081)
- SNMP Exporter (9116), PVE Exporter (9221), Life Progress API (5051)
- n8n (5678), Jaeger (16686)
**Prometheus Targets Status - ALL UP**:
- cadvisor, cadvisor-media, docker-stats-media, omada, prometheus, synology, traefik, proxmox (3/3)
**Still Not Deployed**:
- Paperless (document management)
- Lagident, Karakeep, Wizarr, Tracearr (will show as down in monitors)

## New Core Utilities VM + Glance Infrastructure Rebuild
**Completed**: 2025-12-27 ~20:30
**Session**: MacBook via Tailscale
**Changes**:
- Replaced broken docker-utilities VM (192.168.40.10) with new docker-vm-core-utilities (192.168.40.13)
- New VM on node01 with 4 cores, 12GB RAM, 40GB disk
- Deployed core monitoring stack: Grafana, Prometheus, Uptime Kuma, Speedtest, cAdvisor
- Updated Glance config to point to new IP (192.168.40.13)
- Updated Traefik routes for monitoring services
- DNS set to OPNsense (192.168.91.30)
**Current Infrastructure**:
- LXC 200 (192.168.40.12): Glance + Media Stats API + Reddit Manager + NBA Stats API
- VM 107 (192.168.40.13): Core monitoring stack (Grafana, Prometheus, Uptime Kuma, Speedtest)
**Pending Deployments** (on 192.168.40.13):
- n8n, Jaeger, Paperless, Lagident, Karakeep, Wizarr, Tracearr
- Reactive Resume, Bentopdf, Edgeshark, Open Notebook
- Discord bots (Argus, Chronos)
- Prometheus exporters (SNMP, PVE, OPNsense, Omada)

## Glance Dashboard LXC Migration
**Completed**: 2025-12-27 ~19:30
**Session**: MacBook via Tailscale
**Changes**:
- Created LXC container 200 (`docker-lxc-glance`) on node01 at 192.168.40.12
- Migrated Glance + 3 custom APIs from docker-utilities VM to LXC
- Worked around AppArmor issues with `--security-opt apparmor=unconfined`
- Used pre-built Python images with volume mounts (Docker builds fail in LXC)
- Added Sports page with localhost:5060 references
- Updated Traefik routing from 192.168.40.10 to 192.168.40.12
**Services Migrated**:
- Glance dashboard (port 8080)
- Media Stats API (port 5054)
- Reddit Manager (port 5053)
- NBA Stats API (port 5060)
**Files on LXC**:
- /opt/glance/config/glance.yml
- /opt/media-stats-api/media-stats-api.py
- /opt/reddit-manager/reddit-manager.py
- /opt/nba-stats-api/nba-stats-api.py

## Discord Bot Fixes
**Completed**: 2025-12-27 ~10:30
**Session**: MacBook via Tailscale
**Changes**:
- Fixed Mnemosyne bot: Added missing API keys (RADARR_API_KEY, SONARR_API_KEY were empty)
- Fixed Chronos bot: Changed GITLAB_PROJECT_ID from `homelab/tasks` to `2` (Homelab Project)
- Added GitLab hosts entry to docker-utilities (`192.168.40.20 gitlab.hrmsmrflrii.xyz`)
**Files Modified**:
- `/opt/mnemosyne-bot/docker-compose.yml` (docker-media)
- `/opt/chronos-bot/docker-compose.yml` (docker-utilities)
- `ansible-playbooks/project-management/deploy-chronos-bot.yml` (local)
- `docs/DISCORD_BOTS.md` (local)

## Discord Bot Reorganization
**Completed**: 2025-12-26 ~22:00
**Session**: MacBook via Tailscale
**Changes**:
- Created Argus bot for container updates (`#container-updates`)
  - Watchtower webhook integration (port 5050)
  - Button-based update approvals
  - Commands: `/check`, `/update`, `/updateall`, `/containers`, `/status`
- Created Chronos bot for project management (`#project-management`)
  - GitLab Boards integration
  - Commands: `/todo`, `/tasks`, `/done`, `/close`, `/board`, `/quick`
- Enhanced Mnemosyne for media downloads (`#media-downloads`)
  - Added: `/availablemovies`, `/availableseries`, `/showlist`
  - Progress notifications at 50%, 80%, 100%
- Fixed channel restriction checking with debug logging
**Files Created**:
- `ansible-playbooks/container-updates/argus-bot.py`
- `ansible-playbooks/container-updates/deploy-argus-bot.yml`
- `ansible-playbooks/project-management/chronos-bot.py`
- `ansible-playbooks/project-management/deploy-chronos-bot.yml`
- `docs/DISCORD_BOTS.md`

## Glance Web & Reddit Page Enhancement
**Completed**: 2025-12-26 ~16:30
**Session**: MacBook via Tailscale
**Changes**:
- Revamped Web page as comprehensive tech news aggregator with 9 collapsible sections
- Added Tech YouTube widget with 7 channels (MKBHD, LTT, Mrwhosetheboss, Dave2D, Austin Evans, JerryRigEverything, Fireship)
- Expanded news sources: The Verge, XDA, TechCrunch, Ars Technica, AWS Blog
- Added categories: Android/Mobile, AI/ML, Cloud, Big Tech, Gaming, PC Builds, Travel
- Updated Reddit Manager with 16 subreddits (added datahoarder, technology, programming, webdev, sysadmin, netsec, gaming, pcmasterrace, buildapc, mechanicalkeyboards)
- Changed Reddit view to "grouped" mode with thumbnails
- Added native Reddit widgets for r/technology, r/programming, r/sysadmin
**Files Created**:
- temp-glance-web-reddit-update.py
- ansible-playbooks/glance/deploy-web-reddit-update.yml
**Files Modified on Server**:
- /opt/glance/config/glance.yml
- /opt/reddit-manager/data/subreddits.json
- /opt/reddit-manager/data/settings.json

## NBA Stats API + Yahoo Fantasy Integration
**Completed**: 2025-12-26 ~14:00
**Session**: MacBook via Tailscale
**Changes**:
- Deployed NBA Stats API to docker-utilities:5060 (fixed port conflict from 5055)
- Fixed ESPN standings URL (v2 endpoint)
- Implemented Yahoo Fantasy OAuth headless flow
- Fixed Yahoo Fantasy API (game ID 466, league key `466.l.12095`)
- Added `/fantasy/matchups` endpoint for weekly matchups
- Added `/fantasy/recommendations` endpoint for player pickup analysis
- Added NBA team logos to games and standings widgets (ESPN CDN)
- Added Sports tab to Glance (8 pages now)
- Created docs/DOCKER_SERVICES.md - comprehensive Docker services inventory
**API Endpoints**:
- `http://192.168.40.10:5060/games` - NBA games with logos
- `http://192.168.40.10:5060/standings` - NBA standings with logos
- `http://192.168.40.10:5060/fantasy` - Fantasy league standings
- `http://192.168.40.10:5060/fantasy/matchups` - Current week matchups
- `http://192.168.40.10:5060/fantasy/recommendations` - Player pickup recommendations
**Files on Server**:
- /opt/nba-stats-api/nba-stats-api.py
- /opt/nba-stats-api/yahoo_fantasy.py
- /opt/nba-stats-api/fantasy_recommendations.py
- /opt/nba-stats-api/data/yahoo_token.json
- /opt/glance/config/glance.yml (Sports tab)

## Synology NAS Storage Dashboard - Protected
**Completed**: 2025-12-25 20:45
**Changes**:
- Created modern Synology NAS dashboard for Storage page
- 6 disk health stat tiles (4 HDDs green, 2 M.2 SSDs purple)
- Summary stats: Uptime, Total/Used Storage, CPU %, Memory %
- Disk temperatures bargauge with gradient coloring
- CPU and Memory time series charts
- Storage Consumption Over Time (7-day window)
- Fixed memory unit display (changed from `deckbytes` to `kbytes`)
- Iframe height: 1350px
- **PROTECTED** - Do not modify without explicit user permission
**Files Modified**:
- temp-synology-nas-dashboard.json
- ansible-playbooks/monitoring/deploy-synology-nas-dashboard.yml
**Documentation Updated**:
- .claude/context.md, .claude/conventions.md, docs/GLANCE.md, claude.md, CHANGELOG.md, session-log.md
- GitHub Wiki: Glance-Dashboard.md
- Obsidian: 23 - Glance Dashboard.md

## Container Status Dashboard - Protected
**Completed**: 2025-12-25 16:30
**Changes**:
- Fixed "No data" and "Too many points" issues
- Added Container Issues table for stopped/restarted containers
- Deployed version 6 of dashboard to Grafana
- Iframe height: 1250px
- **PROTECTED** - Do not modify without explicit user permission
**Files Modified**:
- temp-container-status-fixed.json
- ansible-playbooks/monitoring/deploy-container-status-dashboard.yml
**Documentation Updated**:
- .claude/context.md, .claude/conventions.md, docs/GLANCE.md, claude.md, CHANGELOG.md

## Tailscale Documentation + CLAUDE.md Restructure
**Completed**: 2025-12-25 14:45
**Changes**:
- Added Tailscale remote access to all docs (CLAUDE.md, NETWORKING.md, wiki, Obsidian)
- Created `.claude/` directory structure for multi-session workflow
- Split CLAUDE.md into focused context files
**Files Modified**:
- claude.md (refactored)
- docs/NETWORKING.md
- Proxmox-TerraformDeployments.wiki/Network-Architecture.md
- Obsidian: 01 - Network Architecture.md
- .claude/context.md (new)
- .claude/active-tasks.md (new)
- .claude/session-log.md (new)
- .claude/conventions.md (new)

---

## Interrupted Tasks (Need Resumption)

<!--
If a task was interrupted (tokens ran out, user stopped, etc.), move it here:

## [Task Name]
**Interrupted**: YYYY-MM-DD HH:MM
**Reason**: Tokens exhausted / User stopped / Error
**Completed Steps**:
1. Step that was done
2. Another step done
**Remaining Steps**:
1. What still needs to be done
2. Another pending step
**Resume Instructions**: Specific guidance for picking up this task
**Context**: Any important state or decisions made
-->

*No interrupted tasks*

---

## Notes for Next Session

<!--
Leave notes here for future sessions:
- Pending decisions
- Things to watch out for
- User preferences discovered
-->

- User prefers documentation updates to happen incrementally, not at the end
- Multiple Claude instances may run in parallel - always check active-tasks first
- Glance Home, Media, Compute, Storage, Network, and Sports pages are protected - don't modify without permission
- Synology NAS Storage dashboard is protected - UID: `synology-nas-modern`, height: 1350px
- Yahoo Fantasy OAuth token stored at `/opt/nba-stats-api/data/yahoo_token.json` - auto-refreshes
- **NEW**: Glance now runs on LXC container 200 (192.168.40.12) instead of docker-utilities
- **NEW**: Discord bots (Argus, Chronos) now run on LXC 201 (192.168.40.14)
- **NEW**: Mnemosyne stays on docker-media (192.168.40.11) - needs localhost access to Radarr/Sonarr
- **NEW**: Created docs/DISCORD_BOT_DEPLOYMENT_TUTORIAL.md - comprehensive tutorial on Discord bot deployment
- docker-utilities VM (192.168.40.10) has been decommissioned
- Docker in LXC requires `--security-opt apparmor=unconfined` flag
- Docker builds fail in LXC - use pre-built images with volume mounts instead
- **NEW**: Grafana has no Authentik protection (allows anonymous read-only access for iframe embedding)
- **NEW**: Grafana uses HTTPS via grafana.hrmsmrflrii.xyz for iframe embedding in Glance
