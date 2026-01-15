# Hermes' Homelab Assistant - Project Description

> Use this description for the Claude Desktop "Homelab Assistant" project to give Claude full context about the infrastructure ecosystem.

---

## Project Overview

This is Hermes' personal homelab infrastructure - an enterprise-grade home data center built on Proxmox virtualization, managed with Infrastructure-as-Code (Terraform, Ansible, Packer), and integrated with Azure cloud services. The infrastructure hosts media services, monitoring, automation, and productivity tools.

**Domain**: `hrmsmrflrii.xyz`
**Primary Dashboard**: https://glance.hrmsmrflrii.xyz

---

## Infrastructure Architecture

### Proxmox Cluster (MorpheusCluster)

A 2-node Proxmox VE cluster with Qdevice for quorum:

| Node | IP | Tailscale IP | Role |
|------|-----|--------------|------|
| **node01** | 192.168.20.20 | 100.89.33.5 | Primary Host (K8s, LXCs, Core Services) |
| **node02** | 192.168.20.21 | 100.96.195.27 | Service Host (Traefik, Authentik, GitLab, Immich) |

**Remote Access**: Tailscale mesh VPN with node01 as subnet router advertising 192.168.20.0/24, 192.168.40.0/24, 192.168.91.0/24

### Network Architecture

| VLAN | Network | Purpose |
|------|---------|---------|
| VLAN 10 | 192.168.10.0/24 | Default/Guest |
| VLAN 20 | 192.168.20.0/24 | Infrastructure (Proxmox, K8s, Ansible, NAS) |
| VLAN 40 | 192.168.40.0/24 | Services (Docker hosts, Applications) |
| VLAN 90 | 192.168.90.0/24 | Management (Pi-hole DNS at 192.168.90.53) |

**Network Hardware**:
- OPNsense Firewall/Router (192.168.0.1)
- TP-Link Omada OC300 Controller (192.168.0.103)
- Omada managed switches and access points

### Storage

**Synology DS920+ NAS** (192.168.20.31):
- 4x HDDs (8TB, 4TB, 12TB, 10TB) in SHR RAID
- 2x M.2 NVMe SSDs (1TB each) as read/write cache
- NFS shares mounted to Proxmox for VM storage
- Plex Media Server running natively
- SNMP monitoring enabled (community: `homelab`)

**Media Paths**:
- Movies: `/volume2/Proxmox-Media/Movies`
- TV Shows: `/volume2/Proxmox-Media/Series`
- Music: `/volume2/Proxmox-Media/Music`

---

## Deployed Services

### Core Infrastructure Hosts

| Host | IP | Type | Services |
|------|-----|------|----------|
| docker-lxc-glance | 192.168.40.12 | LXC 200 | Glance Dashboard, Media Stats API, Reddit Manager, NBA Stats API, Pi-hole Stats API |
| docker-vm-core-utilities01 | 192.168.40.13 | VM 107 | Grafana, Prometheus, Uptime Kuma, Speedtest, SNMP Exporter, Life Progress API, **Sentinel Discord Bot** |
| docker-media | 192.168.40.11 | VM | Jellyfin, Radarr, Sonarr, Lidarr, Prowlarr, Bazarr, Deluge, SABnzbd, MeTube |
| traefik | 192.168.40.20 | VM | Reverse Proxy (TLS termination, routing) |
| authentik | 192.168.40.21 | VM | SSO/Identity Provider (ForwardAuth) |
| immich-vm01 | 192.168.40.22 | VM | Immich Photo Management |
| pihole | 192.168.90.53 | LXC 202 | Pi-hole v6 + Unbound DNS |
| ansible | 192.168.20.30 | VM | Ansible Controller + Packer |

### Kubernetes Cluster

9-node cluster (3 controllers + 6 workers) running Kubernetes v1.28.15 on VLAN 20.

### Service URLs

| Category | Service | URL |
|----------|---------|-----|
| **Core** | Proxmox | https://proxmox.hrmsmrflrii.xyz |
| | Traefik | https://traefik.hrmsmrflrii.xyz |
| | Authentik | https://auth.hrmsmrflrii.xyz |
| **Media** | Jellyfin | https://jellyfin.hrmsmrflrii.xyz |
| | Plex | http://192.168.20.31:32400/web |
| | Radarr | https://radarr.hrmsmrflrii.xyz |
| | Sonarr | https://sonarr.hrmsmrflrii.xyz |
| | Overseerr | https://overseerr.hrmsmrflrii.xyz |
| **Monitoring** | Grafana | https://grafana.hrmsmrflrii.xyz |
| | Prometheus | https://prometheus.hrmsmrflrii.xyz |
| | Uptime Kuma | https://uptime.hrmsmrflrii.xyz |
| | Jaeger | https://jaeger.hrmsmrflrii.xyz |
| **Dashboard** | Glance | https://glance.hrmsmrflrii.xyz |
| **Productivity** | GitLab | https://gitlab.hrmsmrflrii.xyz |
| | Immich | https://photos.hrmsmrflrii.xyz |
| | n8n | https://n8n.hrmsmrflrii.xyz |
| | Paperless | https://paperless.hrmsmrflrii.xyz |

---

## Infrastructure-as-Code Tools

### Terraform
- **Purpose**: Provision VMs and LXC containers on Proxmox
- **Location**: Local repository (`Proxmox-TerraformDeployments`)
- **Provider**: `bpg/proxmox`
- **API User**: `terraform-deployment-user@pve!tf`

### Ansible
- **Purpose**: Configuration management, service deployment
- **Controller**: 192.168.20.30 (`~/ansible/`)
- **Playbook Structure**: `ansible-playbooks/{category}/{playbook}.yml`
- **Categories**: `services/`, `monitoring/`, `glance/`, `traefik/`

### Packer
- **Purpose**: Create VM templates with cloud-init
- **Location**: 192.168.20.30 (`~/packer/`)
- **Base Template**: Ubuntu 24.04 LTS with UEFI boot

---

## Monitoring & Observability Stack

### Prometheus (192.168.40.13:9090)
Scrapes metrics from:
- Docker Stats Exporter (containers on both VMs)
- SNMP Exporter (Synology NAS)
- PVE Exporter (Proxmox nodes)
- Omada Exporter (network devices)
- Traefik metrics endpoint

### Grafana (192.168.40.13:3030)
Key dashboards:
- `container-status` - Container uptime and state timeline
- `synology-nas-modern` - NAS storage, RAID status, temperatures
- `omada-network` - Network device health, client stats, PoE usage
- `proxmox-compute` - Cluster resource utilization

### RAID Monitoring
The Synology NAS dashboard monitors RAID array health:
- `synologyRaidStatus{raidIndex="0"}` - HDD Storage Pool
- `synologyRaidStatus{raidIndex="1"}` - SSD Cache Pool

Status codes: 1=Normal, 2=Repairing, 7=Syncing, 11=Degraded, 12=Crashed

---

## Glance Dashboard

Self-hosted dashboard at https://glance.hrmsmrflrii.xyz with 7 tabs:

| Tab | Content |
|-----|---------|
| **Home** | Clock, Weather, Chess.com stats, Life Progress, GitHub contributions, Service monitors, Markets |
| **Compute** | Proxmox cluster dashboard, Container monitoring (Grafana iframes) |
| **Storage** | Synology NAS dashboard with RAID status, disk temps, storage consumption |
| **Network** | Omada network dashboard, Pi-hole stats, Speedtest |
| **Media** | Media Stats grid (Radarr/Sonarr), Recent downloads, RSS feeds |
| **Web** | Tech YouTube, News RSS, Cloud/AI feeds |
| **Reddit** | Dynamic Reddit feed via Reddit Manager API |

**Config Location**: `/opt/glance/config/glance.yml` on LXC 200 (192.168.40.12)

---

## Discord Bot: Sentinel

Unified homelab management bot running on docker-vm-core-utilities01 (192.168.40.13).

**Cog Modules**:
| Cog | Channel | Purpose |
|-----|---------|---------|
| Homelab | #homelab-infrastructure | Proxmox cluster status, VM/LXC management |
| Updates | #container-updates | Watchtower webhooks, update approvals |
| Media | #media-downloads | Download tracking, failed download alerts |
| GitLab | #project-management | Issue creation via slash commands |
| Tasks | #claude-tasks | Claude task queue with REST API |

**Key Commands**: `/homelab status`, `/vm <id> restart`, `/lxc <id> restart`, `/check`, `/downloads`, `/insight`

---

## Azure Cloud Integration

**Subscription**: FireGiants-Prod
**Region**: Southeast Asia

### Resources
| Resource | Purpose |
|----------|---------|
| ubuntu-deploy-vm (10.90.10.5) | Primary Terraform/Ansible deployment VM |
| law-homelab-sentinel | Log Analytics + Sentinel SIEM |
| Site-to-Site VPN | OPNsense <-> Azure VNet connectivity |

### Azure Hybrid AD Lab
Active Directory domain `hrmsmrflrii.xyz` with:
- AZDC01 (10.10.4.4) - Primary DC
- AZDC02 (10.10.4.5) - Secondary DC
- AZRODC01/02 - Read-only DCs

---

## SSH Access

| Target | User | Key |
|--------|------|-----|
| Proxmox nodes | root | `~/.ssh/homelab_ed25519` |
| All VMs | hermes-admin | `~/.ssh/homelab_ed25519` |
| Azure VMs | hermes-admin | `~/.ssh/ubuntu-deploy-vm.pem` |

**SSH Config Aliases**: `node01`, `node02`, `ansible`, `docker-vm-core-utilities01`, `docker-media`, `traefik`, `ubuntu-deploy`

---

## GitHub Repositories

| Repository | Purpose |
|------------|---------|
| [Proxmox-TerraformDeployments](https://github.com/herms14/Proxmox-TerraformDeployments) | Main infrastructure repo (Terraform, Ansible, docs) |
| [glance-dashboard](https://github.com/herms14/glance-dashboard) | Glance config and custom APIs |
| [Clustered-Thoughts](https://github.com/herms14/Clustered-Thoughts) | Homelab blog (Hugo + GitHub Pages) |

---

## Key Conventions

1. **Documentation Sync**: When updating docs, sync across: `docs/`, Obsidian vault, CHANGELOG.md
2. **Protected Layouts**: Glance Home, Compute, Storage, Network, Media tabs require explicit permission to modify
3. **Service Deployment**: Use Ansible playbooks from the controller, not direct SSH
4. **Grafana Dashboards**: Provisioned from JSON files in `/opt/monitoring/grafana/dashboards/`
5. **Traefik Routes**: Dynamic config in `/opt/traefik/config/dynamic/services.yml`

---

## Common Tasks

### Deploy a new service
1. Create Terraform config for VM/LXC
2. Write Ansible playbook for service deployment
3. Add Traefik route for HTTPS access
4. Configure DNS in Pi-hole/OPNsense
5. Add Authentik ForwardAuth if needed
6. Update Glance dashboard
7. Document in all locations

### Check service health
```bash
ssh docker-vm-core-utilities01 "docker ps"
curl https://uptime.hrmsmrflrii.xyz/api/status/homelab
```

### View logs
```bash
ssh docker-vm-core-utilities01 "docker logs <container> --tail 100"
ssh traefik "docker logs traefik --tail 100"
```

### Restart a service
```bash
ssh <host> "cd /opt/<service> && docker compose restart"
```

---

## Obsidian Vault Location

Personal documentation with credentials:
```
C:\Users\herms\OneDrive\Obsidian Vault\Hermes's Life Knowledge Base\07 HomeLab Things\Claude Managed Homelab\
```

Key files:
- `11 - Credentials.md` - All passwords and API keys
- `23 - Glance Dashboard.md` - Dashboard documentation
- `07 - Deployed Services.md` - Service inventory

---

## Quick Reference IPs

| Service | IP:Port |
|---------|---------|
| Proxmox node01 | 192.168.20.20:8006 |
| Proxmox node02 | 192.168.20.21:8006 |
| Synology NAS | 192.168.20.31:5001 |
| Ansible Controller | 192.168.20.30 |
| Glance LXC | 192.168.40.12 |
| Docker Utilities VM | 192.168.40.13 |
| Docker Media VM | 192.168.40.11 |
| Traefik | 192.168.40.20 |
| Authentik | 192.168.40.21 |
| Immich | 192.168.40.22 |
| Grafana | 192.168.40.13:3030 |
| Prometheus | 192.168.40.13:9090 |
| Pi-hole | 192.168.90.53 |
