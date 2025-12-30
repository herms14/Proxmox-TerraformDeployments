# Homelab Master Wiki

> **The Complete Technical Reference for MorpheusCluster Homelab**
>
> This document serves as the authoritative wiki and encyclopedia for the entire homelab infrastructure. For step-by-step tutorials, see [The Complete Homelab Guide](../Obsidian/Book%20-%20The%20Complete%20Homelab%20Guide.md).

---

## Table of Contents

1. [Infrastructure Overview](#infrastructure-overview)
2. [Network Architecture](#network-architecture)
3. [Compute Infrastructure](#compute-infrastructure)
4. [Storage Architecture](#storage-architecture)
5. [Tech Stack Reference](#tech-stack-reference)
6. [Services Catalog](#services-catalog)
7. [Automation & DevOps](#automation--devops)
8. [Monitoring & Observability](#monitoring--observability)
9. [Security & Access](#security--access)
10. [Operations Reference](#operations-reference)
11. [Quick Reference](#quick-reference)

---

# Infrastructure Overview

## At a Glance

| Metric | Value |
|--------|-------|
| **Cluster Name** | MorpheusCluster |
| **Proxmox Nodes** | 2 (HA with Qdevice) |
| **Virtual Machines** | 18 |
| **LXC Containers** | 3 |
| **Docker Containers** | 30+ |
| **Kubernetes Nodes** | 9 |
| **Total vCPUs** | 44 |
| **Total RAM** | 145 GB |
| **Storage** | 426 GB (NFS) |
| **VLANs** | 8 |
| **Services** | 40+ |

*Last updated: December 30, 2025*

## Architecture Diagram

```
                                    INTERNET
                                        │
                                        ▼
                              ┌─────────────────┐
                              │   ISP Router    │
                              │  192.168.100.1  │
                              │   (Converge)    │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │   Core Router   │
                              │    ER605 v2.20  │
                              │   192.168.0.1   │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │  Atreus Switch  │
                              │   ES20GP v1.0   │
                              │  192.168.90.51  │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │   Core Switch   │
                              │  SG3210 v3.20   │
                              │  192.168.90.2   │
                              └────────┬────────┘
                                       │
          ┌────────────┬───────────────┼───────────────┬────────────┐
          │            │               │               │            │
          ▼            ▼               ▼               ▼            ▼
    ┌──────────┐ ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────┐
    │ Morpheus │ │ OPNsense │  │ Synology │  │  Wireless │  │  Other   │
    │  Switch  │ │ Firewall │  │   NAS    │  │    APs    │  │ Devices  │
    │ SG2210P  │ │  .91.30  │  │  .20.31  │  │ EAP225/   │  │          │
    │  .90.3   │ │          │  │          │  │ EAP610    │  │          │
    └────┬─────┘ └──────────┘  └──────────┘  └───────────┘  └──────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
  Node01   Node02
  (.20)    (.21)
```

## Domain & SSL

| Setting | Value |
|---------|-------|
| **Domain** | hrmsmrflrii.xyz |
| **Registrar** | GoDaddy |
| **DNS Provider** | Cloudflare |
| **SSL Provider** | Let's Encrypt (wildcard) |
| **SSL Challenge** | DNS-01 via Cloudflare API |
| **Internal DNS** | Pi-hole v6 + Unbound (192.168.90.53) |

---

# Network Architecture

## VLAN Configuration

| VLAN ID | Name | Network | Gateway | Purpose | DHCP Range |
|---------|------|---------|---------|---------|------------|
| 1 | Default | 192.168.0.0/24 | 192.168.0.1 | Management (temporary) | .100-.199 |
| 10 | Internal | 192.168.10.0/24 | 192.168.10.1 | Main LAN (workstations, NAS) | .50-.254 |
| **20** | **Homelab** | **192.168.20.0/24** | **192.168.20.1** | **Proxmox nodes, K8s, VMs** | .50-.254 |
| 30 | IoT | 192.168.30.0/24 | 192.168.30.1 | IoT WiFi devices | .50-.254 |
| **40** | **Production** | **192.168.40.0/24** | **192.168.40.1** | **Docker services, apps** | .50-.254 |
| 50 | Guest | 192.168.50.0/24 | 192.168.50.1 | Guest WiFi | .50-.254 |
| 60 | Sonos | 192.168.60.0/24 | 192.168.60.1 | Sonos speakers | .50-.100 |
| 90 | Management | 192.168.90.0/24 | 192.168.90.1 | Network device management | .50-.254 |
| 91 | Firewall | 192.168.91.0/24 | 192.168.91.1 | OPNsense firewall | - |

## Network Hardware

| Device | Model | IP Address | Firmware | Purpose |
|--------|-------|------------|----------|---------|
| Core Router | ER605 | 192.168.0.1 | v2.20 | Main gateway, inter-VLAN routing |
| Atreus Switch | ES20GP | 192.168.90.51 | v1.0 | First floor distribution |
| Core Switch | SG3210 | 192.168.90.2 | v3.20 | Primary L2 switch, VLAN trunking |
| Morpheus Switch | SG2210P | 192.168.90.3 | v5.20 | Proxmox node connectivity (PoE) |
| Computer Room EAP | EAP225 | 192.168.90.12 | v4.0 | WiFi AP |
| Living Room EAP | EAP610 | 192.168.90.10 | v3.0 | Primary WiFi AP |
| Outdoor EAP | EAP603-Outdoor | 192.168.90.11 | v1.0 | Outdoor WiFi |
| Network Controller | OC300 | Cloud | - | Omada SDN management |

## IP Address Allocation

### VLAN 20 - Infrastructure (192.168.20.0/24)

| IP Address | Hostname | Purpose |
|------------|----------|---------|
| 192.168.20.1 | - | Gateway |
| 192.168.20.20 | node01 | Proxmox primary node |
| 192.168.20.21 | node02 | Proxmox secondary node |
| 192.168.20.30 | ansible-controller01 | Ansible automation |
| 192.168.20.31 | synology-nas | Synology NAS (VLAN 20 interface) |
| 192.168.20.32-34 | k8s-controller01-03 | Kubernetes control plane |
| 192.168.20.40-45 | k8s-worker01-06 | Kubernetes workers |
| 192.168.20.46-99 | Reserved | Future K8s nodes |
| 192.168.20.100-199 | Reserved | LXC containers |

### VLAN 40 - Services (192.168.40.0/24)

| IP Address | Hostname | Purpose |
|------------|----------|---------|
| 192.168.40.1 | - | Gateway |
| 192.168.40.5 | linux-syslog-server01 | Centralized logging |
| 192.168.40.11 | docker-vm-media01 | Media services (Arr stack) |
| 192.168.40.12 | docker-lxc-glance | Glance dashboard (LXC) |
| 192.168.40.13 | docker-vm-core-utilities01 | Monitoring services |
| 192.168.40.14 | docker-lxc-bots | Discord bots (LXC) |
| 192.168.40.20 | traefik-vm01 | Reverse proxy |
| 192.168.40.21 | authentik-vm01 | Identity/SSO |
| 192.168.40.22 | immich-vm01 | Photo management |
| 192.168.40.23 | gitlab-vm01 | DevOps platform |
| 192.168.40.24 | gitlab-runner-vm01 | CI/CD runner |

### VLAN 90 - Management (192.168.90.0/24)

| IP Address | Hostname | Purpose |
|------------|----------|---------|
| 192.168.90.2 | core-switch | SG3210 |
| 192.168.90.3 | morpheus-switch | SG2210P |
| 192.168.90.10 | eap-living | EAP610 |
| 192.168.90.11 | eap-outdoor | EAP603-Outdoor |
| 192.168.90.12 | eap-computer | EAP225 |
| 192.168.90.51 | atreus-switch | ES20GP |
| 192.168.90.53 | pihole | Pi-hole DNS |

## Remote Access (Tailscale)

| Device | Local IP | Tailscale IP | Role |
|--------|----------|--------------|------|
| node01 | 192.168.20.20 | 100.89.33.5 | **Subnet Router** |
| node02 | 192.168.20.21 | 100.96.195.27 | Peer |
| MacBook Pro | - | 100.90.207.58 | Client |

**Advertised Subnets** (via node01):
- 192.168.20.0/24 (Infrastructure)
- 192.168.40.0/24 (Services)
- 192.168.91.0/24 (Firewall/DNS)

---

# Compute Infrastructure

## Proxmox Cluster

**Cluster Name**: MorpheusCluster
**Configuration**: 2-node cluster with Qdevice for quorum

| Node | IP Address | Tailscale IP | Purpose | Workloads |
|------|------------|--------------|---------|-----------|
| **node01** | 192.168.20.20 | 100.89.33.5 | Primary VM Host | K8s cluster, LXCs, Core Services |
| **node02** | 192.168.20.21 | 100.96.195.27 | Service Host | Traefik, Authentik, GitLab, Immich |

### Proxmox Version & API

| Setting | Value |
|---------|-------|
| **Version** | Proxmox VE 9.1.2 |
| **API URL** | https://192.168.20.21:8006/api2/json |
| **API Token** | terraform-deployment-user@pve!tf |
| **Terraform Provider** | telmate/proxmox v3.0.2-rc06 |

### Wake-on-LAN

| Node | MAC Address | Interface |
|------|-------------|-----------|
| node01 | 38:05:25:32:82:76 | nic0 |
| node02 | 84:47:09:4d:7a:ca | nic0 |

```bash
# Wake nodes
python3 scripts/wake-nodes.py          # Both nodes
python3 scripts/wake-nodes.py node01   # node01 only
```

## Virtual Machines

### VLAN 20 VMs (Infrastructure)

| Hostname | VMID | Node | IP | Cores | RAM | Disk | Purpose |
|----------|------|------|----|-------|-----|------|---------|
| ansible-controller01 | - | node01 | 192.168.20.30 | 2 | 8GB | 20GB | Ansible automation |
| k8s-controller01 | - | node01 | 192.168.20.32 | 2 | 8GB | 20GB | K8s control plane |
| k8s-controller02 | - | node01 | 192.168.20.33 | 2 | 8GB | 20GB | K8s control plane |
| k8s-controller03 | - | node01 | 192.168.20.34 | 2 | 8GB | 20GB | K8s control plane |
| k8s-worker01 | - | node01 | 192.168.20.40 | 2 | 8GB | 20GB | K8s worker |
| k8s-worker02 | - | node01 | 192.168.20.41 | 2 | 8GB | 20GB | K8s worker |
| k8s-worker03 | - | node01 | 192.168.20.42 | 2 | 8GB | 20GB | K8s worker |
| k8s-worker04 | - | node01 | 192.168.20.43 | 2 | 8GB | 20GB | K8s worker |
| k8s-worker05 | - | node01 | 192.168.20.44 | 2 | 8GB | 20GB | K8s worker |
| k8s-worker06 | - | node01 | 192.168.20.45 | 2 | 8GB | 20GB | K8s worker |

### VLAN 40 VMs (Services)

| Hostname | VMID | Node | IP | Cores | RAM | Disk | Purpose |
|----------|------|------|----|-------|-----|------|---------|
| linux-syslog-server01 | 109 | node02 | 192.168.40.5 | 8 | 8GB | 50GB | Centralized logging |
| docker-vm-media01 | 111 | node01 | 192.168.40.11 | 2 | 12GB | 100GB | Arr media stack |
| docker-vm-core-utilities01 | 107 | node01 | 192.168.40.13 | 4 | 12GB | 40GB | Monitoring stack |
| traefik-vm01 | 102 | node02 | 192.168.40.20 | 2 | 8GB | 20GB | Reverse proxy |
| authentik-vm01 | 100 | node02 | 192.168.40.21 | 2 | 8GB | 20GB | Identity/SSO |
| immich-vm01 | 108 | node02 | 192.168.40.22 | 10 | 12GB | 20GB | Photo management |
| gitlab-vm01 | 106 | node02 | 192.168.40.23 | 2 | 8GB | 20GB | DevOps platform |
| gitlab-runner-vm01 | 121 | node02 | 192.168.40.24 | 2 | 2GB | 20GB | CI/CD runner |

## LXC Containers

| Hostname | VMID | Node | IP | Cores | RAM | Disk | Purpose |
|----------|------|------|----|-------|-----|------|---------|
| docker-lxc-glance | 200 | node01 | 192.168.40.12 | 2 | 4GB | 20GB | Glance, APIs |
| docker-lxc-bots | 201 | node01 | 192.168.40.14 | 2 | 2GB | 8GB | Discord bots |
| pihole | 202 | node01 | 192.168.90.53 | 2 | 1GB | 8GB | Pi-hole + Unbound |

## Kubernetes Cluster

| Setting | Value |
|---------|-------|
| **Version** | v1.28.15 |
| **Runtime** | containerd v1.7.28 |
| **CNI** | Calico v3.27.0 |
| **Pod Network** | 10.244.0.0/16 |
| **Control Plane** | 3 controllers (HA, stacked etcd) |
| **Workers** | 6 nodes |

---

# Storage Architecture

## Synology NAS

| Setting | Value |
|---------|-------|
| **Model** | Synology DS920+ |
| **IP (VLAN 10)** | 192.168.10.31 |
| **IP (VLAN 20)** | 192.168.20.31 |
| **Protocol** | NFS v3/v4 |

### NFS Exports

| Export | Mount Point | Purpose | Clients |
|--------|-------------|---------|---------|
| /volume1/VMDisks | /mnt/synology/VMDisks | Proxmox VM storage | Proxmox nodes |
| /volume1/ISOImages | /mnt/synology/ISOImages | ISO storage | Proxmox nodes |
| /volume1/HomelabBackups | /mnt/synology/Backups | VM backups | Proxmox nodes |
| /volume1/media | /mnt/media | Media files | Docker hosts |
| /volume1/torrents | /mnt/torrents | Download staging | Docker hosts |

### Proxmox Storage Pools

| Pool Name | Type | Content | Path |
|-----------|------|---------|------|
| VMDisks | NFS | images,rootdir | /mnt/synology/VMDisks |
| ISOImages | NFS | iso,vztmpl | /mnt/synology/ISOImages |
| Backups | NFS | backup | /mnt/synology/Backups |
| local | Directory | iso,vztmpl | /var/lib/vz |
| local-lvm | LVM-thin | images,rootdir | - |

---

# Tech Stack Reference

## Core Technologies

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| **Hypervisor** | Proxmox VE | 9.1.2 | Virtualization platform |
| **Container Runtime** | Docker | 24.x | Container orchestration |
| **Container Orchestration** | Kubernetes | 1.28.15 | K8s workloads |
| **IaC** | Terraform | 1.6+ | Infrastructure provisioning |
| **Config Management** | Ansible | 2.15+ | Configuration automation |
| **Reverse Proxy** | Traefik | 3.2 | Load balancing, SSL |
| **Identity Provider** | Authentik | 2024.x | SSO/OAuth |
| **Monitoring** | Prometheus | 2.x | Metrics collection |
| **Visualization** | Grafana | 10.x | Dashboards |
| **DNS** | Pi-hole | v6 | Ad blocking, DNS |
| **Recursive DNS** | Unbound | - | DNS resolution |
| **Tracing** | Jaeger | - | Distributed tracing |
| **OTEL** | OpenTelemetry | - | Observability pipeline |

## Software Stack by Service Host

### docker-vm-media01 (192.168.40.11)

| Service | Port | Purpose |
|---------|------|---------|
| Jellyfin | 8096 | Media streaming |
| Radarr | 7878 | Movie management |
| Sonarr | 8989 | TV show management |
| Lidarr | 8686 | Music management |
| Prowlarr | 9696 | Indexer management |
| Bazarr | 6767 | Subtitle management |
| Overseerr | 5055 | Media requests |
| Jellyseerr | 5056 | Jellyfin requests |
| Tdarr | 8265 | Transcoding automation |
| Autobrr | 7474 | Release automation |
| Deluge | 8112 | Torrent client |
| SABnzbd | 8081 | Usenet client |
| Mnemosyne Bot | - | Media notifications |

### docker-vm-core-utilities01 (192.168.40.13)

| Service | Port | Purpose |
|---------|------|---------|
| Grafana | 3030 | Dashboards |
| Prometheus | 9090 | Metrics |
| Uptime Kuma | 3001 | Status monitoring |
| OpenSpeedTest | 3000 | Speed testing |
| n8n | 5678 | Workflow automation |
| Jaeger | 16686 | Trace viewer |
| OTEL Collector | 4317/4318 | Telemetry pipeline |

### docker-lxc-glance (192.168.40.12)

| Service | Port | Purpose |
|---------|------|---------|
| Glance | 8080 | Dashboard |
| Media Stats API | 5050 | Arr integration |
| Reddit Manager | 5052 | Reddit feed API |
| NBA Stats API | 5054 | Sports data |
| Pi-hole Stats API | 5055 | DNS stats |

### docker-lxc-bots (192.168.40.14)

| Service | Port | Purpose |
|---------|------|---------|
| Argus Bot | - | Container update notifications |
| Chronos Bot | - | Project management |
| Athena API | 5051 | Task queue API |

---

# Services Catalog

## Service URLs

### Infrastructure Services

| Service | Internal URL | External URL |
|---------|--------------|--------------|
| Proxmox Cluster | https://192.168.20.21:8006 | https://proxmox.hrmsmrflrii.xyz |
| Proxmox Node01 | https://192.168.20.20:8006 | https://node01.hrmsmrflrii.xyz |
| Proxmox Node02 | https://192.168.20.21:8006 | https://node02.hrmsmrflrii.xyz |
| Traefik Dashboard | http://192.168.40.20:8080 | https://traefik.hrmsmrflrii.xyz |
| Pi-hole | http://192.168.90.53/admin | https://pihole.hrmsmrflrii.xyz |

### Core Services

| Service | Internal URL | External URL | Auth |
|---------|--------------|--------------|------|
| Authentik | http://192.168.40.21:9000 | https://auth.hrmsmrflrii.xyz | - |
| Immich | http://192.168.40.22:2283 | https://photos.hrmsmrflrii.xyz | Authentik |
| GitLab | http://192.168.40.23:80 | https://gitlab.hrmsmrflrii.xyz | Built-in |

### Media Services

| Service | Internal URL | External URL | Auth |
|---------|--------------|--------------|------|
| Jellyfin | http://192.168.40.11:8096 | https://jellyfin.hrmsmrflrii.xyz | Built-in |
| Radarr | http://192.168.40.11:7878 | https://radarr.hrmsmrflrii.xyz | Authentik |
| Sonarr | http://192.168.40.11:8989 | https://sonarr.hrmsmrflrii.xyz | Authentik |
| Lidarr | http://192.168.40.11:8686 | https://lidarr.hrmsmrflrii.xyz | Authentik |
| Prowlarr | http://192.168.40.11:9696 | https://prowlarr.hrmsmrflrii.xyz | Authentik |
| Bazarr | http://192.168.40.11:6767 | https://bazarr.hrmsmrflrii.xyz | Authentik |
| Overseerr | http://192.168.40.11:5055 | https://overseerr.hrmsmrflrii.xyz | Built-in |
| Jellyseerr | http://192.168.40.11:5056 | https://jellyseerr.hrmsmrflrii.xyz | Built-in |
| Tdarr | http://192.168.40.11:8265 | https://tdarr.hrmsmrflrii.xyz | Authentik |
| Autobrr | http://192.168.40.11:7474 | https://autobrr.hrmsmrflrii.xyz | Authentik |
| Deluge | http://192.168.40.11:8112 | https://deluge.hrmsmrflrii.xyz | Authentik |
| SABnzbd | http://192.168.40.11:8081 | https://sabnzbd.hrmsmrflrii.xyz | Authentik |

### Monitoring Services

| Service | Internal URL | External URL | Auth |
|---------|--------------|--------------|------|
| Glance | http://192.168.40.12:8080 | https://glance.hrmsmrflrii.xyz | None |
| Grafana | http://192.168.40.13:3030 | https://grafana.hrmsmrflrii.xyz | Authentik |
| Prometheus | http://192.168.40.13:9090 | https://prometheus.hrmsmrflrii.xyz | Authentik |
| Uptime Kuma | http://192.168.40.13:3001 | https://uptime.hrmsmrflrii.xyz | Authentik |
| Jaeger | http://192.168.40.13:16686 | https://jaeger.hrmsmrflrii.xyz | Authentik |

### Utility Services

| Service | Internal URL | External URL | Auth |
|---------|--------------|--------------|------|
| n8n | http://192.168.40.13:5678 | https://n8n.hrmsmrflrii.xyz | Authentik |
| Speedtest | http://192.168.40.13:3000 | https://speedtest.hrmsmrflrii.xyz | None |
| Paperless-ngx | http://192.168.40.10:8000 | https://paperless.hrmsmrflrii.xyz | Authentik |

---

# Automation & DevOps

## Terraform

### Provider Configuration

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://192.168.20.21:8006/api2/json"
  pm_api_token_id     = "terraform-deployment-user@pve!tf"
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}
```

### VM Module Usage

```hcl
module "my_vm" {
  source = "./modules/linux-vm"

  hostname    = "my-vm01"
  vmid        = 150
  target_node = "node01"
  cores       = 4
  memory      = 8192
  disk_size   = "50G"
  vlan_tag    = 40
  ip_address  = "192.168.40.50/24"
  gateway     = "192.168.40.1"
}
```

## Ansible

### Inventory Structure

```ini
[proxmox_nodes]
node01 ansible_host=192.168.20.20 ansible_user=root
node02 ansible_host=192.168.20.21 ansible_user=root

[docker_hosts]
docker-utilities ansible_host=192.168.40.10
docker-media ansible_host=192.168.40.11

[k8s_controllers]
k8s-controller01 ansible_host=192.168.20.32
k8s-controller02 ansible_host=192.168.20.33
k8s-controller03 ansible_host=192.168.20.34

[k8s_workers]
k8s-worker01 ansible_host=192.168.20.40
k8s-worker02 ansible_host=192.168.20.41
k8s-worker03 ansible_host=192.168.20.42
k8s-worker04 ansible_host=192.168.20.43
k8s-worker05 ansible_host=192.168.20.44
k8s-worker06 ansible_host=192.168.20.45
```

### Key Playbooks

| Playbook | Purpose |
|----------|---------|
| `services/deploy-*.yml` | Deploy individual services |
| `monitoring/deploy-grafana-dashboard.yml` | Deploy Grafana dashboards |
| `glance/backup-glance.yml` | Backup Glance config |
| `glance/restore-glance.yml` | Restore Glance from backup |

## GitLab CI/CD

### Pipeline Stages

1. **Build** - Build Docker images
2. **Test** - Run tests
3. **Deploy** - Deploy to hosts via Ansible

### Runner Configuration

| Setting | Value |
|---------|-------|
| **Host** | gitlab-runner-vm01 (192.168.40.24) |
| **Executor** | Docker |
| **Tags** | homelab, docker |

---

# Monitoring & Observability

## Metrics Stack

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Services  │────►│ Prometheus  │────►│   Grafana   │
│  (exporters)│     │  (metrics)  │     │ (dashboards)│
└─────────────┘     └─────────────┘     └─────────────┘
```

### Prometheus Targets

| Target | Endpoint | Metrics |
|--------|----------|---------|
| Proxmox | :9221 | Node, VM, container stats |
| Node Exporter | :9100 | System metrics |
| Docker | :9323 | Container metrics |
| Traefik | :8082/metrics | Request metrics |

### Grafana Dashboards

| Dashboard | ID | Purpose |
|-----------|----|---------|
| Container Status History | container-status | Docker container status over time |
| Synology NAS Storage | synology-nas-modern | NAS disk and volume stats |
| Omada Network Overview | omada-network | Network device metrics |

## Tracing Stack

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Services  │────►│    OTEL     │────►│   Jaeger    │
│  (traces)   │     │  Collector  │     │  (viewer)   │
└─────────────┘     └─────────────┘     └─────────────┘
```

### OTEL Endpoints

| Protocol | Port | Purpose |
|----------|------|---------|
| gRPC | 4317 | OTLP receiver |
| HTTP | 4318 | OTLP receiver |
| Metrics | 8888 | Collector metrics |
| Pipeline | 8889 | Exporter metrics |

## Status Monitoring

### Uptime Kuma

Monitors all service endpoints with:
- HTTP/HTTPS checks
- TCP port checks
- Response time tracking
- Alerting via Discord

### Glance Dashboard

Central dashboard showing:
- Service status monitors
- Grafana dashboard embeds
- Media statistics
- System metrics

---

# Security & Access

## SSH Access

### SSH Configuration

```bash
# ~/.ssh/config
Host node01
    HostName 192.168.20.20
    User root
    IdentityFile ~/.ssh/homelab_ed25519

Host node02
    HostName 192.168.20.21
    User root
    IdentityFile ~/.ssh/homelab_ed25519

Host ansible
    HostName 192.168.20.30
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host docker-utilities
    HostName 192.168.40.10
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host docker-media
    HostName 192.168.40.11
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host traefik
    HostName 192.168.40.20
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519
```

### SSH Key

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAby7br+5MzyDus2fi2UFjUBZvGucN40Gxa29bgUTbfz hermes@homelab
```

## Authentication

### Authentik SSO

Most services use Authentik for SSO via:
- OAuth2/OIDC
- Forward Auth (Traefik middleware)

### Forward Auth Configuration

```yaml
# Traefik dynamic config
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
```

---

# Operations Reference

## Service Deployment Workflow

1. **Create VM/LXC** via Terraform
2. **Configure host** via Ansible
3. **Deploy service** via Docker Compose
4. **Add Traefik route**
5. **Configure DNS** in Pi-hole
6. **Add Authentik protection** (if needed)
7. **Add to monitoring** (Uptime Kuma, Glance)
8. **Update documentation**

## Common Operations

### Restart Services

```bash
# Glance
ssh docker-utilities "cd /opt/glance && docker compose restart"

# Grafana
ssh docker-utilities "cd /opt/monitoring && docker compose restart grafana"

# Traefik
ssh traefik "cd /opt/traefik && docker compose restart"
```

### View Logs

```bash
# Container logs
ssh docker-utilities "docker logs glance --tail 100"

# Proxmox cluster logs
ssh node01 "journalctl -u corosync -n 50"
```

### Backup Operations

```bash
# Backup Glance config
ansible-playbook ansible-playbooks/glance/backup-glance.yml

# Restore Glance
ansible-playbook ansible-playbooks/glance/restore-glance.yml
```

## Watchtower Updates

Container updates are managed via Watchtower with Discord notifications:

1. Watchtower detects update
2. Argus bot sends update notification to Discord
3. User approves/rejects via reaction
4. Update proceeds or is skipped

---

# Quick Reference

## Command Cheatsheet

### Proxmox

```bash
# Cluster status
pvecm status

# Node resources
pvesh get /cluster/resources --type node

# List VMs
qm list

# Start/stop VM
qm start <vmid>
qm stop <vmid>
```

### Docker

```bash
# List containers
docker ps -a

# View logs
docker logs <container> --tail 100 -f

# Restart container
docker restart <container>

# Update containers
docker compose pull && docker compose up -d
```

### Kubernetes

```bash
# Get nodes
kubectl get nodes

# Get pods
kubectl get pods -A

# Describe pod
kubectl describe pod <pod> -n <namespace>
```

### Ansible

```bash
# Ping all hosts
ansible all -m ping

# Run playbook
ansible-playbook playbook.yml

# Run with limit
ansible-playbook playbook.yml -l docker_hosts
```

## Emergency Contacts

| Service | Action | Command |
|---------|--------|---------|
| Proxmox Down | SSH via Tailscale | `ssh root@100.89.33.5` |
| Container Issues | Check Docker | `docker ps -a && docker logs <name>` |
| Network Issues | Check Pi-hole | `ssh root@192.168.90.53` |

## Related Documentation

- [NETWORKING.md](./NETWORKING.md) - Network deep dive
- [PROXMOX.md](./PROXMOX.md) - Proxmox configuration
- [SERVICES.md](./SERVICES.md) - Service details
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Common issues
- [SERVICE_ONBOARDING.md](./SERVICE_ONBOARDING.md) - Adding new services

---

*This wiki is the authoritative reference for the MorpheusCluster homelab. For step-by-step tutorials, see the [Complete Homelab Guide](../Obsidian/Book%20-%20The%20Complete%20Homelab%20Guide.md).*
