# Homelab Master Wiki

> **The Complete Technical Reference for MorpheusCluster Homelab**
>
> This document serves as the authoritative wiki and encyclopedia for the entire homelab infrastructure. For step-by-step tutorials, see [[Book - The Complete Homelab Guide]].

Related: [[00 - Homelab Index]] | [[11 - Credentials]] | [[10 - IP Address Map]]

---

## Table of Contents

1. [[#Infrastructure Overview]]
2. [[#Network Architecture]]
3. [[#Compute Infrastructure]]
4. [[#Storage Architecture]]
5. [[#Tech Stack Reference]]
6. [[#Services Catalog]]
7. [[#Automation & DevOps]]
8. [[#Monitoring & Observability]]
9. [[#Security & Access]]
10. [[#Operations Reference]]
11. [[#Quick Reference]]

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

See also: [[01 - Network Architecture]]

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

See [[10 - IP Address Map]] for complete details.

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

See also: [[02 - Proxmox Cluster]]

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

See [[07 - Deployed Services]] for complete VM inventory.

### VLAN 20 VMs (Infrastructure)

| Hostname | Node | IP | Cores | RAM | Purpose |
|----------|------|----|-------|-----|---------|
| ansible-controller01 | node01 | 192.168.20.30 | 2 | 8GB | Ansible automation |
| k8s-controller01-03 | node01 | 192.168.20.32-34 | 2 | 8GB | K8s control plane |
| k8s-worker01-06 | node01 | 192.168.20.40-45 | 2 | 8GB | K8s workers |

### VLAN 40 VMs (Services)

| Hostname | Node | IP | Cores | RAM | Purpose |
|----------|------|----|-------|-----|---------|
| docker-vm-media01 | node01 | 192.168.40.11 | 2 | 12GB | Arr media stack |
| docker-vm-core-utilities01 | node01 | 192.168.40.13 | 4 | 12GB | Monitoring stack |
| traefik-vm01 | node02 | 192.168.40.20 | 2 | 8GB | Reverse proxy |
| authentik-vm01 | node02 | 192.168.40.21 | 2 | 8GB | Identity/SSO |
| immich-vm01 | node02 | 192.168.40.22 | 10 | 12GB | Photo management |
| gitlab-vm01 | node02 | 192.168.40.23 | 2 | 8GB | DevOps platform |

## LXC Containers

| Hostname | VMID | Node | IP | Cores | RAM | Purpose |
|----------|------|------|----|-------|-----|---------|
| docker-lxc-glance | 200 | node01 | 192.168.40.12 | 2 | 4GB | Glance, APIs |
| docker-lxc-bots | 201 | node01 | 192.168.40.14 | 2 | 2GB | Discord bots |
| pihole | 202 | node01 | 192.168.90.53 | 2 | 1GB | Pi-hole + Unbound |

## Kubernetes Cluster

See [[04 - Kubernetes Cluster]] for details.

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

See also: [[03 - Storage Architecture]]

## Synology NAS

| Setting | Value |
|---------|-------|
| **Model** | Synology DS920+ |
| **IP (VLAN 10)** | 192.168.10.31 |
| **IP (VLAN 20)** | 192.168.20.31 |
| **Protocol** | NFS v3/v4 |

### NFS Exports

| Export | Mount Point | Purpose |
|--------|-------------|---------|
| /volume1/VMDisks | /mnt/synology/VMDisks | Proxmox VM storage |
| /volume1/ISOImages | /mnt/synology/ISOImages | ISO storage |
| /volume1/HomelabBackups | /mnt/synology/Backups | VM backups |
| /volume1/media | /mnt/media | Media files |
| /volume1/torrents | /mnt/torrents | Download staging |

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

See [[08 - Arr Media Stack]] for details.

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

### docker-vm-core-utilities01 (192.168.40.13)

See [[17 - Monitoring Stack]] and [[18 - Observability Stack]].

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

See [[23 - Glance Dashboard]].

| Service | Port | Purpose |
|---------|------|---------|
| Glance | 8080 | Dashboard |
| Media Stats API | 5050 | Arr integration |
| Reddit Manager | 5052 | Reddit feed API |
| NBA Stats API | 5054 | Sports data |
| Pi-hole Stats API | 5055 | DNS stats |

### docker-lxc-bots (192.168.40.14)

See [[24 - Discord Bots]].

| Service | Port | Purpose |
|---------|------|---------|
| Argus Bot | - | Container update notifications |
| Chronos Bot | - | Project management |
| Athena API | 5051 | Task queue API |

---

# Services Catalog

See [[07 - Deployed Services]] for complete list.

## Service URLs

### Infrastructure Services

| Service | Internal URL | External URL |
|---------|--------------|--------------|
| Proxmox Cluster | https://192.168.20.21:8006 | https://proxmox.hrmsmrflrii.xyz |
| Traefik Dashboard | http://192.168.40.20:8080 | https://traefik.hrmsmrflrii.xyz |
| Pi-hole | http://192.168.90.53/admin | https://pihole.hrmsmrflrii.xyz |

### Core Services

| Service | Internal URL | External URL | Auth |
|---------|--------------|--------------|------|
| Authentik | http://192.168.40.21:9000 | https://auth.hrmsmrflrii.xyz | - |
| Immich | http://192.168.40.22:2283 | https://photos.hrmsmrflrii.xyz | Authentik |
| GitLab | http://192.168.40.23:80 | https://gitlab.hrmsmrflrii.xyz | Built-in |

### Media Services

| Service | External URL | Auth |
|---------|--------------|------|
| Jellyfin | https://jellyfin.hrmsmrflrii.xyz | Built-in |
| Radarr | https://radarr.hrmsmrflrii.xyz | Authentik |
| Sonarr | https://sonarr.hrmsmrflrii.xyz | Authentik |
| Lidarr | https://lidarr.hrmsmrflrii.xyz | Authentik |
| Prowlarr | https://prowlarr.hrmsmrflrii.xyz | Authentik |
| Bazarr | https://bazarr.hrmsmrflrii.xyz | Authentik |
| Overseerr | https://overseerr.hrmsmrflrii.xyz | Built-in |
| Jellyseerr | https://jellyseerr.hrmsmrflrii.xyz | Built-in |

### Monitoring Services

| Service | External URL | Auth |
|---------|--------------|------|
| Glance | https://glance.hrmsmrflrii.xyz | None |
| Grafana | https://grafana.hrmsmrflrii.xyz | Authentik |
| Prometheus | https://prometheus.hrmsmrflrii.xyz | Authentik |
| Uptime Kuma | https://uptime.hrmsmrflrii.xyz | Authentik |
| Jaeger | https://jaeger.hrmsmrflrii.xyz | Authentik |

---

# Automation & DevOps

## Terraform

See [[05 - Terraform Configuration]] for details.

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

## Ansible

See [[06 - Ansible Automation]] for details.

### Key Playbooks

| Playbook | Purpose |
|----------|---------|
| `services/deploy-*.yml` | Deploy individual services |
| `monitoring/deploy-grafana-dashboard.yml` | Deploy Grafana dashboards |
| `glance/backup-glance.yml` | Backup Glance config |
| `glance/restore-glance.yml` | Restore Glance from backup |

## GitLab CI/CD

See [[20 - GitLab CI-CD Automation]] for details.

---

# Monitoring & Observability

See [[17 - Monitoring Stack]] and [[18 - Observability Stack]].

## Metrics Stack

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Services  │────►│ Prometheus  │────►│   Grafana   │
│  (exporters)│     │  (metrics)  │     │ (dashboards)│
└─────────────┘     └─────────────┘     └─────────────┘
```

## Tracing Stack

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Services  │────►│    OTEL     │────►│   Jaeger    │
│  (traces)   │     │  Collector  │     │  (viewer)   │
└─────────────┘     └─────────────┘     └─────────────┘
```

---

# Security & Access

## SSH Access

See [[16 - SSH Configuration]] for full details.

### Quick SSH Reference

```bash
ssh node01              # Proxmox node01
ssh node02              # Proxmox node02
ssh ansible             # Ansible controller
ssh docker-utilities    # Docker utilities host
ssh docker-media        # Media services host
ssh traefik             # Traefik reverse proxy
```

## Authentication

See [[14 - Authentik Google SSO Setup]] for SSO configuration.

Most services use Authentik for SSO via:
- OAuth2/OIDC
- Forward Auth (Traefik middleware)

---

# Operations Reference

## Service Deployment Workflow

See [[15 - New Service Onboarding Guide]] and [[22 - Service Onboarding Workflow]].

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

## Watchtower Updates

See [[19 - Watchtower Updates]].

---

# Quick Reference

## Command Cheatsheet

### Proxmox

```bash
pvecm status                              # Cluster status
pvesh get /cluster/resources --type node  # Node resources
qm list                                   # List VMs
qm start <vmid>                           # Start VM
qm stop <vmid>                            # Stop VM
```

### Docker

```bash
docker ps -a                              # List containers
docker logs <container> --tail 100 -f     # View logs
docker restart <container>                # Restart container
docker compose pull && docker compose up -d  # Update containers
```

### Kubernetes

```bash
kubectl get nodes                         # Get nodes
kubectl get pods -A                       # Get all pods
kubectl describe pod <pod> -n <namespace> # Describe pod
```

### Ansible

```bash
ansible all -m ping                       # Ping all hosts
ansible-playbook playbook.yml             # Run playbook
ansible-playbook playbook.yml -l docker_hosts  # Run with limit
```

## Emergency Contacts

| Service | Action | Command |
|---------|--------|---------|
| Proxmox Down | SSH via Tailscale | `ssh root@100.89.33.5` |
| Container Issues | Check Docker | `docker ps -a && docker logs <name>` |
| Network Issues | Check Pi-hole | `ssh root@192.168.90.53` |

---

## Related Documentation

- [[01 - Network Architecture]] - Network deep dive
- [[02 - Proxmox Cluster]] - Proxmox configuration
- [[07 - Deployed Services]] - Service details
- [[12 - Troubleshooting]] - Common issues
- [[15 - New Service Onboarding Guide]] - Adding new services

---

*This wiki is the authoritative reference for the MorpheusCluster homelab. For step-by-step tutorials, see [[Book - The Complete Homelab Guide]].*
