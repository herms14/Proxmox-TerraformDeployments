# New Service Onboarding Guide

> **Internal Documentation** - Complete workflow for adding new services to the homelab.

Related: [[00 - Homelab Index]] | [[07 - Deployed Services]] | [[09 - Traefik Reverse Proxy]] | [[14 - Authentik Google SSO Setup]]

---

## Overview

This guide documents the complete workflow for introducing a new service to the homelab infrastructure. Each new service requires:

1. **Deployment** - Via Ansible playbook or manual Docker
2. **Reverse Proxy** - Traefik routing configuration
3. **DNS** - OPNsense host override
4. **SSL** - Let's Encrypt certificate (automatic via Traefik)
5. **SSO** - Authentik integration (optional)
6. **Documentation** - Update homelab docs

---

## Workflow Diagram

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   1. Deploy     │────▶│  2. Traefik     │────▶│   3. DNS        │
│   Container     │     │  Route          │     │   (OPNsense)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                         │
┌─────────────────┐     ┌─────────────────┐              ▼
│   6. Update     │◀────│  5. Authentik   │◀────┌─────────────────┐
│   Documentation │     │  SSO (Optional) │     │   4. SSL        │
└─────────────────┘     └─────────────────┘     │   (Automatic)   │
                                                └─────────────────┘
```

---

## Step 1: Deploy the Container

### Option A: Ansible Playbook (Recommended)

Create playbook in `~/ansible/<service>/deploy-<service>.yml` on ansible-controller01:

```yaml
---
# <Service> Deployment Playbook
# Usage: ansible-playbook <service>/deploy-<service>.yml

- name: Deploy <Service>
  hosts: docker-vm-core-utilities01  # or docker-vm-media01
  become: yes
  vars:
    service_path: /opt/<service>
    service_port: XXXX

  tasks:
    - name: Create service directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      loop:
        - "{{ service_path }}"
        - "{{ service_path }}/config"
        - "{{ service_path }}/data"

    - name: Create Docker Compose file
      copy:
        dest: "{{ service_path }}/docker-compose.yml"
        content: |
          version: '3.8'
          services:
            <service>:
              image: <image>:<tag>
              container_name: <service>
              restart: unless-stopped
              ports:
                - "{{ service_port }}:<container_port>"
              volumes:
                - {{ service_path }}/config:/config
                - {{ service_path }}/data:/data
              environment:
                - TZ=Asia/Manila
        mode: '0644'

    - name: Deploy container
      community.docker.docker_compose:
        project_src: "{{ service_path }}"
        state: present
        pull: yes

    - name: Wait for service to be ready
      uri:
        url: "http://localhost:{{ service_port }}"
        status_code: [200, 301, 302]
      register: service_status
      until: service_status.status in [200, 301, 302]
      retries: 30
      delay: 2

    - name: Display access info
      debug:
        msg: |
          <Service> deployed!
          Internal: http://{{ ansible_host }}:{{ service_port }}
          External: https://<service>.hrmsmrflrii.xyz (after Traefik config)
```

**Run the playbook:**
```bash
# SSH to ansible-controller01
ssh hermes-admin@192.168.20.30

# Run playbook
ansible-playbook <service>/deploy-<service>.yml
```

### Option B: Manual Docker Deployment

SSH to target host and deploy manually:

```bash
# SSH to target host
ssh hermes-admin@192.168.40.13  # docker-vm-core-utilities01

# Create directories
sudo mkdir -p /opt/<service>/{config,data}

# Deploy container
sudo docker run -d \
  --name <service> \
  --restart unless-stopped \
  -p XXXX:XXXX \
  -v /opt/<service>/config:/config \
  -v /opt/<service>/data:/data \
  -e TZ=Asia/Manila \
  <image>:<tag>

# Verify running
sudo docker ps --filter name=<service>

# Check logs
sudo docker logs <service>
```

### Target Hosts

| Host | IP | Purpose | Use For |
|------|-----|---------|---------|
| docker-vm-core-utilities01 | 192.168.40.13 | Utility services | Dashboards, automation, tools |
| docker-vm-media01 | 192.168.40.11 | Media services | Arr stack, streaming |
| traefik-vm01 | 192.168.40.20 | Reverse proxy | Traefik only |
| authentik-vm01 | 192.168.40.21 | Identity | Authentik only |
| immich-vm01 | 192.168.40.22 | Photos | Immich only |
| gitlab-vm01 | 192.168.40.23 | DevOps | GitLab only |

---

## Step 2: Configure Traefik Reverse Proxy

### Edit Dynamic Configuration

SSH to traefik-vm01 and edit the services file:

```bash
ssh hermes-admin@192.168.40.20
sudo nano /opt/traefik/config/dynamic/services.yml
```

### Add Router Entry

Add under `http.routers:`:

```yaml
    <service>:
      rule: "Host(`<service>.hrmsmrflrii.xyz`)"
      service: <service>
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
```

### Add Service Entry

Add under `http.services:`:

```yaml
    <service>:
      loadBalancer:
        servers:
          - url: "http://<IP>:<PORT>"
```

### Example: Adding OpenSpeedTest

```yaml
# Under routers:
    openspeedtest:
      rule: "Host(`speedtest.hrmsmrflrii.xyz`)"
      service: openspeedtest
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

# Under services:
    openspeedtest:
      loadBalancer:
        servers:
          - url: "http://192.168.40.13:3000"
```

### Verify Configuration

Traefik auto-reloads, but you can restart to force reload:

```bash
# Restart Traefik
cd /opt/traefik && sudo docker compose restart

# Verify route works
curl -sk https://<service>.hrmsmrflrii.xyz
```

---

## Step 3: Configure DNS (OPNsense)

DNS records must point to Traefik (192.168.40.20) for all services.

### Option A: OPNsense Web UI

1. Login to OPNsense: https://192.168.91.30
2. Navigate: **Services** → **Unbound DNS** → **Host Overrides**
3. Click **Add**
4. Configure:
   - **Host**: `<service>`
   - **Domain**: `hrmsmrflrii.xyz`
   - **IP**: `192.168.40.20`
5. Click **Save** → **Apply Changes**

### Option B: Ansible Automation

Set environment variables:
```bash
export OPNSENSE_API_KEY="your-api-key"
export OPNSENSE_API_SECRET="your-api-secret"
```

Run playbook:
```bash
ansible-playbook opnsense/add-dns-record.yml -e "hostname=<service> ip=192.168.40.20"
```

### Verify DNS Resolution

```bash
# From any machine using OPNsense DNS
nslookup <service>.hrmsmrflrii.xyz
# Should return: 192.168.40.20

# Or test directly against OPNsense
nslookup <service>.hrmsmrflrii.xyz 192.168.91.30
```

---

## Step 4: SSL Certificate (Automatic)

SSL is **automatically** handled by Traefik via Let's Encrypt.

### How It Works

1. Traefik detects new route with `tls.certResolver: letsencrypt`
2. Requests wildcard cert via Cloudflare DNS-01 challenge
3. Certificate stored in `/opt/traefik/certs/acme.json`
4. Auto-renewal before expiration

### Verify SSL

```bash
# Check certificate
curl -vI https://<service>.hrmsmrflrii.xyz 2>&1 | grep -i "SSL\|issuer"

# Should show:
# * SSL certificate verify ok.
# * issuer: C=US; O=Let's Encrypt; CN=R3
```

### Manual Certificate Check

```bash
# On traefik-vm01
sudo cat /opt/traefik/certs/acme.json | jq '.letsencrypt.Certificates[].domain'
```

---

## Step 5: Authentik SSO Integration (Optional)

### When to Use SSO

- Services with user authentication
- Dashboard access control
- Centralized login management

### When NOT to Use SSO

- OpenSpeedTest (no auth needed)
- Public services
- Services with API-only access

### Method A: Forward Auth (Most Services)

1. **Create Application in Authentik**

   Navigate to: https://auth.hrmsmrflrii.xyz/if/admin/

   ```
   Applications → Providers → Create → OAuth2/OpenID Provider

   Name: <service>-provider
   Authorization Flow: default-authorization-flow
   Client Type: Confidential
   Redirect URIs: https://<service>.hrmsmrflrii.xyz/outpost.goauthentik.io/callback
   ```

2. **Create Application**

   ```
   Applications → Applications → Create

   Name: <service>
   Slug: <service>
   Provider: <service>-provider
   Launch URL: https://<service>.hrmsmrflrii.xyz
   ```

3. **Add to Outpost**

   ```
   Applications → Outposts → traefik-outpost → Edit

   Add <service> to Applications list
   Save
   ```

4. **Add Authentik Middleware to Traefik**

   Edit `/opt/traefik/config/dynamic/services.yml`:

   ```yaml
   http:
     middlewares:
       authentik:
         forwardAuth:
           address: http://192.168.40.21:9000/outpost.goauthentik.io/auth/traefik
           trustForwardHeader: true
           authResponseHeaders:
             - X-authentik-username
             - X-authentik-groups
             - X-authentik-email
             - X-authentik-name
             - X-authentik-uid

     routers:
       <service>:
         rule: "Host(`<service>.hrmsmrflrii.xyz`)"
         service: <service>
         entryPoints:
           - websecure
         tls:
           certResolver: letsencrypt
         middlewares:
           - authentik  # Add this line
   ```

### Method B: Native OIDC (GitLab, Immich, etc.)

Some services support native OIDC integration. Configure in the service's settings using Authentik as the identity provider.

**Authentik OIDC Endpoints:**
- Authorization: `https://auth.hrmsmrflrii.xyz/application/o/authorize/`
- Token: `https://auth.hrmsmrflrii.xyz/application/o/token/`
- Userinfo: `https://auth.hrmsmrflrii.xyz/application/o/userinfo/`
- JWKS: `https://auth.hrmsmrflrii.xyz/application/o/<app-slug>/jwks/`

---

## Step 6: Update Documentation

### Files to Update

1. **Obsidian Vault** (Internal - Full Details)
   - `07 - Deployed Services.md` - Add service URL and details
   - `10 - IP Address Map.md` - Add port allocation

2. **CLAUDE.md** (Repository - Sanitized)
   - Domain & SSL Configuration section
   - Deployed Docker Services section

3. **GitHub Wiki** (Public - Beginner-Friendly)
   - Services page

### Template for Service Documentation

Add to `07 - Deployed Services.md`:

```markdown
### <Service Name> (<hostname>)

**Status**: ✅ Deployed <Date>

| Property | Value |
|----------|-------|
| VM | docker-vm-core-utilities01 |
| IP:Port | 192.168.40.13:XXXX |
| Internal URL | http://192.168.40.13:XXXX |
| External URL | https://<service>.hrmsmrflrii.xyz |
| Docker Image | <image>:<tag> |
| Config Path | /opt/<service>/ |

**Features:**
- Feature 1
- Feature 2

**Management:**
- Ansible: `~/ansible/<service>/deploy-<service>.yml`
- Docker Compose: `/opt/<service>/docker-compose.yml`
```

---

## Quick Reference: Complete Example

### Deploying OpenSpeedTest

**1. Deploy Container:**
```bash
ssh hermes-admin@192.168.40.13
sudo docker run -d --name openspeedtest --restart unless-stopped \
  -p 3000:3000 openspeedtest/latest
```

**2. Add Traefik Route:**
```yaml
# /opt/traefik/config/dynamic/services.yml

http:
  routers:
    openspeedtest:
      rule: "Host(`speedtest.hrmsmrflrii.xyz`)"
      service: openspeedtest
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

  services:
    openspeedtest:
      loadBalancer:
        servers:
          - url: "http://192.168.40.13:3000"
```

**3. Add DNS Record:**
- Host: `speedtest`
- Domain: `hrmsmrflrii.xyz`
- IP: `192.168.40.20`

**4. SSL:** Automatic via Traefik

**5. SSO:** Not needed (no authentication)

**6. Access:**
- Internal: http://192.168.40.13:3000
- External: https://speedtest.hrmsmrflrii.xyz

---

## Troubleshooting

### Service Not Accessible

1. **Check container is running:**
   ```bash
   docker ps --filter name=<service>
   ```

2. **Check container logs:**
   ```bash
   docker logs <service>
   ```

3. **Verify port is listening:**
   ```bash
   curl -v http://localhost:<port>
   ```

### Traefik Route Not Working

1. **Check config syntax:**
   ```bash
   cat /opt/traefik/config/dynamic/services.yml | docker run -i --rm mikefarah/yq e '.' -
   ```

2. **Check Traefik logs:**
   ```bash
   docker logs traefik 2>&1 | tail -50
   ```

3. **Restart Traefik:**
   ```bash
   cd /opt/traefik && docker compose restart
   ```

### DNS Not Resolving

1. **Check OPNsense config:**
   - Services → Unbound DNS → Host Overrides

2. **Test DNS resolution:**
   ```bash
   nslookup <service>.hrmsmrflrii.xyz 192.168.91.30
   ```

3. **Restart Unbound:**
   - Services → Unbound DNS → Restart

### SSL Certificate Issues

1. **Check Traefik logs for ACME errors:**
   ```bash
   docker logs traefik 2>&1 | grep -i acme
   ```

2. **Verify Cloudflare API token is valid**

3. **Check acme.json permissions:**
   ```bash
   ls -la /opt/traefik/certs/acme.json
   # Should be 600
   ```

---

## Port Allocation Reference

| Port Range | Purpose |
|------------|---------|
| 80, 443 | Traefik (HTTP/HTTPS) |
| 2283 | Immich |
| 3000-3999 | Utility tools |
| 5055-5678 | Request managers, automation |
| 6767-6999 | Subtitle services |
| 7474-7999 | Download automation |
| 8000-8999 | Web applications, dashboards |
| 9000-9999 | Management, indexers |

---

*Last updated: December 2025*
