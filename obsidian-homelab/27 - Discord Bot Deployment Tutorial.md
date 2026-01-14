# Discord Bot Deployment Tutorial

> Complete guide to creating, deploying, and managing Discord bots in Docker containers on Proxmox infrastructure.

Related: [[24 - Discord Bots]] | [[26 - Tutorials Index]] | [[11 - Credentials]]

---

## Overview

This tutorial covers the complete workflow from Discord application creation to production deployment in LXC containers.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Proxmox Cluster                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LXC 201: docker-lxc-bots (192.168.40.14)              │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │  Argus Bot  │  │ Chronos Bot │  │ Athena API  │     │   │
│  │  │ (Container  │  │  (Project   │  │  (Task      │     │   │
│  │  │  Updates)   │  │ Management) │  │   Queue)    │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  │                                                         │   │
│  │                  Docker Engine                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  VM: docker-vm-media01 (192.168.40.11)                 │   │
│  │                                                         │   │
│  │  ┌───────────────┐                                      │   │
│  │  │ Mnemosyne Bot │  (Media Download Notifications)      │   │
│  │  └───────────────┘                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Discord Bots

| Bot | Channel | Purpose | Host |
|-----|---------|---------|------|
| **Argus** | #container-updates | Container update notifications | LXC 201 |
| **Chronos** | #project-management | GitLab project management | LXC 201 |
| **Athena** | #claude-tasks | Claude task queue API | LXC 201 |
| **Mnemosyne** | #media-downloads | Media download notifications | VM 111 |

---

## Quick Start

### Part 1: Create Discord Application

1. Go to https://discord.com/developers/applications
2. Click "New Application" → Name it (e.g., "Argus")
3. Go to "Bot" section → Click "Add Bot"
4. Enable "Message Content Intent" under Privileged Gateway Intents
5. Copy the Bot Token (store securely in [[11 - Credentials]])

### Part 2: Invite Bot to Server

Generate invite URL:
```
https://discord.com/oauth2/authorize?client_id=YOUR_CLIENT_ID&permissions=274878286912&scope=bot
```

Required permissions:
- Send Messages
- Embed Links
- Attach Files
- Read Message History
- Add Reactions

### Part 3: Basic Bot Structure

```python
# bot.py
import discord
from discord.ext import commands
import os

bot = commands.Bot(command_prefix='/', intents=discord.Intents.all())

@bot.event
async def on_ready():
    print(f'{bot.user} has connected to Discord!')

@bot.slash_command(name="ping", description="Check if bot is alive")
async def ping(ctx):
    await ctx.respond(f"Pong! Latency: {round(bot.latency * 1000)}ms")

bot.run(os.environ.get('DISCORD_TOKEN'))
```

### Part 4: Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

CMD ["python", "bot.py"]
```

### Part 5: Docker Compose

```yaml
version: '3.8'
services:
  argus-bot:
    build: .
    container_name: argus-bot
    restart: unless-stopped
    environment:
      - DISCORD_TOKEN=${DISCORD_TOKEN}
    volumes:
      - ./data:/app/data
```

### Part 6: Deploy to LXC

```bash
# SSH to bot LXC
ssh root@192.168.40.14

# Clone/copy bot code
cd /opt/discord-bots/argus

# Create .env file
echo "DISCORD_TOKEN=your_token_here" > .env

# Start bot
docker compose up -d

# View logs
docker logs argus-bot -f
```

---

## Full Tutorial

For the complete step-by-step tutorial with detailed explanations, see:
- **GitHub**: `docs/DISCORD_BOT_DEPLOYMENT_TUTORIAL.md`
- **Wiki**: https://github.com/herms14/Proxmox-TerraformDeployments/wiki

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Bot not responding | Check token, verify intents enabled |
| Permission errors | Re-invite with correct permissions |
| Connection reset | Check Docker networking, firewall rules |

---

## Related Documentation

- [[24 - Discord Bots]] - Bot details and configuration
- [[30 - LXC Migration Tutorial]] - LXC container setup
- [[11 - Credentials]] - Bot tokens and API keys
