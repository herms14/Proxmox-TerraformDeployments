---
tags:
  - todo
  - homelab
  - networking
  - security
created: 2025-12-23
status: pending
---

# TODO: Expose Jellyfin & Jellyseerr to Internet via Cloudflare Tunnel

> Securely expose media services to the internet without port forwarding using Cloudflare Tunnel.

## Related Documents

- [[00 - Homelab Index]]
- [[08 - Arr Media Stack]]
- [[09 - Traefik Reverse Proxy]]

---

## Why Cloudflare Tunnel?

| Feature | Benefit |
|---------|---------|
| No port forwarding | Firewall stays closed, no exposed ports |
| DDoS protection | Cloudflare absorbs attacks |
| Hidden IP | Your public IP is never exposed |
| Free tier | Works perfectly for homelab use |
| Easy setup | Single container deployment |

---

## Architecture

```
Internet Users
      │
      ▼
Cloudflare Edge (DDoS protection, SSL)
      │
      ▼ (Encrypted tunnel)
cloudflared container (192.168.40.13)
      │
      ▼
Traefik (192.168.40.20) ─── Authentik SSO
      │
      ├── Jellyfin (192.168.40.11:8096)
      └── Jellyseerr (192.168.40.11:5056)
```

---

## Tasks

### Step 1: Cloudflare DNS Setup
- [ ] Create Cloudflare account (https://dash.cloudflare.com/sign-up)
- [ ] Add domain `hrmsmrflrii.xyz` to Cloudflare
- [ ] Note the Cloudflare nameservers provided
- [ ] Log into GoDaddy → My Domains → hrmsmrflrii.xyz
- [ ] Change nameservers from "Default" to "Custom"
- [ ] Enter Cloudflare nameservers
- [ ] Wait for DNS propagation (5-30 minutes)
- [ ] Verify domain is active in Cloudflare dashboard

### Step 2: Create Cloudflare Tunnel
- [ ] Go to Cloudflare Dashboard → Zero Trust
- [ ] Navigate to Networks → Tunnels
- [ ] Click "Create a tunnel"
- [ ] Select "Cloudflared" connector type
- [ ] Name: `homelab-tunnel`
- [ ] Copy the tunnel token (save securely!)

### Step 3: Deploy cloudflared Container
- [ ] SSH to docker-vm-core-utilities01 (192.168.40.13)
- [ ] Create directory: `/opt/cloudflared/`
- [ ] Create docker-compose.yml with tunnel token
- [ ] Deploy container: `docker compose up -d`
- [ ] Verify tunnel shows "Healthy" in Cloudflare dashboard

### Step 4: Configure Tunnel Routes
In Cloudflare Zero Trust → Tunnels → homelab-tunnel → Public Hostnames:

- [ ] Add route: `jellyfin.hrmsmrflrii.xyz` → `http://192.168.40.11:8096`
- [ ] Add route: `jellyseerr.hrmsmrflrii.xyz` → `http://192.168.40.11:5056`
- [ ] Test external access to both services

### Step 5: Configure Authentik SSO for Jellyseerr
- [ ] Create Proxy Provider in Authentik for Jellyseerr
- [ ] Create Application linked to provider
- [ ] Assign provider to Embedded Outpost
- [ ] Update Traefik ForwardAuth middleware
- [ ] Test SSO login flow

### Step 6: Documentation
- [ ] Update [[08 - Arr Media Stack]] with external access info
- [ ] Update docs/SERVICES.md with Cloudflare Tunnel config
- [ ] Add to GitHub wiki

---

## Configuration Reference

### docker-compose.yml (cloudflared)

```yaml
# Location: /opt/cloudflared/docker-compose.yml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=<paste-your-token-here>
    networks:
      - cloudflared

networks:
  cloudflared:
    driver: bridge
```

### Tunnel Routes to Configure

| Public Hostname | Service | Internal URL |
|-----------------|---------|--------------|
| jellyfin.hrmsmrflrii.xyz | Jellyfin | http://192.168.40.11:8096 |
| jellyseerr.hrmsmrflrii.xyz | Jellyseerr | http://192.168.40.11:5056 |

---

## Security Considerations

> [!warning] Important Security Notes
> - Jellyfin has its own authentication - users create accounts
> - Jellyseerr will be protected by Authentik SSO
> - Consider enabling Cloudflare Access policies for additional protection
> - Monitor access logs in Cloudflare dashboard

---

## Verification Checklist

After setup, verify:
- [ ] `jellyfin.hrmsmrflrii.xyz` accessible from phone (not on home WiFi)
- [ ] `jellyseerr.hrmsmrflrii.xyz` redirects to Authentik login
- [ ] Tunnel shows "Healthy" in Cloudflare dashboard
- [ ] No ports exposed on OPNsense firewall

---

## Rollback Plan

If issues occur:
1. Delete tunnel in Cloudflare dashboard
2. Stop cloudflared container: `docker compose down`
3. Revert GoDaddy nameservers to default (if needed)
4. Services remain accessible internally via Traefik

---

*Created: December 23, 2025*
