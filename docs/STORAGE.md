# Storage Configuration

> Part of the [Proxmox Infrastructure Documentation](../CLAUDE.md)

## Architecture Overview

The cluster uses a production-grade NFS storage architecture with dedicated exports for each content type. This design prevents storage state ambiguity, content type conflicts, and ensures consistent behavior across all nodes.

**Design Rule**: One NFS export = One Proxmox storage pool

## Synology NAS Configuration

**NAS Address**: 192.168.20.31

| Storage Pool | Export Path | Type | Content | Management |
|--------------|-------------|------|---------|------------|
| **VMDisks** | `/volume2/ProxmoxCluster-VMDisks` | NFS | Disk image | Proxmox-managed |
| **ISOs** | `/volume2/ProxmoxCluster-ISOs` | NFS | ISO image | Proxmox-managed |
| **LXC Configs** | `/volume2/Proxmox-LXCs` | NFS | App data | Manual mount |
| **Media** | `/volume2/Proxmox-Media` | NFS | Media files | Manual mount |
| **local-lvm** | N/A | Local LVM | Container | Local storage |

## Storage Pools

### VMDisks (Proxmox-managed)

VM disk images with full Proxmox integration.

- **Used for**: VM virtual disks, cloud-init drives
- **Enables**: Live migration, snapshots, HA
- **Mount**: Automatically managed by Proxmox

**Proxmox Configuration** (Datacenter > Storage):
```
ID: VMDisks
Server: 192.168.20.31
Export: /volume2/ProxmoxCluster-VMDisks
Content: Disk image
Nodes: All nodes
```

### ISOs (Proxmox-managed)

Installation media storage.

- **Used for**: ISO images, installation media
- **Separated from**: VM disks to prevent accidental operations
- **Mount**: Automatically managed by Proxmox

**Proxmox Configuration**:
```
ID: ISOs
Server: 192.168.20.31
Export: /volume2/ProxmoxCluster-ISOs
Content: ISO image
Nodes: All nodes
```

### LXC Configs (Manual mount)

Application configuration data for containers.

- **Mount point**: `/mnt/nfs/lxcs` (on all nodes)
- **Used for**: LXC application configurations via bind mounts
- **Why NOT Proxmox storage**: Proxmox expects LXC rootfs images, not app directories

### Media (Manual mount)

Media files for Arr stack, Jellyfin, and Plex.

- **Mount point**: `/mnt/nfs/media` (Proxmox nodes), `/mnt/media` (Docker hosts)
- **Used for**: Radarr, Sonarr, Lidarr, Jellyfin, **Plex** media files
- **Directory structure**: `/Movies/`, `/Series/`, `/Music/`
- **Why NOT Proxmox storage**: Prevents Proxmox from scanning thousands of media files

**Plex Access**: Plex runs on the Synology NAS and accesses media directly at `/volume2/Proxmox-Media/` without needing NFS mounts.

**Docker Host Mount**:
```
192.168.20.31:/volume2/Proxmox-Media -> /mnt/media
```

## Manual NFS Mount Setup

### /etc/fstab Configuration

Add to `/etc/fstab` on all Proxmox nodes:

```bash
192.168.20.31:/volume2/Proxmox-LXCs   /mnt/nfs/lxcs   nfs  defaults,_netdev  0  0
192.168.20.31:/volume2/Proxmox-Media  /mnt/nfs/media  nfs  defaults,_netdev  0  0
```

### Setup Commands

Run on all nodes:

```bash
# Create mount points
mkdir -p /mnt/nfs/lxcs
mkdir -p /mnt/nfs/media

# Mount all
mount -a

# Verify
df -h | grep /mnt/nfs
```

## LXC Bind Mount Strategy

Bind-mount NFS subdirectories into containers for persistent config.

### Example: Traefik Container

**Container config** (`/etc/pve/lxc/100.conf`):
```
mp0: /mnt/nfs/lxcs/traefik,mp=/app/config
```

**Flow**:
1. Host has `/mnt/nfs/lxcs` mounted via NFS
2. Subdirectory `/mnt/nfs/lxcs/traefik/` bind-mounted into container
3. Container sees `/app/config` as normal directory
4. Data persists on NAS at `/volume2/Proxmox-LXCs/traefik/`

### New Container Example

```hcl
# In lxc.tf
new-container = {
  count        = 1
  starting_ip  = "192.168.20.101"
  storage      = "local-lvm"  # LXC rootfs on local storage
  # ... other config
}
```

Then add bind mount in `/etc/pve/lxc/<vmid>.conf`:
```
mp0: /mnt/nfs/lxcs/new-container,mp=/app/config
```

## Why This Architecture Works

**Problems Prevented**:

| Issue | Solution |
|-------|----------|
| Inactive storage warnings | Each storage has dedicated export |
| `?` icons in UI | Homogeneous content types per storage |
| Template clone failures | All storages available on all nodes |
| LXC rootfs errors | App configs are manual mounts |
| Performance degradation | Media not scanned by Proxmox |
| Migration issues | Identical paths across nodes |

**Key Insight**: Proxmox storages are for Proxmox-managed content (VM disks, ISOs, LXC rootfs). Application data and media require manual mounts with bind mounts into containers.

## Terraform Storage References

```hcl
# VM disk storage
storage = "VMDisks"

# LXC rootfs (local for performance)
storage = "local-lvm"
```

## Immich Photo Storage

Special NFS mount for Immich photo management:

```bash
# On immich-vm01 (/etc/fstab)
192.168.20.31:/volume2/ProxmoxData /mnt/appdata nfs defaults,_netdev 0 0
```

- **Photos & Videos**: `/mnt/appdata/immich/` (7TB capacity)
  - Uploads: `/mnt/appdata/immich/upload/`
  - Library: `/mnt/appdata/immich/library/`
  - Profiles: `/mnt/appdata/immich/profile/`

## NAS Monitoring

The Synology NAS is monitored via SNMP with metrics displayed in Grafana and embedded in the Glance dashboard.

### Metrics Available

| Metric | Description |
|--------|-------------|
| Storage Usage | RAID total, used, free space |
| Disk Health | SMART status, temperature per disk |
| CPU Usage | Per-core processor load |
| Memory Usage | Total, available, cached RAM |
| System Status | Overall health, temperature, fan status |

### Dashboard Access

| Location | URL |
|----------|-----|
| Grafana | https://grafana.hrmsmrflrii.xyz/d/synology-nas/synology-nas |
| Glance | https://glance.hrmsmrflrii.xyz → Storage page |

### SNMP Configuration

SNMP must be enabled on the NAS (Control Panel → Terminal & SNMP → SNMP):
- SNMPv2c enabled
- Community: `homelab`

See [Observability](./OBSERVABILITY.md#synology-nas-monitoring) for full setup details.

## Proxmox Backup Server (PBS)

**Address**: 192.168.20.50 (LXC 100 on node03)
**Web UI**: https://192.168.20.50:8007
**External URL**: https://pbs.hrmsmrflrii.xyz (via Traefik)

PBS provides enterprise-grade backup storage with deduplication for the Proxmox cluster.

### Datastores

| Datastore | Storage | Size | Purpose | Mount Path |
|-----------|---------|------|---------|------------|
| `main` | Seagate 4TB HDD (ST4000VN006) | 3.4TB | Weekly/monthly backups, long retention | /backup |
| `daily` | Kingston 1TB NVMe (SNV3S1000G) | 870GB | Daily backups, fast restores | /backup-ssd |

### Backup Strategy

| Storage | Schedule | VMs | Retention |
|---------|----------|-----|-----------|
| `pbs-daily` (SSD) | Daily 2AM | Critical VMs (Traefik, Authentik, Glance, Grafana) | 7 daily |
| `pbs-main` (HDD) | Weekly Sun 3AM | All VMs | 4 weekly, 2 monthly |

### PBS Architecture

```
node03 (host)
├── /mnt/pbs-backup (4TB HDD)
│   └── /datastore → LXC mount at /backup
└── /mnt/pbs-ssd (1TB NVMe)
    └── /datastore → LXC mount at /backup-ssd

PBS LXC (100)
├── /backup → main datastore
└── /backup-ssd → daily datastore
```

### Proxmox Storage Configuration

Add both PBS storages in Datacenter → Storage → Add → Proxmox Backup Server:

| Setting | pbs-main | pbs-daily |
|---------|----------|-----------|
| ID | pbs-main | pbs-daily |
| Server | 192.168.20.50 | 192.168.20.50 |
| Datastore | main | daily |
| Username | backup@pbs!pve | backup@pbs!pve |
| Content | backup | backup |

### PBS Credentials

| Access | Value |
|--------|-------|
| Web UI | https://192.168.20.50:8007 |
| External | https://pbs.hrmsmrflrii.xyz |
| Username | `root` (select "Linux PAM" realm) |
| Password | See Obsidian Credentials |
| API Token | backup@pbs!pve |
| Fingerprint | 32:27:42:d5:ab:7e:41:ef:80:17:ea:30:b8:43:9a:f3:59:af:60:f5:6b:05:ea:1f:28:30:ff:7f:19:b6:d4:55 |

> **Login Note**: Enter `root` in username field (not `root@pam`). The realm dropdown adds `@pam` automatically.

### Remove Subscription Nag

```bash
pct exec 100 -- perl -i.bak -pe \
  's/res.status.toLowerCase\(\) !== .active./false/g' \
  /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
pct exec 100 -- systemctl restart proxmox-backup-proxy
```

## Related Documentation

- [Proxmox](./PROXMOX.md) - Cluster configuration
- [Services](./SERVICES.md) - Service storage paths
- [Terraform](./TERRAFORM.md) - IaC storage configuration
- [Observability](./OBSERVABILITY.md) - NAS monitoring details
