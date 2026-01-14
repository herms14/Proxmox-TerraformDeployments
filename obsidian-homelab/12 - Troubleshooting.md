# Troubleshooting

> **Internal Documentation** - Diagnostic commands and resolution steps organized by category.

Related: [[00 - Homelab Index]] | [[02 - Proxmox Cluster]] | [[01 - Network Architecture]]

---

## Table of Contents

- [[#Proxmox Cluster Issues]]
- [[#Kubernetes Issues]]
- [[#Authentication Issues]]
- [[#Container & Docker Issues]]
- [[#Service-Specific Issues]]
- [[#Network Issues]]
- [[#Common Issues]]
- [[#Diagnostic Commands]]

---

## Proxmox Cluster Issues

### Corosync SIGSEGV Crash

**Resolved**: December 2025

**Symptoms**:
- `corosync.service` fails with `status=11/SEGV`
- Logs stop at: `Initializing transport (Kronosnet)`
- Node cannot join cluster

**Root Cause**: Broken NSS crypto stack (`libnss3`).

**Resolution**:
```bash
apt install --reinstall -y \
  libnss3 libnss3-tools \
  libknet1t64 libnozzle1t64 \
  corosync libcorosync-common4
```

**Verification**:
```bash
systemctl start corosync
pvecm status
journalctl -u corosync | grep crypto_nss
```

---

### Node Showing Question Mark

**Resolved**: December 2025

**Symptoms**:
- Question mark icon in Proxmox UI
- "NR" (Not Ready) status

**Diagnosis**:
```bash
ping 192.168.20.22
ssh root@192.168.20.22 "pvecm status"
```

**Resolution**:
1. Power on node if shutdown
2. Restart cluster services:
   ```bash
   systemctl restart pve-cluster && systemctl restart corosync
   ```

---

### Cloud-init VM Boot Failure

**Resolved**: December 2025

**Symptoms**:
- Console stops at: `Btrfs loaded, zoned=yes, fsverity=yes`
- VM unreachable via SSH/ping

**Root Cause**: UEFI/BIOS boot mode mismatch.

**Resolution**: Updated `modules/linux-vm/main.tf`:
```hcl
bios    = "ovmf"
machine = "q35"

efidisk {
  storage           = var.storage
  efitype           = "4m"
  pre_enrolled_keys = true
}

scsihw = "virtio-scsi-single"
```

---

## Kubernetes Issues

### kubectl Connection Refused

**Resolved**: December 20, 2025

**Symptoms**: On non-primary controllers (controller02, controller03):
```
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

**Root Cause**: Kubeconfig not set up on secondary controller nodes after `kubeadm join`.

**Fix**:
```bash
ssh hermes-admin@192.168.20.32 "cat ~/.kube/config" | ssh hermes-admin@192.168.20.33 "mkdir -p ~/.kube && cat > ~/.kube/config && chmod 600 ~/.kube/config"
ssh hermes-admin@192.168.20.32 "cat ~/.kube/config" | ssh hermes-admin@192.168.20.34 "mkdir -p ~/.kube && cat > ~/.kube/config && chmod 600 ~/.kube/config"
```

**Verification**:
```bash
for ip in 192.168.20.32 192.168.20.33 192.168.20.34; do
  echo "=== $ip ==="
  ssh hermes-admin@$ip "kubectl get nodes --no-headers | head -3"
done
```

**Prevention**: Add kubeconfig distribution to Kubernetes Ansible playbook.

---

## Authentication Issues

### Authentik ForwardAuth "Not Found" Error

**Resolved**: December 21, 2025

**Symptoms**: When accessing services protected by Authentik ForwardAuth (Grafana, Prometheus, Jaeger), users receive a "not found" error instead of being redirected to login.

**Root Cause**: The Authentik **Embedded Outpost had no providers assigned**. Proxy providers and applications were created, but never bound to the outpost that handles ForwardAuth requests from Traefik.

**Diagnosis**:
```bash
ssh hermes-admin@192.168.40.21 "sudo docker exec authentik-server ak shell -c \"
from authentik.outposts.models import Outpost
outpost = Outpost.objects.get(name='authentik Embedded Outpost')
print(f'Providers: {list(outpost.providers.values_list(\"name\", flat=True))}')
\""
# Empty list = problem
```

**Fix**:
```bash
ssh hermes-admin@192.168.40.21 "sudo docker exec authentik-server ak shell -c \"
from authentik.providers.proxy.models import ProxyProvider
from authentik.outposts.models import Outpost

providers = list(ProxyProvider.objects.all())
outpost = Outpost.objects.get(name='authentik Embedded Outpost')
for p in providers:
    outpost.providers.add(p)
outpost.save()
print(f'Added {len(providers)} providers to outpost')
\""
```

**Verification**:
```bash
# Should return 302 (redirect to login)
curl -s -k -o /dev/null -w "%{http_code}" https://grafana.hrmsmrflrii.xyz
```

**Prevention**:
1. Always assign new providers to the Embedded Outpost in Authentik Admin UI
2. Include outpost assignment in blueprints
3. Verify outpost has providers assigned before testing

---

### Authentik "Permission Denied - Internal Users Only"

**Resolved**: December 24, 2025

**Symptoms**: User logs in via Google/GitHub OAuth and sees "Permission denied - Interface can only be accessed by internal users"

**Root Cause**: OAuth sources create users with `type=external` by default. The Authentik Admin Interface (`/if/admin/`) is restricted to internal users by design.

> [!info] User Type Behavior
> | User Type | App Access | Admin UI Access |
> |-----------|------------|-----------------|
> | `internal` | ✅ Yes | ✅ Yes |
> | `external` | ✅ Yes | ❌ No |
>
> **External users CAN access regular apps** (Grafana, Jellyfin, etc.) - this restriction only applies to the Authentik Admin Interface.

**This is expected behavior** - most OAuth users should remain `external`. Only change to `internal` if admin access is specifically needed.

**Diagnosis** (check user types):
```bash
ssh hermes-admin@192.168.40.21 "sudo docker exec authentik-server ak shell -c \"
from authentik.core.models import User
for u in User.objects.all():
    print(f'{u.username}: type={u.type}')
\""
```

**Fix** (only if admin access is required):
```bash
ssh hermes-admin@192.168.40.21 "sudo docker exec authentik-server ak shell -c \"
from authentik.core.models import User
user = User.objects.get(username='USERNAME_HERE')
user.type = 'internal'
user.save()
print(f'Changed {user.username} to internal')
\""
```

---

### GitLab SSO "Failed to open tcp connection" (DNS Resolution)

**Resolved**: December 24, 2025

**Symptoms**: Clicking "Authentik" SSO button on GitLab login page shows:
```
Could not authenticate you from OpenIDConnect because "Failed to open tcp connection to auth.hrmsmrflrii.xyz:443 (getaddrinfo: name or service not known)".
```

**Root Cause**: GitLab VM had incorrect DNS configuration. Netplan was configured with DNS server `192.168.20.1` instead of `192.168.91.30` (OPNsense). The VM couldn't resolve internal domain names.

**Diagnosis**:
```bash
# Check DNS resolution from GitLab VM
ssh hermes-admin@192.168.40.23 "nslookup auth.hrmsmrflrii.xyz"
# Returns: NXDOMAIN = DNS misconfigured

# Check current DNS configuration
ssh hermes-admin@192.168.40.23 "resolvectl status | grep 'DNS Server'"
```

**Fix**:
```bash
# Update netplan DNS to correct server
ssh hermes-admin@192.168.40.23 "sudo sed -i 's/192.168.20.1/192.168.91.30/g' /etc/netplan/50-cloud-init.yaml"

# Apply changes
ssh hermes-admin@192.168.40.23 "sudo netplan apply"

# Verify DNS now works
ssh hermes-admin@192.168.40.23 "nslookup auth.hrmsmrflrii.xyz"
# Should return: 192.168.40.20 (Traefik IP)
```

**Verification**:
```bash
# Test from Docker container
ssh hermes-admin@192.168.40.23 "docker exec gitlab nslookup auth.hrmsmrflrii.xyz"
```

> [!tip] Prevention
> Ensure all VLAN 40 VMs use DNS `192.168.91.30` (OPNsense). Check Terraform `nameserver` variable in `main.tf` vm_groups.

---

### GitLab SSO "Invalid client" (Client Secret Mismatch)

**Resolved**: December 24, 2025

**Symptoms**: After fixing DNS, clicking "Authentik" SSO button shows:
```
Could not authenticate you from OpenIDConnect because "Invalid client :: client authentication failed (e.g., unknown client, no client authentication included, or unsupported authentication method)".
```

**Root Cause**: The client secret in GitLab's docker-compose.yml was truncated/incorrect:
- Wrong character: `Jtz41sHn` (digit "1") instead of `Jtz4lsHn` (lowercase "L")
- Truncated: Missing the second half of the secret string

**Diagnosis**:
```bash
# Get correct secret from Authentik database
ssh hermes-admin@192.168.40.21 "docker exec authentik-postgres psql -U authentik -d authentik -c \"
SELECT p.name, o.client_id, o.client_secret
FROM authentik_core_provider p
JOIN authentik_providers_oauth2_oauth2provider o ON p.id = o.provider_ptr_id
WHERE p.name ILIKE '%gitlab%';\""

# Compare with GitLab config
ssh hermes-admin@192.168.40.23 "grep 'secret:' /opt/gitlab/docker-compose.yml"
```

**Fix**:
```bash
# Update GitLab docker-compose.yml with correct secret
ssh hermes-admin@192.168.40.23 "sudo nano /opt/gitlab/docker-compose.yml"
# Fix the 'secret:' value to match Authentik database

# Restart GitLab (takes 2-3 minutes to initialize)
ssh hermes-admin@192.168.40.23 "cd /opt/gitlab && sudo docker compose down && sudo docker compose up -d"
```

**Verification**:
1. Navigate to https://gitlab.hrmsmrflrii.xyz
2. Click "Authentik" button
3. Complete Authentik login
4. Should redirect back to GitLab logged in

> [!warning] Prevention
> When copying OAuth secrets:
> - Verify full string length matches
> - Watch for "1" (one) vs "l" (lowercase L) confusion
> - Test OIDC immediately after configuration

---

### Jellyfin SSO Button Not Showing on Login Page

**Resolved**: December 24, 2025

**Symptoms**: Jellyfin login page shows only username/password fields, no "Sign in with Authentik" button despite SSO-Auth plugin being installed.

**Root Cause**: SSO-Auth plugin does not automatically add a login button. It must be manually added via Branding settings.

**Fix**:
1. Go to Dashboard → General → Branding
2. In "Login disclaimer" field, add:
```html
<a href="/sso/OID/start/authentik" style="display: block; width: 100%; padding: 12px; margin-top: 10px; background-color: #00a4dc; color: white; text-align: center; text-decoration: none; border-radius: 4px; font-weight: bold;">Sign in with Authentik</a>
```
3. Click Save

**Verification**: Refresh login page - button should appear below password field.

---

### Jellyfin SSO invalid_grant Error

**Resolved**: December 24, 2025

**Symptoms**: After Authentik login, redirected back with:
```
Error logging in: Error redeeming code: invalid_grant
The provided authorization grant or refresh token is invalid...
```

**Root Cause**: Scheme mismatch. Jellyfin behind reverse proxy generates HTTP redirect URIs, but authorization was done with HTTPS.

**Fix**:
1. Go to Dashboard → Plugins → SSO-Auth → Settings
2. Select provider and click "Load Provider"
3. Set **Scheme Override** to `https`
4. Click "Save Provider"
5. Restart Jellyfin: `docker restart jellyfin`

**Verification**: Test SSO login - should complete successfully.

> [!tip] Prevention
> Always configure Scheme Override to `https` for services behind TLS-terminating reverse proxies.

---

### Jellyseerr OIDC Not Working with Latest Image

**Resolved**: December 24, 2025

**Symptoms**:
- OIDC environment variables configured but no SSO button appears
- API shows `openIdProviders: []` (empty array)
- No errors in logs, OIDC just silently not working

**Root Cause**: The `latest` Jellyseerr image does not include native OIDC support. OIDC is only available in the `preview-OIDC` branch image.

**Diagnosis**:
```bash
# Check current image
ssh hermes-admin@192.168.40.11 "docker inspect jellyseerr --format='{{.Config.Image}}'"

# Check API for OIDC providers
ssh hermes-admin@192.168.40.11 "curl -s http://localhost:5056/api/v1/settings/public | jq '.openIdProviders'"
```

**Resolution**:
```bash
# Update docker-compose.yml to use preview-OIDC image
ssh hermes-admin@192.168.40.11 "sudo sed -i 's|fallenbagel/jellyseerr:latest|fallenbagel/jellyseerr:preview-OIDC|' /opt/arr-stack/docker-compose.yml"

# Recreate container
ssh hermes-admin@192.168.40.11 "cd /opt/arr-stack && sudo docker compose up -d --force-recreate jellyseerr"
```

Then configure OIDC via UI: **Settings → Users → Configure OpenID Connect**

> [!warning] Important
> OIDC configuration via environment variables does NOT work. Must use the UI settings.

---

### Jellyseerr SSO Redirect URI Error

**Resolved**: December 24, 2025

**Symptoms**: After clicking SSO button and authenticating with Authentik, user is redirected back with error:
```
Redirect URI Error
The request fails due to a missing, invalid, or mismatching redirection URI
```

**Root Cause**: Two issues:
1. Jellyseerr uses a new callback format: `/login?provider=authentik&callback=true`
2. Behind reverse proxy, Jellyseerr generates `http://` URIs instead of `https://`

**Diagnosis**:
```bash
# Check Authentik logs for the actual redirect URI being sent
ssh hermes-admin@192.168.40.21 "sudo docker logs authentik-server --tail 50 2>&1 | grep -i redirect"
```

**Resolution**: Add both HTTP and HTTPS redirect URIs with regex matching in Authentik:

```bash
ssh hermes-admin@192.168.40.21 "sudo docker exec authentik-server ak shell -c \"
from authentik.providers.oauth2.models import OAuth2Provider
from authentik.providers.oauth2.constants import RedirectURIMatchingMode
from authentik.providers.oauth2.models import RedirectURI

provider = OAuth2Provider.objects.get(name='jellyseerr-oidc-provider')
new_uris = [
    RedirectURI(matching_mode=RedirectURIMatchingMode.REGEX, url=r'https://jellyseerr\.hrmsmrflrii\.xyz/login\?provider=authentik.*'),
    RedirectURI(matching_mode=RedirectURIMatchingMode.REGEX, url=r'http://jellyseerr\.hrmsmrflrii\.xyz/login\?provider=authentik.*'),
]
provider.redirect_uris = new_uris
provider.save()
\""
```

**Key Points**:
- Use `REGEX` matching mode for URLs with query parameters
- Include BOTH `http://` and `https://` versions
- Escape dots in regex: `\.` not `.`

**Verification**: Navigate to https://jellyseerr.hrmsmrflrii.xyz, click SSO button, complete login - should work without errors.

---

## Container & Docker Issues

### Watchtower TLS Handshake Error

**Resolved**: December 2025

**Symptoms**: `tls: first record does not look like a TLS handshake`

**Root Cause**: Using `generic://` instead of `generic+http://` in webhook URL.

**Fix**: Update `WATCHTOWER_NOTIFICATION_URL`:
```yaml
# Wrong
WATCHTOWER_NOTIFICATION_URL: "generic://192.168.40.13:5050/webhook"

# Correct
WATCHTOWER_NOTIFICATION_URL: "generic+http://192.168.40.13:5050/webhook"
```

Then restart: `cd /opt/watchtower && sudo docker compose restart`

---

### Update Manager SSH Key Not Accessible

**Resolved**: December 2025

**Symptoms**: Discord bot returns `❌ Update failed: Could not find compose directory`

**Root Cause**: SSH key not mounted in Update Manager container.

**Fix**:
```bash
scp ~/.ssh/homelab_ed25519 hermes-admin@192.168.40.13:/home/hermes-admin/.ssh/
ssh hermes-admin@192.168.40.13 "chmod 600 /home/hermes-admin/.ssh/homelab_ed25519"
ssh hermes-admin@192.168.40.13 "cd /opt/update-manager && sudo docker compose restart"
```

**Verification**:
```bash
ssh hermes-admin@192.168.40.13 "docker exec update-manager ssh -i /root/.ssh/homelab_ed25519 -o StrictHostKeyChecking=no hermes-admin@192.168.40.11 hostname"
```

---

### Docker Build Cache Issues

**Resolved**: December 2025

**Symptoms**: Bot behavior doesn't change after modifying code.

**Root Cause**: Docker caching old layers.

**Fix**: Force rebuild with no cache:
```bash
sudo docker compose down && sudo docker compose build --no-cache && sudo docker compose up -d
```

---

### Jellyfin Shows Fewer Movies Than Download Monitor

**Resolved**: December 24, 2025

**Symptoms**:
- Download Monitor shows several movies downloaded
- Jellyfin only shows 5 movies
- Movies in `/mnt/media/Completed/` but not in `/mnt/media/Movies/`
- Jellyfin logs: `Library folder /data/movies is inaccessible or empty`

**Root Causes (Multiple)**:
1. **Docker Volume Mount Failure**: Nested bind mounts over NFS didn't initialize
2. **Dual Root Folders in Radarr**: `/data/Movies` and `/movies` causing inconsistent imports
3. **Missing SABnzbd Remote Path Mapping**: Only Deluge had mapping configured
4. **Stuck Radarr Command**: `ProcessMonitoredDownloads` blocked other operations

**Diagnosis**:
```bash
# Check Jellyfin mount
docker exec jellyfin ls -la /data/movies
# Returns "No such file" = mount not active

# Check Radarr root folders
curl -s 'http://localhost:7878/api/v3/rootfolder' -H 'X-Api-Key: KEY' | jq '.[] | .path'
# Shows both paths = dual root folder issue
```

**Fix Steps**:
1. Recreate Jellyfin container:
   ```bash
   cd /opt/arr-stack && sudo docker compose up -d --force-recreate jellyfin
   ```

2. Add SABnzbd remote path mapping via Radarr API

3. Consolidate all movies to `/data/Movies` path using Python script

4. Delete legacy `/movies` root folder

5. Restart Radarr to clear stuck commands

**Prevention**:
- Use unified `/data` mount for all arr-stack services
- Configure remote path mappings for ALL download clients
- Use only ONE root folder per media type
- Avoid nested Docker bind mounts over NFS

> [!warning] Best Practice
> Use single parent mount in docker-compose:
> ```yaml
> volumes:
>   - /mnt/media:/data  # Single mount - good
> # NOT:
>   - /mnt/media/Movies:/data/movies  # Nested - problematic!
> ```

---

## Service-Specific Issues

### GitLab Unsupported Config Value (grafana)

**Resolved**: December 20, 2025

**Symptoms**: GitLab container restart loop with:
```
FATAL: Mixlib::Config::UnknownConfigOptionError: Reading unsupported config value grafana.
```

**Root Cause**: GitLab removed bundled Grafana support. The `grafana['enable'] = false` line is deprecated.

**Fix**: Remove `grafana['enable'] = false` from GITLAB_OMNIBUS_CONFIG in `/opt/gitlab/docker-compose.yml`:
```bash
cd /opt/gitlab && sudo docker compose down && sudo docker compose up -d
```

**Verification**:
```bash
docker ps --filter name=gitlab
docker exec gitlab gitlab-ctl status
```

**Prevention**: Review GitLab release notes for deprecated options before updates.

---

## Network Issues

### VLAN-Aware Bridge Missing

**Symptom**: `QEMU exited with code 1`

**Solution**: Configure `/etc/network/interfaces`:
```bash
auto vmbr0
iface vmbr0 inet static
    address 192.168.20.XX/24
    gateway 192.168.20.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

Then: `ifreload -a` or reboot.

---

### NFS Mount Failures

**Diagnosis**:
```bash
showmount -e 192.168.20.31
df -h | grep nfs
```

**Common Fixes**:
- Check NFS service on NAS
- Verify firewall (ports 111, 2049)
- For stale mounts: `umount -l /mnt/stale && mount -a`

---

## Common Issues

### Connection Refused Errors

**Symptom**: `dial tcp 192.168.20.21:8006: connectex: No connection`

**Solution**:
```bash
ssh root@192.168.20.21 "systemctl status pveproxy"
```

---

### Template Not Found (LXC)

**Symptom**: `template 'local:vztmpl/...' does not exist`

**Solution**:
```bash
ssh root@<node> "pveam update && pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
```

---

### Terraform State Lock

**Solution**:
1. Ensure no other terraform operations running
2. Force unlock: `terraform force-unlock <lock-id>`

---

## Diagnostic Commands

### Terraform
```bash
terraform state list
terraform state show <resource>
terraform refresh
terraform validate
```

### Proxmox
```bash
pvecm status
pvesh get /cluster/resources --type node
qm config <vmid>
systemctl status pve-cluster corosync pveproxy
journalctl -xeu corosync
```

### Kubernetes
```bash
kubectl get nodes
kubectl get pods -A
kubectl describe node <node>
kubectl logs -n <namespace> <pod>
```

### Ansible
```bash
ansible all -m ping
ansible <host> -m setup
```

### Network
```bash
ip -d link show vmbr0 | grep vlan_filtering
bridge link show
ip route show
```

### Docker
```bash
docker logs <container> --tail 50
docker exec <container> <command>
```

### Authentik
```bash
ssh hermes-admin@192.168.40.21 "sudo docker exec authentik-server ak shell -c \"
from authentik.outposts.models import Outpost
outpost = Outpost.objects.get(name='authentik Embedded Outpost')
print(f'Providers: {outpost.providers.count()}')
\""
```

---

## Related Documentation

- [[02 - Proxmox Cluster]] - Cluster configuration
- [[01 - Network Architecture]] - Network configuration
- [[05 - Terraform Configuration]] - Deployment configuration
- [[19 - Watchtower Updates]] - Container update issues
- [[14 - Authentik Google SSO Setup]] - SSO configuration
