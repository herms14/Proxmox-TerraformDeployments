# Athena Bot Tutorial

> Setting up Athena task queue bot with Claude Code integration for automated homelab management.

Related: [[24 - Discord Bots]] | [[27 - Discord Bot Deployment Tutorial]] | [[11 - Credentials]]

---

## Overview

Athena is a Discord bot that provides a task queue API for Claude Code integration, enabling automated homelab management through Discord.

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Claude Code    │────►│   Athena API    │────►│  Discord Bot    │
│  (MCP Client)   │     │  (Port 5051)    │     │  (#claude-tasks)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │
                              ▼
                        ┌─────────────────┐
                        │  Task Queue     │
                        │  (SQLite)       │
                        └─────────────────┘
```

### Features

- **Task Queue** - Queue tasks for later review
- **Discord Integration** - Post tasks to #claude-tasks channel
- **API Endpoint** - REST API for Claude Code MCP integration
- **Task Status** - Track pending, completed, and cancelled tasks

---

## Deployment

### Prerequisites

- Docker installed on LXC 201 (192.168.40.14)
- Discord bot token (see [[11 - Credentials]])
- #claude-tasks channel ID

### Docker Compose

```yaml
version: '3.8'
services:
  athena-bot:
    build: ./athena
    container_name: athena-bot
    restart: unless-stopped
    ports:
      - "5051:5051"
    environment:
      - DISCORD_TOKEN=${ATHENA_DISCORD_TOKEN}
      - CHANNEL_ID=${ATHENA_CHANNEL_ID}
      - API_KEY=${ATHENA_API_KEY}
    volumes:
      - ./athena/data:/app/data
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `DISCORD_TOKEN` | Athena bot Discord token |
| `CHANNEL_ID` | #claude-tasks channel ID |
| `API_KEY` | API authentication key |

---

## API Endpoints

### Add Task

```bash
curl -X POST http://192.168.40.14:5051/api/tasks \
  -H "Authorization: Bearer athena-homelab-key" \
  -H "Content-Type: application/json" \
  -d '{"task": "Update Grafana dashboards", "priority": "high"}'
```

### Get Tasks

```bash
curl http://192.168.40.14:5051/api/tasks \
  -H "Authorization: Bearer athena-homelab-key"
```

### Complete Task

```bash
curl -X PUT http://192.168.40.14:5051/api/tasks/1/complete \
  -H "Authorization: Bearer athena-homelab-key"
```

---

## Claude Code Integration

Athena can be integrated with Claude Code via MCP for automated task management.

---

## Full Tutorial

For complete implementation details:
- **GitHub**: `docs/ATHENA_BOT_TUTORIAL.md`

---

## Related Documentation

- [[24 - Discord Bots]] - All Discord bots
- [[27 - Discord Bot Deployment Tutorial]] - Bot deployment guide
- [[11 - Credentials]] - API keys and tokens
