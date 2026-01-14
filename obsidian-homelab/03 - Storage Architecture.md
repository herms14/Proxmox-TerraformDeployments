# Storage Architecture

> **Internal Documentation** - Contains NAS configuration and mount details.

Related: [[00 - Homelab Index]] | [[02 - Proxmox Cluster]] | [[08 - Arr Media Stack]]

---

## Architecture Overview

The cluster uses a production-grade NFS storage architecture with dedicated exports for each content type.

**Design Rule**: One NFS export = One Proxmox storage pool

---

## Synology NAS Configuration

**NAS Address**: 192.168.20.31

| Storage Pool | Export Path | Type | Content | Management |
|--------------|-------------|------|---------|------------|
| **VMDisks** | `/volume2/ProxmoxCluster-VMDisks` | NFS | Disk image | Proxmox-managed |
| **ISOs** | `/volume2/ProxmoxCluster-ISOs` | NFS | ISO image | Proxmox-managed |
| **LXC Configs** | `/volume2/Proxmox-LXCs` | NFS | App data | Manual mount |
| **Media** | `/volume2/Proxmox-Media` | NFS | Media files | Manual mount |
| **ProxmoxData** | `/volume2/ProxmoxData` | NFS | App data (Immich) | Manual mount |
| **local-lvm** | N/A | Local LVM | Container | Local storage |

---

## Proxmox Storage Pools

### VMDisks

VM disk images with full Proxmox integration.

```
ID: VMDisks
Server: 192.168.20.31
Export: /volume2/ProxmoxCluster-VMDisks
Content: Disk image
Nodes: All nodes
```

- **Used for**: VM virtual disks, cloud-init drives
- **Enables**: Live migration, snapshots, HA

### ISOs

Installation media storage.

```
ID: ISOs
Server: 192.168.20.31
Export: /volume2/ProxmoxCluster-ISOs
Content: ISO image
Nodes: All nodes
```

---

## Manual NFS Mounts

### /etc/fstab Configuration

Add to `/etc/fstab` on all Proxmox nodes:

```bash
192.168.20.31:/volume2/Proxmox-LXCs   /mnt/nfs/lxcs   nfs  defaults,_netdev  0  0
192.168.20.31:/volume2/Proxmox-Media  /mnt/nfs/media  nfs  defaults,_netdev  0  0
```

### Setup Commands

```bash
# Create mount points
mkdir -p /mnt/nfs/lxcs
mkdir -p /mnt/nfs/media

# Mount all
mount -a

# Verify
df -h | grep /mnt/nfs
```

---

## Docker Host Mounts

### Media Mount (docker-vm-media01)

```bash
# /etc/fstab
192.168.20.31:/volume2/Proxmox-Media /mnt/media nfs defaults,_netdev 0 0
```

**Directory Structure**:
- `/mnt/media/Movies`
- `/mnt/media/Series`
- `/mnt/media/Music`
- `/mnt/media/Downloads`

### Immich Mount (immich-vm01)

```bash
# /etc/fstab
192.168.20.31:/volume2/ProxmoxData /mnt/appdata nfs defaults,_netdev 0 0
```

**Directory Structure** (7TB capacity):
- `/mnt/appdata/immich/upload/`
- `/mnt/appdata/immich/library/`
- `/mnt/appdata/immich/profile/`

---

## LXC Bind Mount Strategy

Bind-mount NFS subdirectories into containers for persistent config.

### Example: Traefik Container

Container config (`/etc/pve/lxc/100.conf`):
```
mp0: /mnt/nfs/lxcs/traefik,mp=/app/config
```

**Flow**:
1. Host has `/mnt/nfs/lxcs` mounted via NFS
2. Subdirectory `/mnt/nfs/lxcs/traefik/` bind-mounted into container
3. Container sees `/app/config` as normal directory
4. Data persists on NAS at `/volume2/Proxmox-LXCs/traefik/`

---

## Why This Architecture Works

| Issue | Solution |
|-------|----------|
| Inactive storage warnings | Each storage has dedicated export |
| `?` icons in UI | Homogeneous content types per storage |
| Template clone failures | All storages available on all nodes |
| LXC rootfs errors | App configs are manual mounts |
| Performance degradation | Media not scanned by Proxmox |
| Migration issues | Identical paths across nodes |

---

## Related Documentation

- [[02 - Proxmox Cluster]] - Cluster configuration
- [[07 - Deployed Services]] - Service storage paths
- [[08 - Arr Media Stack]] - Media storage configuration
- [[05 - Terraform Configuration]] - IaC storage configuration

