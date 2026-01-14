# IP Address Map

> **Internal Documentation** - Complete IP allocation for all VLANs.

Related: [[00 - Homelab Index]] | [[01 - Network Architecture]] | [[07 - Deployed Services]]

---

## VLAN 20 - Homelab Infrastructure (192.168.20.0/24)

### Proxmox Cluster

| IP | Hostname | Purpose |
|----|----------|---------|
| 192.168.20.1 | Gateway | VLAN 20 Gateway |
| 192.168.20.20 | node01 | Proxmox Node (VM Host) |
| 192.168.20.21 | node02 | Proxmox Node (LXC Host) |
| 192.168.20.22 | node03 | Proxmox Node (K8s Host) |

### Automation & Storage

| IP | Hostname | Purpose |
|----|----------|---------|
| 192.168.20.30 | ansible-controller01 | Ansible automation |
| 192.168.20.31 | synology-nas | Synology NAS (NFS storage) |

### Kubernetes Control Plane

| IP | Hostname | Purpose |
|----|----------|---------|
| 192.168.20.32 | k8s-controller01 | K8s Primary |
| 192.168.20.33 | k8s-controller02 | K8s HA |
| 192.168.20.34 | k8s-controller03 | K8s HA |

### Kubernetes Workers

| IP | Hostname | Purpose |
|----|----------|---------|
| 192.168.20.40 | k8s-worker01 | K8s Worker |
| 192.168.20.41 | k8s-worker02 | K8s Worker |
| 192.168.20.42 | k8s-worker03 | K8s Worker |
| 192.168.20.43 | k8s-worker04 | K8s Worker |
| 192.168.20.44 | k8s-worker05 | K8s Worker |
| 192.168.20.45 | k8s-worker06 | K8s Worker |

### Reserved Ranges

| Range | Purpose |
|-------|---------|
| 192.168.20.46-99 | Additional K8s nodes |
| 192.168.20.100-199 | LXC containers |
| 192.168.20.200-254 | Future VMs |

---

## VLAN 40 - Production Services (192.168.40.0/24)

### Docker Hosts & LXC Containers

| IP | Hostname | Purpose |
|----|----------|---------|
| 192.168.40.1 | Gateway | VLAN 40 Gateway |
| 192.168.40.5 | linux-syslog-server01 | Centralized logging |
| 192.168.40.10 | ~~docker-vm-core-utilities01~~ | **DECOMMISSIONED** - Replaced by 192.168.40.12 & 192.168.40.13 |
| 192.168.40.11 | docker-vm-media01 | Arr Media Stack |
| 192.168.40.12 | lxc-glance (LXC 200) | Glance Dashboard |
| 192.168.40.13 | docker-vm-core-utilities-1 | n8n, Paperless, Speedtest, Monitoring Stack, Karakeep, Wizarr, Tracearr |

### Core Application Services

| IP | Hostname | Purpose |
|----|----------|---------|
| 192.168.40.20 | traefik-lxc (LXC 203) | Reverse Proxy |
| 192.168.40.21 | authentik-lxc (LXC 204) | Identity/SSO |
| 192.168.40.22 | immich-vm01 | Photo Management |
| 192.168.40.23 | gitlab-vm01 | DevOps Platform |
| 192.168.40.24 | gitlab-runner-vm01 | GitLab CI/CD Runner |
| 192.168.40.25 | homeassistant-lxc (LXC 206) | Home Assistant Smart Home |

### Reserved Ranges

| Range | Purpose |
|-------|---------|
| 192.168.40.14-19 | Additional Docker hosts |
| 192.168.40.24-39 | Monitoring & additional services |
| 192.168.40.40-254 | Future services |

---

## VLAN 90 - Management (192.168.90.0/24)

| IP | Device | Purpose |
|----|--------|---------|
| 192.168.90.1 | Gateway | VLAN 90 Gateway |
| 192.168.90.2 | SG3210 | Core Switch |
| 192.168.90.3 | SG2210P | Morpheus Switch |
| 192.168.90.10 | EAP610 | Living Room WiFi AP |
| 192.168.90.11 | EAP603 | Outdoor WiFi AP |
| 192.168.90.12 | EAP225 | Computer Room WiFi AP |
| 192.168.90.51 | ES20GP | Atreus Switch |

---

## VLAN 91 - Firewall (192.168.91.0/24)

| IP | Device | Purpose |
|----|--------|---------|
| 192.168.91.1 | Gateway | VLAN 91 Gateway |
| 192.168.91.30 | OPNsense | Firewall/DNS |

---

## Other VLANs

### VLAN 10 - Internal LAN

- 192.168.10.0/24
- Workstations, NAS access

### VLAN 30 - IoT

- 192.168.30.0/24
- IoT WiFi devices

### VLAN 50 - Guest

- 192.168.50.0/24
- Guest WiFi access

### VLAN 60 - Sonos

- 192.168.60.0/24
- Sonos speakers

---

## Related Documentation

- [[01 - Network Architecture]] - VLAN configuration
- [[02 - Proxmox Cluster]] - Node details
- [[07 - Deployed Services]] - Service details

