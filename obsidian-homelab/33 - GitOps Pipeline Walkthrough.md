---
tags:
  - homelab
  - gitops
  - gitlab
  - cicd
  - pipeline
created: 2025-12-30
updated: 2025-12-30
status: active
---

# GitOps Pipeline Walkthrough

## Pipeline Overview

The GitOps pipeline consists of **10 stages** and **13 jobs** that execute sequentially to deploy and configure services.

### Visual Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GITLAB CI/CD PIPELINE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  STAGE 1        STAGE 2        STAGE 3        STAGE 4                       │
│  ────────       ────────       ────────       ────────                       │
│                                                                              │
│  ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐  ┌────────┐        │
│  │ detect │────►│validate│────►│  plan  │────►│ deploy │  │ remove │        │
│  │changes │     │services│     │        │     │contains│  │services│        │
│  └────────┘     └────────┘     └────────┘     └────────┘  └────────┘        │
│                                                    │           │             │
│                                                    ▼           │             │
│  STAGE 5                      STAGE 6             │           │             │
│  ────────                     ────────            │           │             │
│                                                   │           │             │
│  ┌────────┐  ┌────────┐       ┌────────┐         │           │             │
│  │configure│  │configure│◄─────│configure│◄────────┘           │             │
│  │ traefik│  │  dns   │       │authentik│                     │             │
│  └────────┘  └────────┘       └────────┘                      │             │
│       │           │                │                          │             │
│       └───────────┼────────────────┘                          │             │
│                   ▼                                           │             │
│  STAGE 7        STAGE 8        STAGE 9        STAGE 10        │             │
│  ────────       ────────       ────────       ─────────       │             │
│                                                               │             │
│  ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐     │             │
│  │ update │────►│ verify │────►│ notify │     │rollback│     │             │
│  │ glance │     │        │     │success │     │(manual)│     │             │
│  └────────┘     └────────┘     └────────┘     └────────┘     │             │
│                                     │                         │             │
│                                ┌────────┐                     │             │
│                                │ notify │◄────────────────────┘             │
│                                │failure │ (on failure)                      │
│                                └────────┘                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Stage Summary

| Stage | Jobs | Purpose | Failure Impact |
|-------|------|---------|----------------|
| detect | 1 | Find changed service files | Pipeline stops |
| validate | 1 | Validate YAML against schema | Pipeline stops |
| plan | 1 | Show deployment preview | Pipeline stops |
| deploy | 2 | Deploy containers, remove old | Pipeline stops |
| configure_routing | 2 | Traefik + DNS | Allow failure |
| configure_security | 1 | Authentik SSO | Allow failure |
| configure_dashboard | 1 | Update Glance | Allow failure |
| verify | 1 | Health checks | Allow failure |
| notify | 2 | Discord notifications | Allow failure |
| rollback | 1 | Manual rollback | N/A (manual) |

---

## Stage 1: Detect Changes

### Purpose
Analyzes the git commit to identify which service YAML files were added, modified, or deleted.

### Output: changes.json
```json
{
  "deploy": [
    {"path": "services/downloads/metube.yml", "name": "metube", "action": "add"}
  ],
  "remove": [],
  "added": 1,
  "modified": 0,
  "deleted": 0,
  "total": 1,
  "mode": "incremental"
}
```

### Execution Flow
```
1. Pipeline triggered by git push
       │
       ▼
2. Check CI_PIPELINE_SOURCE
       │
       ├── "push" ──► Get base/head SHAs, Run git diff
       │
       └── "web" ──► Deploy all mode, Scan all service files
       │
       ▼
3. Filter for services/*.yml files
       │
       ▼
4. Categorize: added/modified/deleted
       │
       ▼
5. Write changes.json artifact
```

---

## Stage 2: Validate

### Purpose
Validates all changed service YAML files against the JSON Schema.

### Validation Checks

| Check | Description | Example Error |
|-------|-------------|---------------|
| Required fields | service.name, deployment.port | "name is required" |
| Field types | port must be integer | "8080 is not of type 'integer'" |
| Enum values | category must be valid | "invalid is not one of ['media', 'downloads']" |
| Pattern matching | name format | "My Service does not match pattern" |

---

## Stage 3: Plan

### Purpose
Generates a human-readable deployment plan showing what will be deployed.

### Example Output
```
=== DEPLOYMENT PLAN ===

Service: services/downloads/metube.yml
  Name: metube
  Host: docker-media
  Port: 8082
  Image: ghcr.io/alexta69/metube:latest
  Traefik: enabled
  DNS: enabled
  Authentik: enabled
  Glance: enabled

=== END PLAN ===
```

---

## Stage 4: Deploy

### Purpose
Deploys Docker containers to target hosts via SSH.

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     CONTAINER DEPLOYMENT                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  GitLab Runner                        Target Host                │
│  ─────────────                        ───────────                │
│                                                                  │
│  1. Parse YAML                                                   │
│        │                                                         │
│        ▼                                                         │
│  2. Generate docker-compose.yml                                  │
│        │                                                         │
│        ▼                                                         │
│  3. SSH ─────────────────────────────► 4. mkdir /opt/service    │
│                                              │                   │
│                                              ▼                   │
│                                        5. Write compose.yml      │
│                                              │                   │
│                                              ▼                   │
│                                        6. docker compose pull    │
│                                              │                   │
│                                              ▼                   │
│                                        7. docker compose up -d   │
│                                              │                   │
│                                              ▼                   │
│  8. Exit code ◄──────────────────────── Container Running        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Stage 5: Configure Routing

### Purpose
Configures Traefik reverse proxy routes and DNS records in parallel.

### Traefik Configuration
- Adds router with Host rule
- Creates load balancer service
- Configures TLS with Let's Encrypt

### DNS Configuration
- Authenticates with Pi-hole v6 API
- Creates custom DNS record
- Points hostname to Traefik IP (192.168.40.20)

---

## Stage 6: Configure Security

### Purpose
Creates Authentik SSO applications for services that require authentication.

### Actions
1. Create Proxy Provider
2. Create Application
3. Add to traefik-outpost providers list

---

## Stage 7: Configure Dashboard

### Purpose
Updates the Glance dashboard with bookmarks and monitor entries.

### Actions
1. SSH to LXC
2. Parse glance.yml
3. Add bookmark to appropriate group
4. Add monitor to appropriate widget
5. Restart Glance container

---

## Stage 8: Verify

### Purpose
Performs health checks on all deployed services.

### Verification Checks

| Check | Description | Pass Criteria |
|-------|-------------|---------------|
| Container running | Docker container status | Status: "running" |
| Port listening | Service port accessible | Port responds |
| Health endpoint | HTTP health check | Status code in expected list |
| DNS resolution | Hostname resolves | Resolves to correct IP |
| Traefik route | HTTPS accessible | Returns valid response |

---

## Stage 9: Notify

### Purpose
Sends notifications about pipeline success or failure to Discord.

---

## Stage 10: Rollback

### Purpose
Provides a manual rollback mechanism.

### Rollback Actions

| Component | Rollback Action |
|-----------|----------------|
| Container | Restore from backup compose.yml |
| Traefik | Remove route from config |
| DNS | Delete Pi-hole record |
| Authentik | Delete provider and application |
| Glance | Remove bookmark and monitor |

---

## Pipeline Variables

### Built-in Variables

| Variable | Description |
|----------|-------------|
| `CI_PROJECT_DIR` | Root directory of project |
| `CI_COMMIT_SHA` | Current commit SHA |
| `CI_COMMIT_BEFORE_SHA` | Previous commit SHA |
| `CI_PIPELINE_SOURCE` | What triggered pipeline |
| `CI_COMMIT_BRANCH` | Branch name |

### Custom Variables (GitLab CI Settings)

| Variable | Description |
|----------|-------------|
| `PIHOLE_API_PASSWORD` | Pi-hole password |
| `AUTHENTIK_TOKEN` | Authentik API token |
| `DISCORD_WEBHOOK_URL` | Discord webhook |

---

## Artifact Flow

```
detect_changes
    │
    ▼
┌─────────────────┐
│  changes.json   │─────────────────────────────────────────┐
└─────────────────┘                                          │
         │                                                   │
         ▼                                                   ▼
  validate_services ────► plan_deployment ────► deploy_containers
                                │                      │
                                │                      ▼
                                │              configure_traefik
                                │              configure_dns
                                │                      │
                                │                      ▼
                                │              configure_authentik
                                │                      │
                                │                      ▼
                                │              update_glance
                                │                      │
                                │                      ▼
                                └────────────► verify_deployment
                                                       │
                                                       ▼
                                              ┌─────────────────┐
                                              │verification.json│
                                              └─────────────────┘
```

---

## Related Documents

- [[32 - GitOps Architecture]] - Architecture overview
- [[34 - GitOps Deployment Tutorial]] - Step-by-step deployment guide
- [[35 - GitOps Troubleshooting]] - Common issues and solutions

---

*Last updated: December 30, 2025*
