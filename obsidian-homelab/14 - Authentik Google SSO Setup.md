# Authentik Google SSO Setup

> **Internal Documentation** - Google OAuth configuration for single sign-on.

Related: [[00 - Homelab Index]] | [[07 - Deployed Services]] | [[11 - Credentials]]

---

## Overview

Configure Google as an identity provider in Authentik to enable single sign-on (SSO) across all homelab services using your Google account: **herms14@gmail.com**

---

## Step 1: Create Google OAuth Credentials

### Access Google Cloud Console

1. Navigate to: https://console.cloud.google.com/apis/credentials
2. Sign in with: `hrmsmrflrii@gmail.com`
3. Select or create a project (e.g., "Homelab SSO")

### Create OAuth 2.0 Client

1. Click **Create Credentials** → **OAuth 2.0 Client ID**
2. Select **Web application**
3. Configure:

| Field                         | Value                                                        |
| ----------------------------- | ------------------------------------------------------------ |
| Name                          | Authentik Homelab                                            |
| Authorized JavaScript origins | `https://auth.hrmsmrflrii.xyz`                               |
| Authorized redirect URIs      | `https://auth.hrmsmrflrii.xyz/source/oauth/callback/google/` |

4. Click **Create**
5. Save the **Client ID** and **Client Secret**

### Store Credentials

Add to [[11 - Credentials ]]:



```
### Google OAuth (Authentik SSO)
| Field | Value |
|-------|-------|
| Client ID | <your-client-id>.apps.googleusercontent.com |
| Client Secret | <your-client-secret> |
```

---

## Step 2: Configure Authentik

### Access Authentik Admin

1. Navigate to: https://auth.hrmsmrflrii.xyz/if/admin/
2. Login with admin account

### Add Google OAuth Source

1. Go to **Directory** → **Federation & Social Login** → **Sources**
2. Click **Create**
3. Select **OAuth Source**
4. Configure:

| Field | Value |
|-------|-------|
| Name | google |
| Slug | google |
| Provider Type | Google |
| Consumer Key | Your Google Client ID |
| Consumer Secret | Your Google Client Secret |
| User Matching Mode | Email (deny creation if email exists) |

5. Enable **Enabled** toggle
6. Click **Create**

### Verify Google Source

1. Go to **Directory** → **Federation & Social Login** → **Sources**
2. Click on **google**
3. Note the **Callback URL**: `https://auth.hrmsmrflrii.xyz/source/oauth/callback/google/`
4. This should match your Google OAuth redirect URI

---

## Step 3: Create Applications for Each Service

For each service you want to protect with SSO:

### Create OAuth2 Provider

1. Go to **Applications** → **Providers**
2. Click **Create**
3. Select **OAuth2/OpenID Provider**
4. Configure:

| Field | Value |
|-------|-------|
| Name | `<service>-provider` |
| Authorization Flow | default-authentication-flow |
| Client Type | Confidential |
| Client ID | Auto-generated |
| Redirect URIs | `https://<service>.hrmsmrflrii.xyz/oauth2/callback` |

### Create Application

1. Go to **Applications** → **Applications**
2. Click **Create**
3. Configure:

| Field | Value |
|-------|-------|
| Name | `<service>` |
| Slug | `<service>` |
| Provider | Select the provider created above |
| Launch URL | `https://<service>.hrmsmrflrii.xyz` |

---

## Step 4: Configure Traefik Forward Auth

### Add Authentik Forward Auth Middleware

Edit `/opt/traefik/config/dynamic/services.yml` on traefik-vm01:

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
          - X-authentik-jwt
          - X-authentik-meta-jwks
          - X-authentik-meta-outpost
          - X-authentik-meta-provider
          - X-authentik-meta-app
          - X-authentik-meta-version

  routers:
    # Example: Protect Radarr with Authentik
    radarr:
      rule: "Host(`radarr.hrmsmrflrii.xyz`)"
      service: radarr
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
      middlewares:
        - authentik  # Add this line to protect with SSO
```

---

## Step 5: Create Embedded Outpost

1. Go to **Applications** → **Outposts**
2. Click **Create**
3. Configure:

| Field | Value |
|-------|-------|
| Name | traefik-outpost |
| Type | Proxy |
| Integration | Embedded Outpost |

4. Add all applications to the outpost

---

## Services to Protect

| Service | URL | Status |
|---------|-----|--------|
| Proxmox | https://proxmox.hrmsmrflrii.xyz | Configure |
| Traefik | https://traefik.hrmsmrflrii.xyz | Configure |
| Jellyfin | https://jellyfin.hrmsmrflrii.xyz | Configure |
| Radarr | https://radarr.hrmsmrflrii.xyz | Configure |
| Sonarr | https://sonarr.hrmsmrflrii.xyz | Configure |
| Prowlarr | https://prowlarr.hrmsmrflrii.xyz | Configure |
| GitLab | https://gitlab.hrmsmrflrii.xyz | Native OIDC |
| Immich | https://photos.hrmsmrflrii.xyz | Native OIDC |
| n8n | https://n8n.hrmsmrflrii.xyz | Configure |
| Portainer | https://portainer.hrmsmrflrii.xyz | Configure |
| Glance | https://glance.hrmsmrflrii.xyz | Configure |

---

## Automation

Use the Ansible playbook to automate configuration:

```bash
# From ansible-controller01
export GOOGLE_CLIENT_ID="your-client-id"
export GOOGLE_CLIENT_SECRET="your-client-secret"
export AUTHENTIK_TOKEN="your-api-token"

ansible-playbook authentik/configure-google-sso.yml
```

---

## Troubleshooting

### "Invalid redirect URI" error

Ensure the redirect URI in Google Cloud Console exactly matches:
`https://auth.hrmsmrflrii.xyz/source/oauth/callback/google/`

### "User not found" error

Check User Matching Mode in the Google source:
- **Email (deny creation)**: User must exist in Authentik
- **Email (create on demand)**: User is created automatically

### Forward auth not working

1. Verify outpost is running
2. Check Traefik can reach Authentik: `curl http://192.168.40.21:9000/outpost.goauthentik.io/ping`
3. Check Traefik logs for auth errors

---

## Related Documentation

- [[07 - Deployed Services]] - Service URLs
- [[09 - Traefik Reverse Proxy]] - Middleware configuration
- [[11 - Credentials]] - OAuth credentials storage

