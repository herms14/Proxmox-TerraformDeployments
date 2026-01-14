---
tags:
  - homelab
  - gitops
  - gitlab
  - troubleshooting
created: 2025-12-30
updated: 2025-12-30
status: active
---

# GitOps Pipeline Troubleshooting

A guide to diagnosing and resolving issues with the homelab GitOps pipeline.

---

## Quick Error Reference

| Error Code | Likely Cause | First Step |
|------------|--------------|------------|
| `config error` | Pipeline rules don't match branch | Check branch name in rules |
| `403` | Repository access denied | Change visibility to Internal |
| `Permission denied` | Missing sudo or wrong user | Add sudo prefix |
| `Port allocated` | Port conflict | Choose different port |
| `Pull access denied` | Invalid image name | Verify image exists |
| `Connection refused` | Service not running | Check container logs |
| `401 Unauthorized` | Invalid API token | Regenerate token |
| `No space left` | Disk full | Run docker prune |

---

## Pipeline Configuration Errors

### Error: "Pipeline: config error" with 0 Jobs

**Symptoms:**
```
Pipeline: config error
This GitLab CI configuration is invalid:
jobs config should contain at least one visible job
```

**Cause:** Pipeline rules only matched `main` branch but you pushed to `master`.

**Solution:**
```yaml
# Update rules to support both branches
.default-rules:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "master"
    - if: $CI_PIPELINE_SOURCE == "web"
```

---

### Error: YAML Parsing Error

**Symptoms:**
```
Error: mapping values are not allowed in this context at line 109
```

**Cause:** Inline Python code with colons being parsed as YAML mappings.

**Solution:** Extract inline Python to separate script files:
```yaml
# Fixed - reference external script
script:
  - python3 scripts/show_plan.py
```

---

## Repository Access Errors

### Error: "You are not allowed to download code"

**Symptoms:**
```
remote: You are not allowed to download code from this project.
The requested URL returned error: 403
```

**Solution:**
1. Go to GitLab → Project → Settings → General
2. Change "Project visibility" from "Private" to "Internal"
3. Save changes

---

## Deployment Errors

### Error: "Permission denied"

**Symptoms:**
```
mkdir: cannot create directory '/opt/metube': Permission denied
```

**Cause:** Non-root user attempting to create directories without sudo.

**Solution:** Update deploy script to use sudo:
```python
sudo_prefix = '' if user == 'root' else 'sudo '
cmd = f'{sudo_prefix}mkdir -p {install_path}'
```

---

### Error: "Port is already allocated"

**Symptoms:**
```
Bind for 0.0.0.0:8081 failed: port is already allocated
```

**Solution:**
1. Find what's using the port:
```bash
ssh hermes-admin@192.168.40.11 "docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep 8081"
```

2. Choose a different port in your service YAML:
```yaml
deployment:
  port: 8082              # Changed from 8081
  container_port: 8081    # Internal port stays the same
```

---

## Network and DNS Errors

### Error: "DNS record creation failed"

**Cause:** Pi-hole API password incorrect or Pi-hole not reachable.

**Solution:**
1. Verify Pi-hole is accessible:
```bash
curl -s http://192.168.90.53/admin/api.php?version
```

2. Check API password in GitLab CI/CD variables

---

### Error: "Service not accessible via Traefik"

**Symptoms:**
- Direct access works: `curl http://192.168.40.11:8082` ✓
- Traefik access fails: `curl https://metube.hrmsmrflrii.xyz` ✗

**Solution:**
1. Check Traefik dashboard for the route
2. Verify DNS resolution:
```bash
nslookup metube.hrmsmrflrii.xyz
# Should return 192.168.40.20
```
3. Check Traefik logs:
```bash
ssh hermes-admin@192.168.40.20 "docker logs traefik --tail 50"
```

---

## Authentication Errors

### Error: "Authentik provider creation failed"

**Cause:** Invalid or expired API token.

**Solution:**
1. Regenerate Authentik API token at https://auth.hrmsmrflrii.xyz
2. Update GitLab CI/CD variable `AUTHENTIK_TOKEN`

---

## Quick Diagnostics

### Check Pipeline Status
```bash
# Visit GitLab UI
https://gitlab.hrmsmrflrii.xyz/homelab/homelab-services/-/pipelines
```

### Check Container Status
```bash
ssh hermes-admin@192.168.40.11 "docker ps -a"
ssh hermes-admin@192.168.40.11 "docker inspect metube | jq '.[0].State'"
```

### Check Service Connectivity
```bash
# Direct access
curl -I http://192.168.40.11:8082

# Via Traefik
curl -I https://metube.hrmsmrflrii.xyz

# DNS resolution
nslookup metube.hrmsmrflrii.xyz
```

### Check Logs
```bash
# Container logs
ssh hermes-admin@<host> "docker logs <container> --tail 100"

# Traefik logs
ssh hermes-admin@192.168.40.20 "docker logs traefik --tail 100"

# GitLab runner logs
journalctl -u gitlab-runner -f
```

### Verify Configuration Files
```bash
# Docker compose file
ssh hermes-admin@<host> "cat /opt/<service>/docker-compose.yml"

# Traefik routes
ssh hermes-admin@192.168.40.20 "cat /opt/traefik/config/dynamic/services.yml"

# Glance config
ssh root@192.168.40.12 "cat /opt/glance/config/glance.yml"
```

---

## Common Root Causes

Most pipeline failures are due to:
1. **Branch name mismatches** - Check pipeline rules
2. **Missing credentials/tokens** - Check GitLab CI/CD variables
3. **Port conflicts** - Check existing containers
4. **Permission issues** - Add sudo prefix

Always check these first!

---

## Related Documents

- [[32 - GitOps Architecture]] - Architecture overview
- [[33 - GitOps Pipeline Walkthrough]] - Pipeline details
- [[34 - GitOps Deployment Tutorial]] - Deployment guide

---

*Last updated: December 30, 2025*
