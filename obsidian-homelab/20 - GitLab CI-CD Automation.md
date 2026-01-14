# GitLab CI/CD Service Onboarding

> **Internal Documentation** - Automated service deployment via GitLab CI/CD.

Related: [[00 - Homelab Index]] | [[07 - Deployed Services]] | [[15 - New Service Onboarding Guide]] | [[19 - Watchtower Updates]]

---

## Overview

Automate the entire service onboarding workflow using GitLab CI/CD. When you commit a `service.yml` to a repository, the pipeline automatically:

1. Deploys the container to the target Docker host
2. Configures Traefik reverse proxy
3. Adds DNS record in OPNsense
4. Registers with Watchtower for updates
5. Sends Discord notification
6. (Optional) Configures Authentik SSO

---

## Infrastructure

| Component | IP | Purpose |
|-----------|-----|---------|
| GitLab Server | 192.168.40.23 | CI/CD coordinator |
| GitLab Runner VM | 192.168.40.24 | Job executor (shell) |
| Automation Scripts | /opt/gitlab-runner/scripts/ | Python scripts |

---

## Quick Start

### 1. Create Repository in GitLab

Navigate to http://192.168.40.23 and create a new project.

### 2. Add Configuration Files

**`.gitlab-ci.yml`**:
```bash
# Copy from runner VM
scp hermes-admin@192.168.40.24:/opt/gitlab-runner/scripts/.gitlab-ci.yml .
```

**`service.yml`**:
```yaml
service:
  name: "myservice"
  display_name: "My Service"
  description: "What it does"

deployment:
  target_host: "docker-vm-core-utilities01"
  port: 8080
  container_port: 8080
  image: "myorg/myservice:latest"

traefik:
  enabled: true
  subdomain: "myservice"

dns:
  enabled: true

watchtower:
  enabled: true
```

### 3. Commit to Main Branch

```bash
git add .
git commit -m "Add service configuration"
git push origin main
```

### 4. Watch Pipeline

GitLab > CI/CD > Pipelines

---

## Pipeline Stages

```
validate → deploy → configure_traefik → configure_dns → register_watchtower → configure_sso → notify
                                                                                              ↓
                                                                                           rollback
```

| Stage | Description | Allow Failure |
|-------|-------------|---------------|
| validate | Parse service.yml | No |
| deploy | Deploy container | No |
| configure_traefik | Add Traefik routes | No |
| configure_dns | Add OPNsense DNS | Yes |
| register_watchtower | Register updates | Yes |
| configure_sso | Authentik SSO | Yes |
| notify | Discord notification | - |

---

## Target Hosts

| Host | IP | Use For |
|------|-----|---------|
| docker-vm-core-utilities01 | 192.168.40.13 | Utility services |
| docker-vm-media01 | 192.168.40.11 | Media services |
| traefik-vm01 | 192.168.40.20 | Traefik only |
| authentik-vm01 | 192.168.40.21 | Authentik only |
| immich-vm01 | 192.168.40.22 | Immich only |
| gitlab-vm01 | 192.168.40.23 | GitLab only |

---

## Service Definition Schema

### Minimal Example

```yaml
service:
  name: "whoami"
  display_name: "WhoAmI"
  description: "Test service"

deployment:
  target_host: "docker-vm-core-utilities01"
  port: 8888
  container_port: 80
  image: "traefik/whoami:latest"
```

### Full Example with All Options

```yaml
service:
  name: "myservice"
  display_name: "My Service"
  description: "Full example"

deployment:
  target_host: "docker-vm-core-utilities01"
  target_ip: "192.168.40.13"  # Auto-filled from target_host
  port: 8080
  container_port: 8080
  image: "myorg/myservice:latest"
  install_path: "/opt/myservice"
  restart_policy: "unless-stopped"
  volumes:
    - "/opt/myservice/config:/config"
    - "/opt/myservice/data:/data"
  environment:
    TZ: "America/New_York"
    DATABASE_URL: "postgres://..."
  healthcheck_path: "/health"
  healthcheck_status: [200]

traefik:
  enabled: true
  subdomain: "myservice"
  websocket: false

dns:
  enabled: true
  hostname: "myservice"
  ip: "192.168.40.20"

watchtower:
  enabled: true
  container_name: "myservice"

authentik:
  enabled: false
  method: "forward_auth"

notifications:
  discord:
    enabled: true
```

---

## CI/CD Variables

Configure in GitLab > Settings > CI/CD > Variables:

| Variable | Protected | Masked | Description |
|----------|-----------|--------|-------------|
| DISCORD_WEBHOOK_URL | Yes | Yes | Discord notifications |
| OPNSENSE_API_KEY | Yes | Yes | DNS automation |
| OPNSENSE_API_SECRET | Yes | Yes | DNS automation |
| AUTHENTIK_TOKEN | Yes | Yes | SSO automation |

---

## Automation Scripts

Located at `/opt/gitlab-runner/scripts/` on 192.168.40.24:

| Script | Purpose |
|--------|---------|
| validate_service.py | Validate service.yml schema |
| generate_playbook.py | Generate Ansible playbook |
| configure_traefik.py | Add Traefik router/service |
| configure_dns.py | Add OPNsense host override |
| register_watchtower.py | Update CONTAINER_HOSTS dict |
| configure_authentik.py | Create Authentik app |
| notify_discord.py | Send success/failure notification |
| rollback_traefik.py | Restore Traefik from backup |
| rollback_container.py | Remove deployed container |

---

## Common Commands

### Check Runner Status

```bash
ssh hermes-admin@192.168.40.24 "sudo gitlab-runner status"
```

### Verify Runner Registration

```bash
ssh hermes-admin@192.168.40.24 "sudo gitlab-runner verify"
```

### Test Ansible Connectivity

```bash
ssh hermes-admin@192.168.40.24 "sudo -u gitlab-runner ansible docker-vm-core-utilities01 -m ping"
```

### View Runner Logs

```bash
ssh hermes-admin@192.168.40.24 "journalctl -u gitlab-runner -f"
```

---

## Rollback

If a deployment fails, use manual rollback jobs in GitLab:

1. Go to pipeline
2. Click "rollback_traefik" or "rollback_container"
3. Click "Play" to execute

Rollback actions:
- **rollback_traefik**: Restores from `traefik_backup.yml` artifact
- **rollback_container**: Runs `docker compose down` on target host

---

## Related Documentation

- [[15 - New Service Onboarding Guide]] - Manual onboarding workflow
- [[09 - Traefik Reverse Proxy]] - Traefik configuration
- [[19 - Watchtower Updates]] - Update Manager integration
- [[11 - Credentials]] - API keys and tokens

---

*Last updated: December 2025*
