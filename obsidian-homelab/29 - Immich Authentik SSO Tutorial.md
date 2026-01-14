# Immich + Authentik SSO Tutorial

> Setting up OAuth authentication for Immich using Authentik as the identity provider.

Related: [[14 - Authentik Google SSO Setup]] | [[26 - Tutorials Index]] | [[07 - Deployed Services]]

---

## Overview

This tutorial explains how to integrate Immich (self-hosted photo management) with Authentik for Single Sign-On (SSO) authentication.

### Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          USER BROWSER                             │
│  1. Visit Immich → 2. Click "Login with Authentik" →             │
│  3. Redirect to Authentik → 4. Authenticate →                    │
│  5. Redirect back to Immich with token                           │
└──────────────────────────────────────────────────────────────────┘
                    │                               ▲
                    ▼                               │
┌──────────────────────────────────────────────────────────────────┐
│  AUTHENTIK (192.168.40.21:9000)                                  │
│  https://auth.hrmsmrflrii.xyz                                    │
│                                                                  │
│  • OAuth2/OpenID Connect Provider                                │
│  • Issues access tokens and ID tokens                            │
│  • Provides user info endpoint                                   │
└──────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│  IMMICH (192.168.40.22:2283)                                     │
│  https://photos.hrmsmrflrii.xyz                                  │
│                                                                  │
│  • Receives OAuth tokens                                         │
│  • Creates/links user accounts                                   │
│  • Grants photo access                                           │
└──────────────────────────────────────────────────────────────────┘
```

---

## Quick Setup

### Step 1: Create OAuth Provider in Authentik

1. Login to Authentik Admin: https://auth.hrmsmrflrii.xyz/if/admin/
2. Go to **Applications** → **Providers** → **Create**
3. Select **OAuth2/OpenID Provider**
4. Configure:
   - **Name**: `immich-oauth-provider`
   - **Authorization flow**: `default-provider-authorization-explicit-consent`
   - **Client type**: `Confidential`
   - **Client ID**: `immich-oauth-client` (or generate)
   - **Client Secret**: Generate and save!
   - **Redirect URIs**: `https://photos.hrmsmrflrii.xyz/auth/login`
   - **Scopes**: `openid email profile`

### Step 2: Create Authentik Application

1. Go to **Applications** → **Applications** → **Create**
2. Configure:
   - **Name**: `Immich`
   - **Slug**: `immich`
   - **Provider**: Select `immich-oauth-provider`
   - **Launch URL**: `https://photos.hrmsmrflrii.xyz`

### Step 3: Configure Immich OAuth

SSH to Immich VM and update the database:

```bash
ssh hermes-admin@192.168.40.22

# Enter PostgreSQL container
docker exec -it immich_postgres psql -U postgres -d immich

# Update OAuth settings
UPDATE system_config SET value = 'true' WHERE key = 'oauth.enabled';
UPDATE system_config SET value = 'immich-oauth-client' WHERE key = 'oauth.clientId';
UPDATE system_config SET value = 'YOUR_CLIENT_SECRET' WHERE key = 'oauth.clientSecret';
UPDATE system_config SET value = 'https://auth.hrmsmrflrii.xyz/application/o/immich/' WHERE key = 'oauth.issuerUrl';
UPDATE system_config SET value = 'openid email profile' WHERE key = 'oauth.scope';
UPDATE system_config SET value = 'Login with Authentik' WHERE key = 'oauth.buttonText';
UPDATE system_config SET value = 'true' WHERE key = 'oauth.autoRegister';

# Exit
\q
```

### Step 4: Restart Immich

```bash
cd /opt/immich && docker compose restart immich-server
```

### Step 5: Test Login

1. Visit https://photos.hrmsmrflrii.xyz
2. Click "Login with Authentik"
3. Authenticate with Authentik credentials
4. Should be redirected back and logged in!

---

## OAuth Credentials

Store in [[11 - Credentials]]:

| Field | Value |
|-------|-------|
| Client ID | `immich-oauth-client` |
| Client Secret | `immich-oauth-secret-homelab-2024` |
| Issuer URL | `https://auth.hrmsmrflrii.xyz/application/o/immich/` |
| Scopes | `openid email profile` |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Invalid redirect URI" | Check redirect URI matches exactly in Authentik |
| "Client authentication failed" | Verify client secret is correct |
| User not created | Ensure `oauth.autoRegister` is `true` |

---

## Full Tutorial

For complete step-by-step guide with detailed explanations:
- **GitHub**: `docs/IMMICH_AUTHENTIK_SSO_TUTORIAL.md`

---

## Related Documentation

- [[14 - Authentik Google SSO Setup]] - Google OAuth setup
- [[09 - Traefik Reverse Proxy]] - Traefik configuration
- [[07 - Deployed Services]] - All services
