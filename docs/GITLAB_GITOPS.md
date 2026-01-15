# GitLab GitOps Architecture

This document describes the GitOps architecture for deploying homelab services using GitLab CI/CD.

## Overview

Each service gets its own GitLab repository with a standardized structure. When changes are pushed to the `main` branch, GitLab CI/CD automatically:

1. Validates the configuration
2. Deploys the container to the target Docker host
3. Configures Traefik routing
4. Adds DNS records via OPNsense API
5. Verifies service health
6. Sends Discord notifications

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GITLAB GITOPS FLOW                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Developer                 GitLab                    Homelab        │
│      │                        │                          │           │
│      │  git push main         │                          │           │
│      │───────────────────────>│                          │           │
│      │                        │                          │           │
│      │                        │  ┌──────────────────┐    │           │
│      │                        │  │ Pipeline Stages  │    │           │
│      │                        │  │                  │    │           │
│      │                        │  │ 1. Validate      │    │           │
│      │                        │  │ 2. Deploy ───────│───>│ Docker    │
│      │                        │  │ 3. Configure ────│───>│ Traefik   │
│      │                        │  │ 4. Verify        │    │ DNS       │
│      │                        │  │ 5. Notify ───────│───>│ Discord   │
│      │                        │  └──────────────────┘    │           │
│      │                        │                          │           │
│      │<───────────────────────│  Notification            │           │
│      │                        │                          │           │
└─────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

Each service repository follows this structure:

```
service-name/
├── .gitlab-ci.yml          # CI/CD pipeline definition
├── service.yml             # Service configuration (GitOps metadata)
├── config/
│   ├── docker-compose.yml  # Container definition
│   └── .env.example        # Environment template (reference only)
├── README.md               # Service documentation
└── .gitignore
```

## GitLab CI/CD Variables

### Group-Level Variables (Shared)

Set these at the GitLab group level so all service repos inherit them:

| Variable | Type | Description |
|----------|------|-------------|
| `SSH_PRIVATE_KEY` | File | SSH private key for deployment to Docker hosts |
| `DISCORD_WEBHOOK_URL` | Variable | Discord webhook for deployment notifications |
| `OPNSENSE_API_KEY` | Variable | OPNsense API key for DNS automation |
| `OPNSENSE_API_SECRET` | Variable | OPNsense API secret (masked) |

**To configure group variables:**
1. Go to your GitLab group → Settings → CI/CD → Variables
2. Add each variable with appropriate protection settings
3. Mark sensitive values as "Masked"

### Project-Level Variables (Service-Specific)

Add service-specific secrets at the project level:

| Service | Variable | Description |
|---------|----------|-------------|
| Grafana | `GRAFANA_ADMIN_PASSWORD` | Admin password |
| Sentinel Bot | `DISCORD_BOT_TOKEN` | Discord bot token |
| Sentinel Bot | `RADARR_API_KEY` | Radarr API key |
| Authentik | `AUTHENTIK_SECRET_KEY` | Secret key |

## Pipeline Stages

### Stage 1: Validate

Validates configuration files before deployment:

- **validate:service-yml** - Checks `service.yml` syntax and required fields
- **validate:docker-compose** - Validates Docker Compose syntax

### Stage 2: Deploy

Deploys the container to the target Docker host:

1. Parses `service.yml` to determine target host and configuration
2. Generates `.env` file from environment variables and secrets
3. SSHs to target host
4. Copies `docker-compose.yml` and `.env`
5. Runs `docker compose pull && up -d`

### Stage 3: Configure

Configures external services:

- **configure:traefik** - Generates and deploys Traefik dynamic config
- **configure:dns** - Adds DNS record via OPNsense API (if not exists)

### Stage 4: Verify

Verifies deployment success:

- **verify:health** - Polls health endpoint until service responds

### Stage 5: Notify

Sends notifications:

- **notify:success** - Discord embed on successful deployment
- **notify:failure** - Discord embed on failed deployment

## Target Hosts

| Host Name | IP | SSH User | Purpose |
|-----------|-----|----------|---------|
| `docker-lxc-media` | 192.168.40.11 | hermes-admin | Media services (Jellyfin, *arr) |
| `docker-lxc-glance` | 192.168.40.12 | root | Dashboard and APIs |
| `docker-vm-core-utilities01` | 192.168.40.13 | hermes-admin | Monitoring and utilities |
| `docker-lxc-bots` | 192.168.40.14 | root | Discord bots |
| `traefik-lxc` | 192.168.40.20 | root | Reverse proxy (Traefik only) |
| `authentik-lxc` | 192.168.40.21 | root | SSO (Authentik only) |

## service.yml Reference

```yaml
service:
  name: my-service              # Unique identifier (required)
  display_name: My Service      # Human-readable name (required)
  description: "Description"    # Optional
  category: utility             # monitoring, media, utility, api
  version: "1.0.0"              # Optional

deployment:
  target_host: docker-vm-core-utilities01  # Required - see host list
  port: 8080                    # Required - host port
  container_port: 8080          # Optional - container port
  install_path: /opt/my-service # Optional - defaults to /opt/{name}

  environment:                  # Static env vars (non-sensitive)
    TZ: America/New_York
    LOG_LEVEL: info

  secrets:                      # GitLab CI/CD variables to inject
    - name: API_KEY             # Env var name in container
      source: MY_SERVICE_API_KEY # GitLab variable name

  healthcheck:
    enabled: true               # Enable health verification
    endpoint: /health           # Health check path
    port: 8080                  # Health check port
    interval: 30                # Seconds between checks
    timeout: 10                 # Seconds to wait
    retries: 3                  # Retry count
    expected_status: [200]      # Expected HTTP status

traefik:
  enabled: true                 # Create Traefik route
  subdomain: my-service         # -> my-service.hrmsmrflrii.xyz
  entrypoints: [websecure]      # HTTPS by default
  tls:
    enabled: true
    cert_resolver: letsencrypt
  middlewares: []               # Optional middleware list
  headers:
    frame_deny: true            # Set false for iframe embedding

dns:
  enabled: true                 # Auto-add DNS record
  hostname: my-service          # Usually same as subdomain

authentik:
  enabled: false                # Require SSO login
  method: forward_auth          # forward_auth, proxy, oidc

glance:
  enabled: false                # Add to Glance dashboard
  page: home                    # home, compute, media, network, storage
  bookmark:
    enabled: true
    group: Utilities
    description: "Short description"
  monitor:
    enabled: true
    widget: monitor
    health_endpoint: /health

watchtower:
  enabled: true                 # Monitor for image updates
  notify_on_update: true        # Discord notification

notifications:
  discord:
    enabled: true               # Send deployment notifications
```

## Creating a New Service

### Step 1: Create GitLab Repository

1. Go to GitLab → New Project → Create blank project
2. Name it `service-name` (match `service.name` in service.yml)
3. Create in your homelab group (inherits CI/CD variables)

### Step 2: Copy Template

Copy the template files from `gitops-templates/gitlab-service-template/`:

```bash
# Clone the template
cp -r gitops-templates/gitlab-service-template/* /path/to/new-repo/

# Or use GitLab's repository import
```

### Step 3: Configure service.yml

Edit `service.yml`:

```yaml
service:
  name: my-new-service
  display_name: My New Service
  description: "What this service does"

deployment:
  target_host: docker-vm-core-utilities01
  port: 8080
  install_path: /opt/my-new-service

traefik:
  enabled: true
  subdomain: my-new-service
```

### Step 4: Configure docker-compose.yml

Edit `config/docker-compose.yml` with your container definition.

### Step 5: Add Project Secrets (if needed)

If your service needs secrets:

1. Add to `service.yml`:
   ```yaml
   deployment:
     secrets:
       - name: API_KEY
         source: MY_SERVICE_API_KEY
   ```

2. Add GitLab variable:
   - Project → Settings → CI/CD → Variables
   - Add `MY_SERVICE_API_KEY` with the secret value

### Step 6: Push and Deploy

```bash
git add .
git commit -m "Initial service configuration"
git push origin main
```

The pipeline will automatically deploy the service.

## Manual Operations

### Trigger Deployment Manually

1. Go to CI/CD → Pipelines
2. Click "Run pipeline"
3. Select `main` branch
4. Click "Run pipeline"

### Rollback to Previous Version

1. Go to CI/CD → Pipelines
2. Find the current pipeline
3. Click the "rollback" job
4. Click "Run" (play button)

This restores the previous `docker-compose.yml` and `.env` from backups.

### View Deployment Logs

1. Go to CI/CD → Pipelines
2. Click the pipeline number
3. Click on any job to view logs

## Troubleshooting

### Pipeline Fails at SSH

**Error:** `Permission denied (publickey)`

**Solution:**
1. Verify `SSH_PRIVATE_KEY` group variable is set
2. Variable must be "File" type, not "Variable"
3. Key must match what's in `/home/hermes-admin/.ssh/authorized_keys` on target

### DNS Record Not Created

**Error:** DNS job succeeds but record doesn't exist

**Solution:**
1. Check OPNsense API credentials are correct
2. Verify OPNsense at 192.168.91.30 is reachable from runner
3. Check Unbound DNS service is running

### Health Check Fails

**Error:** `Health check failed after 30 attempts`

**Solution:**
1. Container may need more startup time - increase `start_period` in docker-compose.yml
2. Health endpoint may be wrong - check `healthcheck.endpoint` in service.yml
3. SSH to host and check: `docker logs <container-name>`

### Traefik Route Not Working

**Error:** 404 or connection refused after deployment

**Solution:**
1. Check Traefik config was created: `ls /opt/traefik/config/dynamic/`
2. Verify Traefik reloaded: `docker logs traefik | tail -20`
3. Check DNS resolves: `nslookup <subdomain>.hrmsmrflrii.xyz`

## Architecture Diagram

```
                              GITLAB VM
    ┌─────────────────────────────────────────────────────────────┐
    │  GitLab CE (gitlab.hrmsmrflrii.xyz)                         │
    │  ┌─────────────────┐    ┌─────────────────────────────────┐ │
    │  │ Service Repos   │    │ GitLab Runner                   │ │
    │  │ ├─ grafana      │    │ Labels: homelab, docker         │ │
    │  │ ├─ jellyfin     │    │ Executor: Docker                │ │
    │  │ ├─ sentinel-bot │    │                                 │ │
    │  │ └─ ...          │    │ Deploys via SSH to:             │ │
    │  └─────────────────┘    │ • docker-media (40.11)          │ │
    │                         │ • docker-glance (40.12)         │ │
    │  ┌─────────────────┐    │ • docker-utils (40.13)          │ │
    │  │ CI/CD Variables │    │ • docker-bots (40.14)           │ │
    │  │ (Group Level)   │    │                                 │ │
    │  │ ├─SSH_PRIVATE_KEY│   │ Configures:                     │ │
    │  │ ├─DISCORD_WEBHOOK│   │ • Traefik (40.20)               │ │
    │  │ └─OPNSENSE_API_* │   │ • OPNsense DNS (91.30)          │ │
    │  └─────────────────┘    └─────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────┘
```

## Migration from Manual Deployment

To migrate an existing manually-deployed service:

1. **Export current config:**
   ```bash
   ssh docker-utils "cat /opt/service-name/docker-compose.yml"
   ssh docker-utils "cat /opt/service-name/.env"
   ```

2. **Create GitLab repo** with the template structure

3. **Copy config** into `config/docker-compose.yml`

4. **Create service.yml** matching current deployment

5. **Add secrets** to GitLab CI/CD variables

6. **Push to main** - service will redeploy via GitOps

7. **Verify** service works as expected

Future changes are now managed via Git commits.
