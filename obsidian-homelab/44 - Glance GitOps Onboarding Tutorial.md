# Glance GitOps Onboarding Tutorial

A hands-on, step-by-step guide to migrating the Glance Dashboard from Ansible-based deployment to GitOps using GitLab CI/CD.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Understanding the Current State](#2-understanding-the-current-state)
3. [GitOps Repository Structure](#3-gitops-repository-structure)
4. [File-by-File Breakdown](#4-file-by-file-breakdown)
5. [Setting Up GitLab Project](#5-setting-up-gitlab-project)
6. [Configuring CI/CD Variables](#6-configuring-cicd-variables)
7. [Initial Deployment](#7-initial-deployment)
8. [Making Your First GitOps Change](#8-making-your-first-gitops-change)
9. [Pipeline Deep Dive](#9-pipeline-deep-dive)
10. [Troubleshooting](#10-troubleshooting)
11. [Summary](#11-summary)

---

## 1. Introduction

### What You'll Learn

By the end of this tutorial, you will:

- Understand how GitOps transforms service management
- Know every file in a GitOps service repository
- Be able to onboard any Docker service to GitOps
- Understand the CI/CD pipeline stages
- Make changes with confidence using version control

### Why Glance?

Glance is the perfect first service to onboard because:

| Reason | Benefit |
|--------|---------|
| Low risk | Dashboard only, no data loss if broken |
| Multiple files | Config, CSS, compose - good template example |
| Visible results | You can immediately see changes on the dashboard |
| Uses secrets | API keys for Radarr/Sonarr - learn secret management |

### Before vs After

```
BEFORE: Ansible-Based Deployment
┌─────────────────────────────────────────────────────────────┐
│  1. SSH to Ansible controller                               │
│  2. Edit playbook files                                     │
│  3. Run: ansible-playbook deploy-glance-dashboard.yml       │
│  4. Wait for playbook to complete                           │
│  5. Manually verify deployment                              │
└─────────────────────────────────────────────────────────────┘

AFTER: GitOps Deployment
┌─────────────────────────────────────────────────────────────┐
│  1. Edit files in Git repository                            │
│  2. Commit and push to main                                 │
│  3. GitLab CI/CD automatically:                             │
│     • Validates configuration                               │
│     • Deploys to target host                                │
│     • Configures Traefik route                              │
│     • Verifies health                                       │
│     • Sends Discord notification                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Understanding the Current State

### Current Glance Deployment

Before migrating, let's understand what currently exists.

| Component | Location | Purpose |
|-----------|----------|---------|
| **LXC Container** | docker-lxc-glance | Dedicated container for Glance |
| **IP Address** | 192.168.40.12 | Services VLAN |
| **Install Path** | /opt/glance | Where files are stored |
| **Port** | 8080 | Internal container port |
| **URL** | https://glance.hrmsmrflrii.xyz | Public URL via Traefik |

### Current File Structure on Host

```bash
# SSH to see current structure
ssh root@192.168.40.12 "find /opt/glance -type f"
```

```
/opt/glance/
├── docker-compose.yml      # Container definition
├── .env                    # Environment variables (secrets)
├── config/
│   └── glance.yml          # Dashboard configuration
└── assets/
    └── custom-themes.css   # Custom styling
```

### Current Secrets

These secrets are currently in `/opt/glance/.env`:

| Secret | Purpose |
|--------|---------|
| `RADARR_API_KEY` | Fetch movie download statistics |
| `SONARR_API_KEY` | Fetch TV show download statistics |
| `OPNSENSE_API_CREDENTIALS` | Fetch firewall statistics (base64 encoded) |

---

## 3. GitOps Repository Structure

### The Complete Repository

Here's what the GitOps repository looks like:

```
glance-homelab/
├── .gitlab-ci.yml          # Pipeline definition (the automation)
├── .gitignore              # Files to exclude from Git
├── service.yml             # GitOps metadata (what/where/how)
├── README.md               # Documentation
├── config/
│   ├── docker-compose.yml  # Container definition
│   └── glance.yml          # Dashboard configuration
└── assets/
    └── custom-themes.css   # Custom CSS themes
```

### File Purposes Summary

| File | Purpose | Who Uses It |
|------|---------|-------------|
| `.gitlab-ci.yml` | Defines what the pipeline does | GitLab Runner |
| `service.yml` | Metadata about the service | Documentation, future automation |
| `docker-compose.yml` | Container configuration | Docker on target host |
| `glance.yml` | Dashboard layout and widgets | Glance application |
| `custom-themes.css` | Visual styling | Glance application |
| `.gitignore` | Prevent committing sensitive files | Git |
| `README.md` | How to use this repo | Humans |

---

## 4. File-by-File Breakdown

### 4.1 service.yml - The GitOps Metadata

This file describes the service and how it should be deployed. It's the "source of truth" for this service.

```yaml
# Service identification
service:
  name: glance                                    # Internal name
  display_name: Glance Dashboard                  # Human-readable name
  description: "Homelab dashboard with..."        # What it does
  category: dashboard                             # Service category
  version: "0.7.0"                                # Current version

# Deployment configuration
deployment:
  target_host: docker-lxc-glance                  # Where to deploy
  port: 8080                                      # External port
  container_port: 8080                            # Internal port
  install_path: /opt/glance                       # Path on target

  environment:                                    # Non-secret env vars
    TZ: America/New_York

  secrets:                                        # Secret mappings
    - name: RADARR_API_KEY                        # Name in .env file
      source: GLANCE_RADARR_API_KEY               # Name in GitLab CI/CD

  healthcheck:                                    # How to verify it's running
    enabled: true
    endpoint: /
    port: 8080

  extra_files:                                    # Additional files to deploy
    - source: config/glance.yml
      destination: config/glance.yml
    - source: assets/custom-themes.css
      destination: assets/custom-themes.css

# Traefik reverse proxy
traefik:
  enabled: true
  subdomain: glance                               # → glance.hrmsmrflrii.xyz
  entrypoints: [websecure]
  tls:
    enabled: true
    cert_resolver: letsencrypt

# Notifications
notifications:
  discord:
    enabled: true
```

**Key Concepts:**

| Concept | Explanation |
|---------|-------------|
| **Secrets Mapping** | `source` is the GitLab variable name, `name` is what appears in the .env file |
| **Extra Files** | Files beyond docker-compose.yml that need to be copied |
| **Target Host** | The hostname or IP where this service runs |

### 4.2 .gitlab-ci.yml - The Pipeline

This is the heart of GitOps - it defines what happens when you push code.

```yaml
# Pipeline metadata
stages:
  - validate      # Check syntax
  - deploy        # Copy files and start container
  - configure     # Set up Traefik route
  - verify        # Health check
  - notify        # Discord notification

# Service-specific variables
variables:
  DOMAIN: hrmsmrflrii.xyz
  SERVICE_NAME: glance
  TARGET_IP: "192.168.40.12"
  SSH_USER: root
  INSTALL_PATH: /opt/glance
  PORT: "8080"

# When does pipeline run?
workflow:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"      # On push to main
    - if: $CI_PIPELINE_SOURCE == "web"      # On manual trigger
```

**Stage Breakdown:**

| Stage | Purpose | What Happens |
|-------|---------|--------------|
| **validate** | Catch errors early | YAML syntax check, compose validation |
| **deploy** | Update the service | SSH → copy files → docker compose up |
| **configure** | Set up routing | Create/update Traefik dynamic config |
| **verify** | Confirm it works | Curl health endpoint repeatedly |
| **notify** | Alert humans | Send success/failure to Discord |

### 4.3 docker-compose.yml - Container Definition

```yaml
services:
  glance:
    image: glanceapp/glance:latest
    container_name: glance
    restart: unless-stopped

    ports:
      - "${SERVICE_PORT:-8080}:8080"    # Use env var or default to 8080

    volumes:
      - ./config:/app/config:ro         # Dashboard config (read-only)
      - ./assets:/app/assets:ro         # Custom CSS (read-only)
      - /etc/timezone:/etc/timezone:ro  # System timezone
      - /etc/localtime:/etc/localtime:ro

    env_file:
      - .env                            # Load secrets from .env

    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3

    labels:
      - "com.centurylinklabs.watchtower.enable=true"  # Auto-update
      - "homelab.service=glance"
      - "homelab.managed-by=gitlab-gitops"
```

**Key Points:**

| Element | Purpose |
|---------|---------|
| `env_file: - .env` | Loads secrets without committing them to Git |
| `volumes: :ro` | Read-only mounts prevent accidental modifications |
| `${SERVICE_PORT:-8080}` | Variable with default value |
| `healthcheck` | Docker monitors container health |

### 4.4 glance.yml - Dashboard Configuration

This is the Glance-specific configuration. Here's a simplified excerpt:

```yaml
server:
  port: 8080
  assets-path: /app/assets

theme:
  background-color: 240 21 15      # HSL values
  primary-color: 267 84 81
  custom-css-file: /app/assets/custom-themes.css

  presets:                          # Selectable themes
    midnight-blue:
      background-color: 213 58 10
      primary-color: 227 95 67
    nord:
      background-color: 220 16 22
      primary-color: 193 43 67

pages:
  - name: Home
    columns:
      - size: small
        widgets:
          - type: clock
            hour-format: "24h"
          - type: weather
            location: Manila, Philippines
          - type: bookmarks
            title: Quick Links
            groups:
              - title: Infrastructure
                links:
                  - title: Proxmox
                    url: https://proxmox.hrmsmrflrii.xyz
      - size: full
        widgets:
          - type: monitor
            title: Service Health
            sites:
              - title: Traefik
                url: http://192.168.40.20:8082/ping
                icon: si:traefikproxy
```

**Structure:**

```
glance.yml
├── server:        # Server settings (port, paths)
├── theme:         # Colors and CSS
│   └── presets:   # Additional selectable themes
└── pages:         # Dashboard pages
    └── columns:   # Layout columns
        └── widgets: # Individual widgets
```

---

## 5. Setting Up GitLab Project

### Step 5.1: Create the Project

1. Navigate to GitLab: https://gitlab.hrmsmrflrii.xyz

2. Create a new project:
   - **Name**: `glance-homelab`
   - **Group**: `homelab` (or your group)
   - **Visibility**: Private
   - **Initialize with README**: No (we'll push our own)

3. Copy the repository URL:
   ```
   git@gitlab.hrmsmrflrii.xyz:homelab/glance-homelab.git
   ```

### Step 5.2: Initialize Local Repository

```bash
# Navigate to the GitOps repo we created
cd /path/to/homelab-infra-automation-project/gitops-repos/glance-homelab

# Initialize Git
git init

# Add GitLab as remote
git remote add origin git@gitlab.hrmsmrflrii.xyz:homelab/glance-homelab.git

# Create main branch
git checkout -b main

# Add all files
git add .

# Initial commit
git commit -m "Initial GitOps setup for Glance Dashboard

- Add service.yml with deployment metadata
- Add docker-compose.yml with container config
- Add glance.yml with dashboard pages and widgets
- Add custom-themes.css for styling
- Add .gitlab-ci.yml with 5-stage pipeline
- Add README.md with documentation"
```

### Step 5.3: Don't Push Yet!

Before pushing, we need to configure CI/CD variables. If you push now, the pipeline will fail because it can't find the required secrets.

---

## 6. Configuring CI/CD Variables

### Step 6.1: Identify Required Variables

From our `.gitlab-ci.yml` and `service.yml`, we need:

| Variable | Level | Description |
|----------|-------|-------------|
| `SSH_PRIVATE_KEY` | Group | SSH key for all deployments |
| `DISCORD_WEBHOOK_URL` | Group | Shared notification webhook |
| `GLANCE_RADARR_API_KEY` | Project | Radarr API key |
| `GLANCE_SONARR_API_KEY` | Project | Sonarr API key |
| `GLANCE_OPNSENSE_CREDENTIALS` | Project | OPNsense API (base64) |

### Step 6.2: Configure Group-Level Variables

Group variables are shared across all projects in the group.

1. Go to: GitLab → **homelab** group → **Settings** → **CI/CD** → **Variables**

2. Add `SSH_PRIVATE_KEY`:
   - **Key**: `SSH_PRIVATE_KEY`
   - **Value**: (paste your SSH private key)
   - **Type**: File
   - **Protected**: Yes
   - **Masked**: Yes

3. Add `DISCORD_WEBHOOK_URL`:
   - **Key**: `DISCORD_WEBHOOK_URL`
   - **Value**: (your Discord webhook URL)
   - **Type**: Variable
   - **Protected**: No
   - **Masked**: Yes

### Step 6.3: Configure Project-Level Variables

Project variables are specific to this service.

1. Go to: **glance-homelab** project → **Settings** → **CI/CD** → **Variables**

2. Add each variable:

**GLANCE_RADARR_API_KEY:**
```
Key: GLANCE_RADARR_API_KEY
Value: your-radarr-api-key-here
Type: Variable
Protected: Yes
Masked: Yes
```

**GLANCE_SONARR_API_KEY:**
```
Key: GLANCE_SONARR_API_KEY
Value: your-sonarr-api-key-here
Type: Variable
Protected: Yes
Masked: Yes
```

**GLANCE_OPNSENSE_CREDENTIALS:**
```
Key: GLANCE_OPNSENSE_CREDENTIALS
Value: base64-encoded-credentials
Type: Variable
Protected: Yes
Masked: Yes
```

### How to Get These Values

| Secret | How to Find |
|--------|-------------|
| **SSH Private Key** | `cat ~/.ssh/homelab_ed25519` |
| **Discord Webhook** | Discord Server → Settings → Integrations → Webhooks |
| **Radarr API Key** | Radarr → Settings → General → API Key |
| **Sonarr API Key** | Sonarr → Settings → General → API Key |
| **OPNsense Credentials** | `echo -n "key:secret" \| base64` |

---

## 7. Initial Deployment

### Step 7.1: Push to GitLab

Now that variables are configured:

```bash
cd /path/to/gitops-repos/glance-homelab

# Push to main branch
git push -u origin main
```

### Step 7.2: Watch the Pipeline

1. Go to: **glance-homelab** → **Build** → **Pipelines**

2. You'll see the pipeline with 5 stages:

```
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ validate │→ │  deploy  │→ │configure │→ │  verify  │→ │  notify  │
└──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘
```

3. Click on each job to see logs

### Step 7.3: Verify Deployment

**Check the Dashboard:**
```
https://glance.hrmsmrflrii.xyz
```

**Check Container on Host:**
```bash
ssh root@192.168.40.12 "docker ps | grep glance"
```

**Check Discord:**
You should receive a notification:
```
✅ Deployed: Glance Dashboard
URL: https://glance.hrmsmrflrii.xyz
Pipeline: #123
Triggered by: YourUsername
```

---

## 8. Making Your First GitOps Change

Now let's see GitOps in action! We'll make a simple change and watch it deploy automatically.

### Step 8.1: Clone the Repository (if needed)

If you're on a different machine:

```bash
git clone git@gitlab.hrmsmrflrii.xyz:homelab/glance-homelab.git
cd glance-homelab
```

### Step 8.2: Make a Change

Let's add a new bookmark to the Home page.

Edit `config/glance.yml`:

```yaml
# Find the bookmarks section under Home page
# Add a new link:

              - title: Services
                links:
                  - title: Jellyfin
                    url: https://jellyfin.hrmsmrflrii.xyz
                  - title: GitLab
                    url: https://gitlab.hrmsmrflrii.xyz
                  - title: Immich
                    url: https://photos.hrmsmrflrii.xyz
                  - title: Grafana
                    url: https://grafana.hrmsmrflrii.xyz
                  - title: Portainer              # ← Add this
                    url: https://portainer.hrmsmrflrii.xyz
```

### Step 8.3: Commit and Push

```bash
# Check what changed
git status
git diff

# Stage and commit
git add config/glance.yml
git commit -m "Add Portainer to Home page bookmarks"

# Push to trigger deployment
git push
```

### Step 8.4: Watch It Deploy

1. Go to GitLab → Pipelines
2. Watch the new pipeline run
3. Wait for completion (~1-2 minutes)
4. Refresh https://glance.hrmsmrflrii.xyz
5. See your new bookmark!

### The GitOps Flow Visualized

```
┌─────────────────────────────────────────────────────────────────────┐
│                         YOUR CHANGE                                  │
│                                                                      │
│  1. Edit config/glance.yml locally                                  │
│                    │                                                 │
│                    ▼                                                 │
│  2. git commit -m "Add Portainer bookmark"                          │
│                    │                                                 │
│                    ▼                                                 │
│  3. git push origin main                                            │
└────────────────────┼────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      GITLAB CI/CD                                    │
│                                                                      │
│  4. Pipeline triggered automatically                                 │
│                    │                                                 │
│                    ▼                                                 │
│  5. Runner executes jobs:                                           │
│     • Validate YAML ✓                                               │
│     • SSH to 192.168.40.12 ✓                                        │
│     • Copy config/glance.yml ✓                                      │
│     • docker compose up -d ✓                                        │
│     • Health check passed ✓                                         │
└────────────────────┼────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      RESULT                                          │
│                                                                      │
│  6. Glance reloads with new configuration                           │
│  7. Discord notification: "Deployed: Glance Dashboard"              │
│  8. You see new bookmark on https://glance.hrmsmrflrii.xyz          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9. Pipeline Deep Dive

### Stage 1: Validate

```yaml
validate:yaml:
  stage: validate
  image: mikefarah/yq:4
  script:
    - yq eval '.' service.yml > /dev/null
    - yq eval '.' config/glance.yml > /dev/null
```

**What it does:** Uses `yq` to parse YAML files. If syntax is invalid, the pipeline stops here.

**Why it matters:** Catches typos before they reach production.

### Stage 2: Deploy

```yaml
deploy:glance:
  stage: deploy
  script:
    # 1. Generate .env from secrets
    - |
      cat > /tmp/glance.env << EOF
      RADARR_API_KEY=${GLANCE_RADARR_API_KEY}
      SONARR_API_KEY=${GLANCE_SONARR_API_KEY}
      EOF

    # 2. Create directories
    - ssh ${SSH_USER}@${TARGET_IP} "mkdir -p ${INSTALL_PATH}/config"

    # 3. Backup existing config
    - ssh ${SSH_USER}@${TARGET_IP} "cp ${INSTALL_PATH}/config/glance.yml ${INSTALL_PATH}/config/glance.yml.bak"

    # 4. Copy new files
    - scp config/docker-compose.yml ${SSH_USER}@${TARGET_IP}:${INSTALL_PATH}/
    - scp config/glance.yml ${SSH_USER}@${TARGET_IP}:${INSTALL_PATH}/config/
    - scp /tmp/glance.env ${SSH_USER}@${TARGET_IP}:${INSTALL_PATH}/.env

    # 5. Deploy
    - ssh ${SSH_USER}@${TARGET_IP} "cd ${INSTALL_PATH} && docker compose pull && docker compose up -d"
```

**What it does:**

| Step | Action | Purpose |
|------|--------|---------|
| 1 | Generate .env | Turn GitLab secrets into environment file |
| 2 | Create dirs | Ensure target paths exist |
| 3 | Backup | Enable rollback if needed |
| 4 | Copy files | Transfer repo files to target |
| 5 | Deploy | Pull latest image and restart container |

### Stage 3: Configure

```yaml
configure:traefik:
  stage: configure
  script:
    - |
      cat > /tmp/traefik-glance.yml << 'EOF'
      http:
        routers:
          glance:
            rule: "Host(`glance.hrmsmrflrii.xyz`)"
            service: glance
            entryPoints:
              - websecure
            tls:
              certResolver: letsencrypt
        services:
          glance:
            loadBalancer:
              servers:
                - url: "http://192.168.40.12:8080"
      EOF

    - scp /tmp/traefik-glance.yml root@192.168.40.20:/opt/traefik/config/dynamic/glance.yml
```

**What it does:** Creates a Traefik dynamic configuration file so `glance.hrmsmrflrii.xyz` routes to the container.

### Stage 4: Verify

```yaml
verify:health:
  stage: verify
  script:
    - |
      for i in $(seq 1 30); do
        if curl -sf "http://${TARGET_IP}:${PORT}" > /dev/null 2>&1; then
          echo "✓ Glance is healthy!"
          exit 0
        fi
        echo "Attempt $i/30 - waiting 5 seconds..."
        sleep 5
      done
      echo "✗ Health check failed"
      exit 1
```

**What it does:** Tries to reach Glance up to 30 times (2.5 minutes total). Fails the pipeline if the service doesn't respond.

### Stage 5: Notify

```yaml
notify:success:
  stage: notify
  script:
    - |
      curl -H "Content-Type: application/json" \
        -d '{
          "embeds": [{
            "title": "✅ Deployed: Glance Dashboard",
            "description": "Dashboard deployed successfully",
            "color": 3066993
          }]
        }' \
        "${DISCORD_WEBHOOK_URL}"
  when: on_success

notify:failure:
  stage: notify
  script:
    - |
      curl -H "Content-Type: application/json" \
        -d '{
          "embeds": [{
            "title": "❌ Deployment Failed: Glance Dashboard",
            "color": 15158332
          }]
        }' \
        "${DISCORD_WEBHOOK_URL}"
  when: on_failure
```

**What it does:** Sends Discord notification on success or failure.

---

## 10. Troubleshooting

### Pipeline Failed at Validate Stage

**Symptom:** `yq: Error: Invalid YAML`

**Solution:**
```bash
# Validate locally first
yq eval '.' config/glance.yml
```

Common issues:
- Indentation errors
- Missing quotes around URLs
- Tabs instead of spaces

### Pipeline Failed at Deploy Stage

**Symptom:** `Permission denied (publickey)`

**Solution:**
1. Check `SSH_PRIVATE_KEY` variable is set correctly
2. Verify the key has access to target host:
   ```bash
   ssh -i ~/.ssh/homelab_ed25519 root@192.168.40.12
   ```

### Pipeline Failed at Verify Stage

**Symptom:** `Health check failed after 30 attempts`

**Solution:**
```bash
# Check container status
ssh root@192.168.40.12 "docker ps -a | grep glance"

# Check logs
ssh root@192.168.40.12 "docker logs glance --tail 50"
```

Common issues:
- Port conflict
- Config syntax error (Glance won't start)
- Missing environment variables

### Dashboard Shows Errors

**Symptom:** Widget shows "Error loading data"

**Solution:**
Check the specific widget's configuration in `glance.yml`:
- Monitor widgets: Verify URLs are reachable
- Media widgets: Verify API keys are correct
- iFrame widgets: Verify source URLs work

### Rollback to Previous Version

If something goes wrong, use the manual rollback job:

1. Go to GitLab → Pipelines
2. Find the latest pipeline
3. Click "rollback" job
4. Click "Play" to trigger

Or via command line:
```bash
ssh root@192.168.40.12 "
  cd /opt/glance
  mv config/glance.yml.bak config/glance.yml
  docker compose up -d
"
```

---

## 11. Summary

### What You've Learned

| Concept | Key Takeaway |
|---------|--------------|
| **GitOps** | Git is the source of truth; push = deploy |
| **Repository Structure** | service.yml + compose + config + pipeline |
| **CI/CD Variables** | Secrets stored in GitLab, injected at runtime |
| **Pipeline Stages** | validate → deploy → configure → verify → notify |
| **Making Changes** | Edit, commit, push, watch pipeline, verify |

### The GitOps Mindset

```
┌─────────────────────────────────────────────────────────────────────┐
│                      OLD WAY (Imperative)                            │
│                                                                      │
│  "SSH to server, edit file, restart service, hope it works"         │
│                                                                      │
│  Problems:                                                           │
│  • No history of changes                                             │
│  • No rollback capability                                            │
│  • No visibility into what changed                                   │
│  • Knowledge locked in one person's head                             │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      NEW WAY (Declarative GitOps)                    │
│                                                                      │
│  "Describe desired state in Git, system makes it happen"            │
│                                                                      │
│  Benefits:                                                           │
│  • Full history in Git                                               │
│  • Easy rollback (revert commit)                                     │
│  • Code review for changes (merge requests)                          │
│  • Self-documenting (README + service.yml)                           │
│  • Automated testing and validation                                  │
│  • Notifications on every change                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Next Steps

Now that Glance is onboarded, you can:

1. **Onboard another service** - Use the same pattern for Grafana, Jellyfin, etc.
2. **Add merge request workflow** - Require reviews before merging to main
3. **Add automated testing** - Run tests before deploying
4. **Create a template repository** - Standardize for all services

### Quick Reference

| Task | Command |
|------|---------|
| Clone repo | `git clone git@gitlab.hrmsmrflrii.xyz:homelab/glance-homelab.git` |
| Make change | Edit files, `git add .`, `git commit -m "message"`, `git push` |
| Watch pipeline | GitLab → Build → Pipelines |
| Check logs | `ssh root@192.168.40.12 "docker logs glance --tail 50"` |
| Manual rollback | GitLab → Pipelines → Click "rollback" → Play |
| Restart service | GitLab → Pipelines → Click "restart" → Play |

---

## Related Documents

- [[43 - GitOps Complete Tutorial]] - Full GitOps theory and concepts
- [[11 - Credentials]] - API keys and secrets
- [[17 - Glance Dashboard]] - Glance configuration reference
- [[23 - Traefik Reverse Proxy]] - Traefik routing details

---

*Tutorial created: 2025-01-14*
*Service: Glance Dashboard v0.7.0+*
*Target: docker-lxc-glance (192.168.40.12)*
