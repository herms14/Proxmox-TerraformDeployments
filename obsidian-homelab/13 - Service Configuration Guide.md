# Service Configuration Guide

> **Internal Documentation** - Detailed configuration steps with command explanations.

Related: [[00 - Homelab Index]] | [[07 - Deployed Services]] | [[06 - Ansible Automation]]

---

## Docker Installation

All Docker hosts were configured with the same base installation.

### Ansible Playbook Breakdown

```yaml
- name: Install required packages
  apt:
    name:
      - apt-transport-https  # Enables HTTPS for apt repos
      - ca-certificates      # SSL certificate authorities
      - curl                 # For downloading GPG key
      - gnupg               # For GPG key management
      - lsb-release         # Provides distro info
    state: present
```

**Explanation**: These packages are prerequisites for adding Docker's official repository securely.

```yaml
- name: Add Docker official GPG key
  apt_key:
    url: https://download.docker.com/linux/ubuntu/gpg
    state: present
```

**Explanation**: The GPG key verifies that packages from Docker's repository are authentic and haven't been tampered with.

```yaml
- name: Add Docker repository
  apt_repository:
    repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
    state: present
```

**Explanation**: Adds Docker's official package repository for your Ubuntu version. `ansible_distribution_release` automatically gets the codename (e.g., "jammy" for 22.04).

```yaml
- name: Install Docker packages
  apt:
    name:
      - docker-ce           # Docker Engine
      - docker-ce-cli       # Command-line interface
      - containerd.io       # Container runtime
      - docker-compose-plugin  # Modern Docker Compose
    state: present
    update_cache: yes
```

**Explanation**:
- `docker-ce`: The Community Edition Docker engine
- `docker-ce-cli`: The `docker` command-line tool
- `containerd.io`: Low-level container runtime
- `docker-compose-plugin`: Enables `docker compose` command (v2)

---

## Traefik Reverse Proxy (192.168.40.20)

### Static Configuration (`traefik.yml`)

```yaml
# API and Dashboard
api:
  dashboard: true         # Enable web dashboard
  insecure: true         # Allow HTTP access to dashboard

# Entry Points (ports Traefik listens on)
entryPoints:
  web:
    address: ":80"        # HTTP port
    http:
      redirections:
        entryPoint:
          to: websecure   # Redirect all HTTP to HTTPS
          scheme: https

  websecure:
    address: ":443"       # HTTPS port

# Certificate Resolvers
certificatesResolvers:
  letsencrypt:
    acme:
      email: herms14@gmail.com    # Let's Encrypt notifications
      storage: /certs/acme.json   # Where to store certificates
      dnsChallenge:
        provider: cloudflare       # DNS provider for DNS-01 challenge
        resolvers:
          - "1.1.1.1:53"          # Cloudflare DNS
          - "8.8.8.8:53"          # Google DNS backup
```

**Explanation**:
- **Entry Points**: Define which ports Traefik listens on. Port 80 redirects to 443.
- **DNS Challenge**: Uses Cloudflare API to prove domain ownership for wildcard certificates.
- **acme.json**: Stores the actual SSL certificates.

### Dynamic Configuration (`services.yml`)

```yaml
http:
  routers:
    # Router for Authentik
    authentik:
      rule: "Host(`auth.hrmsmrflrii.xyz`)"   # Match this hostname
      service: authentik                      # Forward to this service
      entryPoints:
        - websecure                           # HTTPS only
      tls:
        certResolver: letsencrypt             # Use Let's Encrypt certs

  services:
    # Backend service definition
    authentik:
      loadBalancer:
        servers:
          - url: "http://192.168.40.21:9000"  # Where to forward traffic
```

**Explanation**:
- **Routers**: Define routing rules (which hostname goes where)
- **Services**: Define the backend servers
- The file auto-reloads when modified (no restart needed)

### Docker Compose (`docker-compose.yml`)

```yaml
services:
  traefik:
    image: traefik:v3.2
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"      # HTTP
      - "443:443"    # HTTPS
      - "8080:8080"  # Dashboard
    environment:
      - CF_API_EMAIL=herms14@gmail.com
      - CF_API_KEY=${CLOUDFLARE_API_KEY}  # From .env file
    volumes:
      - /opt/traefik/config/traefik.yml:/traefik.yml:ro
      - /opt/traefik/config/dynamic:/config:ro
      - /opt/traefik/certs:/certs
```

**Explanation**:
- `restart: unless-stopped`: Automatically restarts after crashes or reboots
- Environment variables provide Cloudflare credentials
- Volumes mount configuration and certificate storage

---

## Arr Media Stack (192.168.40.11)

### NFS Mount for Media Storage

```bash
# /etc/fstab entry
192.168.20.31:/volume2/Proxmox-Media /mnt/media nfs defaults,_netdev 0 0
```

**Explanation**:
- `192.168.20.31`: Synology NAS IP address
- `/volume2/Proxmox-Media`: The NFS export path on the NAS
- `/mnt/media`: Local mount point on the Docker host
- `nfs`: Filesystem type
- `defaults`: Standard mount options (rw, suid, dev, exec, auto, nouser, async)
- `_netdev`: Wait for network before mounting (important for NFS)
- `0 0`: Don't dump or fsck this mount

### Docker Compose for Arr Stack

```yaml
services:
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000        # User ID for file permissions
      - PGID=1000        # Group ID for file permissions
      - TZ=Asia/Manila   # Timezone for logs and scheduling
    volumes:
      - /opt/arr-stack/radarr:/config        # Persistent config
      - /mnt/media/Movies:/movies            # Movie library
      - /mnt/media/Downloads:/downloads      # Download location
    ports:
      - 7878:7878
    restart: unless-stopped
```

**Explanation**:
- **PUID/PGID**: LinuxServer images use these to set file ownership. Use `id` command to find your user's IDs.
- **Config volume**: Stores database, settings, and state
- **Media volumes**: Map to NFS mount for shared storage

### Inter-App Connections

#### Prowlarr to *Arrs

Prowlarr acts as a centralized indexer manager. It was configured to sync with all *Arr apps:

```bash
# Add Radarr to Prowlarr (via API)
curl -X POST "http://localhost:9696/api/v1/applications" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: ${PROWLARR_API_KEY}" \
  -d '{
    "name": "Radarr",
    "syncLevel": "fullSync",
    "implementation": "Radarr",
    "configContract": "RadarrSettings",
    "tags": [],
    "fields": [
      {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
      {"name": "baseUrl", "value": "http://radarr:7878"},
      {"name": "apiKey", "value": "'${RADARR_API_KEY}'"},
      {"name": "syncCategories", "value": [2000,2010,2020,2030,2040,2045,2050,2060]}
    ]
  }'
```

**Explanation**:
- `syncLevel: fullSync`: Prowlarr manages all indexers for this app
- Container names (`radarr`, `prowlarr`) work because they're on the same Docker network
- `syncCategories`: Newznab/Torznab category codes for movies

#### Bazarr to *Arrs

Bazarr was configured via its config file:

```yaml
# /opt/arr-stack/bazarr/config/config.yaml
radarr:
  ip: radarr       # Docker container name (not IP!)
  port: 7878
  apikey: <radarr-api-key>
  ssl: false
```

**Explanation**: Using container names allows Docker's internal DNS to resolve the connection, even if container IPs change.

---

## Authentik Identity Provider (192.168.40.21)

### Why Authentik?

Authentik provides:
- Single Sign-On (SSO) for all services
- OAuth2/OIDC provider
- LDAP server for legacy apps
- Two-factor authentication
- User management

### Docker Compose Components

```yaml
services:
  postgresql:
    image: docker.io/library/postgres:12-alpine
    volumes:
      - database:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${PG_PASS}
      POSTGRES_USER: authentik
      POSTGRES_DB: authentik
```

**Explanation**: PostgreSQL stores all Authentik data (users, applications, sessions).

```yaml
  redis:
    image: docker.io/library/redis:alpine
    command: --save 60 1 --loglevel warning
```

**Explanation**:
- Redis caches sessions and job queues
- `--save 60 1`: Persist to disk every 60 seconds if at least 1 key changed

```yaml
  server:
    image: ghcr.io/goauthentik/server:latest
    command: server
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD: ${PG_PASS}
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY}
    ports:
      - "9000:9000"    # HTTP
      - "9443:9443"    # HTTPS
```

**Explanation**:
- `AUTHENTIK_SECRET_KEY`: Used to encrypt sessions and tokens. Generate with: `openssl rand -base64 32`
- Server handles web UI and API

```yaml
  worker:
    image: ghcr.io/goauthentik/server:latest
    command: worker
```

**Explanation**: Worker handles background tasks (email sending, LDAP sync, etc.)

### Initial Setup

1. Navigate to: `http://192.168.40.21:9000/if/flow/initial-setup/`
2. Create admin account (username: `akadmin`)
3. Configure Google OAuth provider (see [[11 - Credentials]])

---

## Immich Photo Management (192.168.40.22)

### Storage Architecture

```yaml
volumes:
  # Photos stored on NAS (7TB)
  - /mnt/appdata/immich/upload:/usr/src/app/upload

  # Config stored locally (faster)
  - /opt/immich/postgres:/var/lib/postgresql/data
  - /opt/immich/model-cache:/cache
```

**Explanation**:
- Photos go to NAS for long-term storage
- Database stays local for performance
- Model cache stores ML models locally to avoid re-downloading

### Machine Learning Container

```yaml
  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    volumes:
      - /opt/immich/model-cache:/cache
    environment:
      - TRANSFORMERS_CACHE=/cache
```

**Explanation**: This container runs face recognition and object detection. Models are cached to avoid downloading 2GB+ on every restart.

### Database with Vector Support

```yaml
  database:
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
```

**Explanation**: Immich uses pgvecto-rs (PostgreSQL with vector extensions) for similarity searches. This enables "find similar photos" and smart search features.

---

## GitLab CE (192.168.40.23)

### Why GitLab?

- Self-hosted code repository
- CI/CD pipelines
- Container registry
- Wiki and documentation
- Issue tracking

### Docker Compose

```yaml
services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    hostname: 'gitlab.hrmsmrflrii.xyz'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.hrmsmrflrii.xyz'
        gitlab_rails['gitlab_ssh_host'] = 'gitlab.hrmsmrflrii.xyz'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
    volumes:
      - /opt/gitlab/config:/etc/gitlab
      - /opt/gitlab/logs:/var/log/gitlab
      - /opt/gitlab/data:/var/opt/gitlab
    shm_size: '256m'
```

**Explanation**:
- `GITLAB_OMNIBUS_CONFIG`: Inline GitLab configuration
- `shm_size`: Shared memory for PostgreSQL (prevents crashes)
- Port 2222 for SSH to avoid conflict with host SSH

### Getting Initial Password

```bash
docker exec gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

**Warning**: This file is deleted after 24 hours!

---

## n8n Workflow Automation (192.168.40.13)

### Docker Compose

```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=n8n.hrmsmrflrii.xyz
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.hrmsmrflrii.xyz/
      - GENERIC_TIMEZONE=Asia/Manila
    volumes:
      - /opt/n8n/data:/home/node/.n8n
```

**Explanation**:
- `WEBHOOK_URL`: Public URL for webhook triggers
- Volume stores workflows and credentials

### Use Cases

1. **OPNsense DNS Automation**: Automatically add DNS records when VMs are created
2. **Discord Notifications**: Alert on service failures
3. **Backup Monitoring**: Check backup status and alert on failures

---

## Related Documentation

- [[07 - Deployed Services]] - Service URLs
- [[11 - Credentials]] - API keys and passwords
- [[06 - Ansible Automation]] - Deployment playbooks
- [[09 - Traefik Reverse Proxy]] - SSL configuration

