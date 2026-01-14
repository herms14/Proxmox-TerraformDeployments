# Omada ACL Implementation Guide

#homelab #networking #security #omada #acl

Step-by-step guide for implementing network segmentation rules on the TP-Link Omada OC300 controller.

**Controller URL**: https://192.168.0.103 (or https://omada.hrmsmrflrii.xyz)
**Estimated Time**: 30-45 minutes

---

## Table of Contents

1. [ACL Types Explained](#acl-types-explained)
2. [Prerequisites](#prerequisites)
3. [Part 1: Create IP Groups](#part-1-create-ip-groups)
4. [Part 2: Create Gateway ACL Rules](#part-2-create-gateway-acl-rules) (with explanations for each rule)
5. [Part 3: Verify Rule Order](#part-3-verify-rule-order)
6. [Part 4: Comprehensive Testing](#part-4-testing) (test each rule set)
7. [Troubleshooting](#troubleshooting)

---

## ACL Types Explained

Omada controllers support three types of ACLs. **All rules in this guide are Gateway ACLs** because they control inter-VLAN (Layer 3) routing.

| ACL Type | Layer | Use Case | When to Use |
|----------|-------|----------|-------------|
| **Gateway ACL** | L3 (Network) | Inter-VLAN traffic control | Blocking/allowing traffic between different VLANs/subnets |
| **Switch ACL** | L2 (Data Link) | Port/MAC-based filtering | Intra-VLAN filtering, port isolation, MAC filtering on switches |
| **EAP ACL** | L2/L3 | Wireless client filtering | Per-SSID policies, wireless client isolation |

### Why All Rules Here Are Gateway ACL

All 62 rules in this guide control traffic **between VLANs** (e.g., VLAN 50 Guest to VLAN 20 Infrastructure). This is Layer 3 routing, which requires Gateway ACL.

**Switch ACL would be used for:**
- Blocking specific switch ports
- MAC address filtering within a VLAN
- Preventing communication between devices on the same VLAN

**EAP ACL would be used for:**
- Isolating wireless clients from each other
- Restricting specific SSIDs from accessing certain resources
- Per-wireless-network policies

---

## Prerequisites

1. Login to Omada Controller: https://192.168.0.103
2. Navigate to the site (Default or your configured site)
3. Ensure you have admin privileges

---

## Part 1: Create IP Groups

**Navigation**: Settings → Profiles → Groups → IP Group → + Create New IP Group

Create each of the following IP groups:

### Infrastructure Groups

| Group Name | IP Addresses | Purpose |
|------------|--------------|---------|
| `PROXMOX_NODES` | 192.168.20.20, 192.168.20.21, 192.168.20.22 | Proxmox cluster nodes |
| `K8S_CONTROLLERS` | 192.168.20.32, 192.168.20.33, 192.168.20.34 | Kubernetes control plane |
| `K8S_WORKERS` | 192.168.20.40, 192.168.20.41, 192.168.20.42, 192.168.20.43, 192.168.20.44, 192.168.20.45 | Kubernetes worker nodes |
| `SYNOLOGY_NAS` | 192.168.20.31 | Synology NAS |
| `PBS_SERVER` | 192.168.20.50 | Proxmox Backup Server |
| `ANSIBLE` | 192.168.20.30 | Ansible controller |

### Service Groups

| Group Name | IP Addresses | Purpose |
|------------|--------------|---------|
| `DOCKER_MEDIA` | 192.168.40.11 | Media stack (Jellyfin, *arr) |
| `DOCKER_GLANCE` | 192.168.40.12 | Glance dashboard |
| `DOCKER_UTILITIES` | 192.168.40.13 | Grafana, Prometheus, Sentinel |
| `TRAEFIK` | 192.168.40.20 | Reverse proxy |
| `AUTHENTIK` | 192.168.40.21 | SSO/Identity |
| `IMMICH` | 192.168.40.22 | Photo management |
| `GITLAB` | 192.168.40.23 | DevOps platform |
| `GITLAB_RUNNER` | 192.168.40.24 | CI/CD runner |

### Network Services Groups

| Group Name | IP Addresses | Purpose |
|------------|--------------|---------|
| `PIHOLE` | 192.168.90.53 | DNS server |
| `OPNSENSE` | 192.168.91.30 | Firewall/DNS |

### Management Groups

| Group Name | IP Addresses | Purpose |
|------------|--------------|---------|
| `MANAGEMENT_PC` | 192.168.10.10 | Kratos PC - full management access |

### How to Create Each Group

1. Click **+ Create New IP Group**
2. Enter the **Name** exactly as shown (case-sensitive)
3. In **IP Address List**, enter each IP on a new line or comma-separated
4. Click **Create**
5. Repeat for all 17 groups

---

## Part 2: Create Gateway ACL Rules

**Navigation**: Settings → Network Security → ACL → Gateway ACL → + Add

> **IMPORTANT**: All rules below are **Gateway ACL** rules. Do NOT create these as Switch ACL or EAP ACL.

**IMPORTANT**: Rules are processed top-to-bottom. Create them in the order listed below.

### Rule Set 1: Universal DNS Access (Priority: Highest)

**ACL Type: Gateway ACL**

| # | Name | Policy | Source | Destination | Protocol | Port |
|---|------|--------|--------|-------------|----------|------|
| 1 | `DNS-to-PiHole` | Permit | All | IP Group: PIHOLE | TCP/UDP | 53 |
| 2 | `DNS-to-OPNsense` | Permit | All | IP Group: OPNSENSE | TCP/UDP | 53 |

**What These Rules Do:**
- **Rule 1-2**: Allow ALL devices on ALL VLANs to query DNS servers (Pi-hole and OPNsense). Without these rules, devices would lose internet connectivity because they couldn't resolve domain names. These rules are placed FIRST so they're evaluated before any deny rules.

**Expected Behavior:**
- Any device can resolve DNS queries via Pi-hole (192.168.90.53) or OPNsense (192.168.91.30)
- Guest devices can still use the internet (DNS works)
- IoT devices can still reach cloud services (DNS works)

---

### Rule Set 2: Guest Network Isolation (VLAN 50)

**ACL Type: Gateway ACL**

| # | Name | Policy | Source | Destination | Protocol | Port |
|---|------|--------|--------|-------------|----------|------|
| 3 | `Guest-Block-VLAN10` | Deny | Network: 192.168.50.0/24 | Network: 192.168.10.0/24 | All | All |
| 4 | `Guest-Block-VLAN20` | Deny | Network: 192.168.50.0/24 | Network: 192.168.20.0/24 | All | All |
| 5 | `Guest-Block-VLAN30` | Deny | Network: 192.168.50.0/24 | Network: 192.168.30.0/24 | All | All |
| 6 | `Guest-Block-VLAN40` | Deny | Network: 192.168.50.0/24 | Network: 192.168.40.0/24 | All | All |
| 7 | `Guest-Block-VLAN60` | Deny | Network: 192.168.50.0/24 | Network: 192.168.60.0/24 | All | All |
| 8 | `Guest-Block-VLAN90` | Deny | Network: 192.168.50.0/24 | Network: 192.168.90.0/24 | All | All |
| 9 | `Guest-Block-VLAN91` | Deny | Network: 192.168.50.0/24 | Network: 192.168.91.0/24 | All | All |

**What These Rules Do:**
- **Rules 3-9**: Block Guest WiFi users from accessing ANY internal network. Guests can only access the internet, nothing else. This protects your homelab from untrusted devices.

**Expected Behavior:**
- Guest on 192.168.50.x **CANNOT** ping, SSH, or access any service on VLANs 10, 20, 30, 40, 60, 90, or 91
- Guest on 192.168.50.x **CAN** access the internet (DNS allowed via Rules 1-2, internet routed normally)
- A malicious guest cannot scan your network or attack internal services

**Why This Matters:**
- Visitors' phones/laptops are untrusted - they might have malware
- Prevents guests from accidentally (or intentionally) accessing your NAS, Proxmox, or services
- Standard security practice for any network with guest access

---

### Rule Set 3: IoT Isolation (VLAN 30)

**ACL Type: Gateway ACL**

| # | Name | Policy | Source | Destination | Protocol | Port |
|---|------|--------|--------|-------------|----------|------|
| 10 | `IoT-Block-VLAN10` | Deny | Network: 192.168.30.0/24 | Network: 192.168.10.0/24 | All | All |
| 11 | `IoT-Block-VLAN20` | Deny | Network: 192.168.30.0/24 | Network: 192.168.20.0/24 | All | All |
| 12 | `IoT-Block-VLAN40` | Deny | Network: 192.168.30.0/24 | Network: 192.168.40.0/24 | All | All |
| 13 | `IoT-Block-VLAN50` | Deny | Network: 192.168.30.0/24 | Network: 192.168.50.0/24 | All | All |
| 14 | `IoT-Block-VLAN60` | Deny | Network: 192.168.30.0/24 | Network: 192.168.60.0/24 | All | All |

**What These Rules Do:**
- **Rules 10-14**: Block IoT devices (smart plugs, cameras, sensors, etc.) from accessing your trusted networks. IoT devices are notoriously insecure and are common attack vectors.

**Expected Behavior:**
- Smart TV on 192.168.30.x **CANNOT** access your workstation, NAS, or Docker services
- IoT device on 192.168.30.x **CAN** access the internet (for cloud services like Tuya, Alexa, etc.)
- IoT device on 192.168.30.x **CAN** use DNS (Rules 1-2)
- Compromised IoT device cannot pivot to attack your infrastructure

**Why This Matters:**
- IoT devices often have poor security, outdated firmware, and known vulnerabilities
- A compromised smart bulb could be used to attack your NAS or Proxmox cluster
- Many IoT devices "phone home" to China - isolating them limits exposure
- Prevents IoT botnets from spreading to your trusted network

---

### Rule Set 4: Management PC Full Access (Kratos)

**ACL Type: Gateway ACL**

**These rules give the management PC (192.168.10.10) full access to all infrastructure:**

| # | Name | Policy | Source | Destination | Protocol | Port |
|---|------|--------|--------|-------------|----------|------|
| 15 | `MgmtPC-to-VLAN20` | Permit | IP Group: MANAGEMENT_PC | Network: 192.168.20.0/24 | All | All |
| 16 | `MgmtPC-to-VLAN40` | Permit | IP Group: MANAGEMENT_PC | Network: 192.168.40.0/24 | All | All |
| 17 | `MgmtPC-to-VLAN90` | Permit | IP Group: MANAGEMENT_PC | Network: 192.168.90.0/24 | All | All |
| 18 | `MgmtPC-to-VLAN91` | Permit | IP Group: MANAGEMENT_PC | Network: 192.168.91.0/24 | All | All |

**What These Rules Do:**
- **Rules 15-18**: Grant your primary management workstation (Kratos - 192.168.10.10) unrestricted access to ALL infrastructure. This bypasses the restrictions placed on other VLAN 10 devices.

**Expected Behavior:**
- Kratos **CAN** SSH directly to Proxmox nodes, Docker hosts, and any server
- Kratos **CAN** access all web UIs directly (Proxmox, NAS DSM, Radarr, etc.) without going through Traefik
- Kratos **CAN** manage Pi-hole and OPNsense directly
- Kratos **CAN** do anything - it's your trusted admin workstation

**Why This Matters:**
- You need ONE trusted PC with full access for administration and troubleshooting
- If Traefik goes down, you can still access services directly from Kratos
- Makes debugging and emergency maintenance possible
- These rules are placed BEFORE the VLAN 10 deny rules (Rules 27-28), so they take precedence

**Security Note:**
- Only your Kratos PC (192.168.10.10) gets this access - ensure this IP is statically assigned
- Keep this machine secure with strong passwords, updates, and endpoint protection

---

### Rule Set 5: Internal Workstations Access (VLAN 10)

**ACL Type: Gateway ACL**

**Allow specific services for other VLAN 10 devices, then block remaining:**

| # | Name | Policy | Source | Destination | Protocol | Port |
|---|------|--------|--------|-------------|----------|------|
| 19 | `Internal-to-Traefik-HTTP` | Permit | Network: 192.168.10.0/24 | IP Group: TRAEFIK | TCP | 80,443 |
| 20 | `Internal-to-Proxmox-UI` | Permit | Network: 192.168.10.0/24 | IP Group: PROXMOX_NODES | TCP | 8006 |
| 21 | `Internal-to-NAS-DSM` | Permit | Network: 192.168.10.0/24 | IP Group: SYNOLOGY_NAS | TCP | 5000,5001 |
| 22 | `Internal-to-NAS-Plex` | Permit | Network: 192.168.10.0/24 | IP Group: SYNOLOGY_NAS | TCP | 32400 |
| 23 | `Internal-to-PBS-UI` | Permit | Network: 192.168.10.0/24 | IP Group: PBS_SERVER | TCP | 8007 |
| 24 | `Internal-to-Grafana` | Permit | Network: 192.168.10.0/24 | IP Group: DOCKER_UTILITIES | TCP | 3030 |
| 25 | `Internal-to-Jellyfin` | Permit | Network: 192.168.10.0/24 | IP Group: DOCKER_MEDIA | TCP | 8096 |
| 26 | `Internal-SSH-Ansible` | Permit | Network: 192.168.10.0/24 | IP Group: ANSIBLE | TCP | 22 |
| 27 | `Internal-Block-VLAN20` | Deny | Network: 192.168.10.0/24 | Network: 192.168.20.0/24 | All | All |
| 28 | `Internal-Block-VLAN40` | Deny | Network: 192.168.10.0/24 | Network: 192.168.40.0/24 | All | All |

**What These Rules Do:**
- **Rules 19-26**: Allow other VLAN 10 devices (not Kratos) to access specific services they need:
  - Rule 19: Access all services via Traefik reverse proxy (primary access method)
  - Rule 20: View Proxmox Web UI (but not SSH)
  - Rule 21-22: Access NAS for file management and Plex streaming
  - Rule 23: View PBS backup status
  - Rule 24-25: Direct access to Grafana and Jellyfin
  - Rule 26: SSH to Ansible for automation work
- **Rules 27-28**: Block ALL other access to VLAN 20 and VLAN 40

**Expected Behavior:**
- Laptop on VLAN 10 **CAN** access `https://grafana.hrmsmrflrii.xyz` (via Traefik)
- Laptop on VLAN 10 **CAN** access `https://192.168.20.20:8006` (Proxmox Web UI direct)
- Laptop on VLAN 10 **CAN** SSH to Ansible for playbook execution
- Laptop on VLAN 10 **CANNOT** SSH to Proxmox nodes directly
- Laptop on VLAN 10 **CANNOT** access Radarr directly (must use Traefik)
- This provides "least privilege" - users get what they need, nothing more

**Why This Matters:**
- Most users on VLAN 10 should access services via Traefik (with Authentik SSO)
- Limits blast radius if a VLAN 10 device is compromised
- Only Kratos (Rules 15-18) gets full admin access

---

### Rule Set 6: Infrastructure Internal (VLAN 20)

**ACL Type: Gateway ACL**

| # | Name | Policy | Source | Destination | Protocol | Port |
|---|------|--------|--------|-------------|----------|------|
| 29 | `Proxmox-Inter-Node` | Permit | IP Group: PROXMOX_NODES | IP Group: PROXMOX_NODES | All | All |
| 30 | `Proxmox-to-NAS-NFS` | Permit | IP Group: PROXMOX_NODES | IP Group: SYNOLOGY_NAS | TCP/UDP | 2049,111 |
| 31 | `Proxmox-to-PBS` | Permit | IP Group: PROXMOX_NODES | IP Group: PBS_SERVER | TCP | 8007 |
| 32 | `K8s-Controllers-Internal` | Permit | IP Group: K8S_CONTROLLERS | IP Group: K8S_CONTROLLERS | All | All |
| 33 | `K8s-Workers-Internal` | Permit | IP Group: K8S_WORKERS | IP Group: K8S_WORKERS | All | All |
| 34 | `K8s-Ctrl-to-Workers` | Permit | IP Group: K8S_CONTROLLERS | IP Group: K8S_WORKERS | All | All |
| 35 | `K8s-Workers-to-Ctrl` | Permit | IP Group: K8S_WORKERS | IP Group: K8S_CONTROLLERS | All | All |
| 36 | `K8s-to-NAS-NFS` | Permit | IP Group: K8S_CONTROLLERS | IP Group: SYNOLOGY_NAS | TCP/UDP | 2049,111 |
| 37 | `Ansible-SSH-VLAN20` | Permit | IP Group: ANSIBLE | Network: 192.168.20.0/24 | TCP | 22 |
| 38 | `Ansible-SSH-VLAN40` | Permit | IP Group: ANSIBLE | Network: 192.168.40.0/24 | TCP | 22 |
| 39 | `PBS-to-NAS-Sync` | Permit | IP Group: PBS_SERVER | IP Group: SYNOLOGY_NAS | TCP/UDP | 2049,111,22 |

**What These Rules Do:**
- **Rule 29**: Allow Proxmox nodes to communicate with each other (required for cluster operations - Corosync, live migration, shared storage)
- **Rule 30**: Allow Proxmox nodes to mount NFS shares from NAS (for VM storage)
- **Rule 31**: Allow Proxmox nodes to send backups to PBS
- **Rules 32-35**: Allow Kubernetes cluster internal communication (control plane ↔ workers)
- **Rule 36**: Allow K8s to mount NFS persistent volumes from NAS
- **Rules 37-38**: Allow Ansible to SSH to all hosts in VLAN 20 and VLAN 40 for configuration management
- **Rule 39**: Allow PBS to sync backups to NAS for offsite storage

**Expected Behavior:**
- Proxmox cluster **WORKS**: live migration, HA, shared storage all function
- Kubernetes cluster **WORKS**: pods can schedule, services can communicate
- Ansible playbooks **WORK**: can configure all infrastructure
- Backups **WORK**: PBS can backup VMs and sync to NAS

**Why This Matters:**
- Infrastructure must communicate internally to function
- Without Rule 29, Proxmox cluster would split-brain and fail
- Without Rules 32-35, Kubernetes would be non-functional
- Without Rules 37-38, you couldn't manage infrastructure with Ansible
- These are the "plumbing" rules that make your homelab work

---

### Rule Set 7: Services Dependencies (VLAN 40)

**ACL Type: Gateway ACL**

| # | Name | Policy | Source | Destination | Protocol | Port |
|---|------|--------|--------|-------------|----------|------|
| 40 | `Services-VLAN40-Internal` | Permit | Network: 192.168.40.0/24 | Network: 192.168.40.0/24 | All | All |
| 41 | `DockerMedia-to-NAS-NFS` | Permit | IP Group: DOCKER_MEDIA | IP Group: SYNOLOGY_NAS | TCP/UDP | 2049,111 |
| 42 | `Immich-to-NAS-NFS` | Permit | IP Group: IMMICH | IP Group: SYNOLOGY_NAS | TCP/UDP | 2049,111 |
| 43 | `Prometheus-Proxmox-Metrics` | Permit | IP Group: DOCKER_UTILITIES | IP Group: PROXMOX_NODES | TCP | 9100 |
| 44 | `Prometheus-NAS-SNMP` | Permit | IP Group: DOCKER_UTILITIES | IP Group: SYNOLOGY_NAS | UDP | 161 |
| 45 | `Prometheus-PBS-Metrics` | Permit | IP Group: DOCKER_UTILITIES | IP Group: PBS_SERVER | TCP | 9101 |
| 46 | `Sentinel-SSH-Proxmox` | Permit | IP Group: DOCKER_UTILITIES | IP Group: PROXMOX_NODES | TCP | 22 |
| 47 | `Glance-to-NAS-API` | Permit | IP Group: DOCKER_GLANCE | IP Group: SYNOLOGY_NAS | TCP | 5000,5001 |
| 48 | `GitLabRunner-to-GitLab` | Permit | IP Group: GITLAB_RUNNER | IP Group: GITLAB | TCP | 80,443 |

**What These Rules Do:**
- **Rule 40**: Allow all VLAN 40 services to communicate with each other (Docker hosts, Traefik, Authentik, etc.)
- **Rule 41**: Allow Docker Media host to mount NFS media shares from NAS (for Jellyfin, *arr stack)
- **Rule 42**: Allow Immich to mount NFS photo storage from NAS
- **Rule 43**: Allow Prometheus to scrape node_exporter metrics from Proxmox nodes
- **Rule 44**: Allow Prometheus to collect SNMP data from Synology NAS
- **Rule 45**: Allow Prometheus to scrape PBS exporter metrics
- **Rule 46**: Allow Sentinel Bot to SSH to Proxmox for power management commands
- **Rule 47**: Allow Glance dashboard to query NAS API for storage stats
- **Rule 48**: Allow GitLab Runner to communicate with GitLab for CI/CD jobs

**Expected Behavior:**
- Jellyfin **CAN** play movies from NAS - media is accessible
- Grafana dashboards **WORK** - Prometheus can scrape all targets
- Glance storage widget **WORKS** - can query NAS API
- Sentinel Bot `/shutdownall` command **WORKS** - can SSH to Proxmox
- GitLab CI/CD pipelines **WORK** - runner can fetch jobs and push results

**Why This Matters:**
- Services need to reach their data sources (NAS, metrics endpoints)
- Without Rule 41, Jellyfin would show "media unavailable"
- Without Rules 43-45, Grafana dashboards would be empty
- Without Rule 46, Sentinel Bot couldn't manage your cluster
- These rules enable your services to function properly

---

### Rule Set 8: Traefik Backend Access

**ACL Type: Gateway ACL**

| # | Name | Policy | Source | Destination | Protocol | Port |
|---|------|--------|--------|-------------|----------|------|
| 49 | `Traefik-to-Media` | Permit | IP Group: TRAEFIK | IP Group: DOCKER_MEDIA | TCP | 7878,8989,8096,8686,9696,6767,5056,8112,8081 |
| 50 | `Traefik-to-Utilities` | Permit | IP Group: TRAEFIK | IP Group: DOCKER_UTILITIES | TCP | 3001,3030,5678,9090,16686,5051 |
| 51 | `Traefik-to-Glance` | Permit | IP Group: TRAEFIK | IP Group: DOCKER_GLANCE | TCP | 8080 |
| 52 | `Traefik-to-Authentik` | Permit | IP Group: TRAEFIK | IP Group: AUTHENTIK | TCP | 9000 |
| 53 | `Traefik-to-Immich` | Permit | IP Group: TRAEFIK | IP Group: IMMICH | TCP | 2283 |
| 54 | `Traefik-to-GitLab` | Permit | IP Group: TRAEFIK | IP Group: GITLAB | TCP | 80,443 |
| 55 | `Traefik-to-PBS` | Permit | IP Group: TRAEFIK | IP Group: PBS_SERVER | TCP | 8007 |
| 56 | `Traefik-to-Proxmox` | Permit | IP Group: TRAEFIK | IP Group: PROXMOX_NODES | TCP | 8006 |

**What These Rules Do:**
- **Rules 49-56**: Allow Traefik reverse proxy to reach all backend services it exposes. Traefik terminates SSL and forwards requests to internal services.

**Port Reference for Rule 49 (Traefik-to-Media):**
| Port | Service |
|------|---------|
| 7878 | Radarr |
| 8989 | Sonarr |
| 8096 | Jellyfin |
| 8686 | Lidarr |
| 9696 | Prowlarr |
| 6767 | Bazarr |
| 5056 | Jellyseerr |
| 8112 | Deluge |
| 8081 | qBittorrent |

**Port Reference for Rule 50 (Traefik-to-Utilities):**
| Port | Service |
|------|---------|
| 3001 | Uptime Kuma |
| 3030 | Grafana |
| 5678 | n8n |
| 9090 | Prometheus |
| 16686 | Jaeger |
| 5051 | Sentinel Webhook |

**Expected Behavior:**
- `https://radarr.hrmsmrflrii.xyz` **WORKS** - Traefik can reach Radarr backend
- `https://grafana.hrmsmrflrii.xyz` **WORKS** - Traefik can reach Grafana backend
- `https://proxmox.hrmsmrflrii.xyz` **WORKS** - Traefik can reach Proxmox Web UI
- All services exposed via Traefik are accessible via their subdomain

**Why This Matters:**
- Traefik is your single entry point for all web services
- Without these rules, all your `*.hrmsmrflrii.xyz` URLs would fail
- Traefik needs to reach backends to proxy requests
- This is the "front door" to your homelab services

---

### Rule Set 9: Sonos (VLAN 60)

**ACL Type: Gateway ACL**

| # | Name | Policy | Source | Destination | Protocol | Port |
|---|------|--------|--------|-------------|----------|------|
| 57 | `Internal-to-Sonos` | Permit | Network: 192.168.10.0/24 | Network: 192.168.60.0/24 | TCP | 1400,1443 |
| 58 | `Sonos-to-NAS-Music` | Permit | Network: 192.168.60.0/24 | IP Group: SYNOLOGY_NAS | TCP/UDP | 2049,111,5000 |
| 59 | `Sonos-Block-VLAN20` | Deny | Network: 192.168.60.0/24 | Network: 192.168.20.0/24 | All | All |
| 60 | `Sonos-Block-VLAN40` | Deny | Network: 192.168.60.0/24 | Network: 192.168.40.0/24 | All | All |

**What These Rules Do:**
- **Rule 57**: Allow workstations (VLAN 10) to control Sonos speakers via the Sonos app (ports 1400, 1443)
- **Rule 58**: Allow Sonos speakers to access music from NAS via NFS and SMB
- **Rules 59-60**: Block Sonos speakers from accessing infrastructure (VLAN 20) and services (VLAN 40)

**Expected Behavior:**
- Sonos app on your phone/laptop **CAN** discover and control speakers
- Sonos speakers **CAN** stream music from your NAS music library
- Sonos speakers **CANNOT** reach Proxmox, Docker, or other sensitive services
- Sonos firmware updates and cloud features still work (internet access allowed)

**Why This Matters:**
- Sonos speakers are IoT devices but need controlled access to function
- They need NAS access for local music libraries but shouldn't access your servers
- Port 1400 is the Sonos control port - required for the app to work
- This is a "semi-trusted" zone - more access than IoT but still restricted

---

### Rule Set 10: Default Inter-VLAN Blocks (Last Rules)

**ACL Type: Gateway ACL**

| # | Name | Policy | Source | Destination | Protocol | Port | Logging |
|---|------|--------|--------|-------------|----------|------|---------|
| 61 | `Block-VLAN40-to-VLAN20` | Deny | Network: 192.168.40.0/24 | Network: 192.168.20.0/24 | All | All | Yes |
| 62 | `Block-VLAN20-to-VLAN40` | Deny | Network: 192.168.20.0/24 | Network: 192.168.40.0/24 | All | All | Yes |

**What These Rules Do:**
- **Rules 61-62**: Block any traffic between VLAN 40 (Services) and VLAN 20 (Infrastructure) that wasn't explicitly allowed by earlier rules. These are "catch-all" deny rules.

**Expected Behavior:**
- Any VLAN 40 → VLAN 20 traffic NOT matching Rules 41-47 is **BLOCKED**
- Any VLAN 20 → VLAN 40 traffic NOT matching Rules 37-38 is **BLOCKED**
- Logging is enabled so you can see what's being blocked

**Why This Matters:**
- **Defense in depth**: Even if you forgot an explicit deny, these catch it
- **Logging helps troubleshooting**: If a new service doesn't work, check the ACL logs
- **Prevents lateral movement**: A compromised service can't easily attack infrastructure
- These rules are LAST because ACLs are processed top-to-bottom - allow rules must come first

**Important Note on Rule Order:**
```
DNS Allow (Rules 1-2)           ← Evaluated first
      ↓
Guest/IoT Deny (Rules 3-14)     ← Blocks untrusted
      ↓
Management PC Allow (Rules 15-18) ← Kratos gets full access
      ↓
Specific Allows (Rules 19-60)   ← Service-specific permits
      ↓
Default Deny (Rules 61-62)      ← Catch-all blocks ← Evaluated last
```

If a packet doesn't match any rule, it's implicitly allowed (Omada default). These explicit deny rules ensure that unmatched inter-VLAN traffic is blocked.

---

## Part 3: Verify Rule Order

After creating all rules, verify they are in the correct order:

1. Navigate to **Settings → Network Security → ACL → Gateway ACL**
2. Rules should be ordered 1-62 as listed above
3. **Drag and drop** to reorder if needed (DNS rules at top, Block rules at bottom)

### Rule Order Verification Checklist

- [ ] Rules 1-2: DNS allow rules at top
- [ ] Rules 3-9: Guest isolation
- [ ] Rules 10-14: IoT isolation
- [ ] Rules 15-18: **Management PC (Kratos) full access**
- [ ] Rules 19-28: Internal workstation access (allows before denies)
- [ ] Rules 29-39: Infrastructure internal communication
- [ ] Rules 40-48: Services dependencies
- [ ] Rules 49-56: Traefik backend access
- [ ] Rules 57-60: Sonos access
- [ ] Rules 61-62: Default deny rules at bottom

---

## Part 4: Testing

Comprehensive testing guide to verify all ACL rules are working correctly.

> **Testing Approach**: For each rule set, test both what SHOULD work (Permit rules) and what SHOULD be BLOCKED (Deny rules). A successful test means permits allow traffic and denies block it.

---

### Test 1: DNS Access (Rules 1-2)

**Test from ANY device on ANY VLAN:**

```bash
# Should WORK - DNS queries to Pi-hole
nslookup google.com 192.168.90.53
dig @192.168.90.53 google.com

# Should WORK - DNS queries to OPNsense
nslookup google.com 192.168.91.30
dig @192.168.91.30 google.com
```

| Test | Command | Expected Result |
|------|---------|-----------------|
| Pi-hole DNS from VLAN 10 | `nslookup google.com 192.168.90.53` | Success |
| Pi-hole DNS from VLAN 50 (Guest) | `nslookup google.com 192.168.90.53` | Success |
| OPNsense DNS from VLAN 30 (IoT) | `nslookup google.com 192.168.91.30` | Success |

---

### Test 2: Guest Network Isolation (Rules 3-9)

**Test from a device on VLAN 50 (Guest) - 192.168.50.x:**

```bash
# Should be BLOCKED - Guest cannot reach internal networks
ping 192.168.10.10      # VLAN 10 - Blocked
ping 192.168.20.20      # VLAN 20 - Blocked
ping 192.168.30.1       # VLAN 30 - Blocked
ping 192.168.40.11      # VLAN 40 - Blocked
ping 192.168.60.1       # VLAN 60 - Blocked
ping 192.168.90.53      # VLAN 90 - Blocked (except DNS port 53)
ping 192.168.91.30      # VLAN 91 - Blocked (except DNS port 53)

# Should WORK - Internet access
ping 8.8.8.8
curl -I https://google.com
```

| Test | From Guest (192.168.50.x) | Expected |
|------|---------------------------|----------|
| Ping workstation | `ping 192.168.10.10` | **BLOCKED** |
| Ping Proxmox | `ping 192.168.20.20` | **BLOCKED** |
| Ping Docker Media | `ping 192.168.40.11` | **BLOCKED** |
| SSH to Ansible | `ssh 192.168.20.30` | **BLOCKED** |
| Access Grafana directly | `curl http://192.168.40.13:3030` | **BLOCKED** |
| Internet | `ping 8.8.8.8` | Success |

---

### Test 3: IoT Isolation (Rules 10-14)

**Test from a device on VLAN 30 (IoT) - 192.168.30.x:**

```bash
# Should be BLOCKED - IoT cannot reach most networks
ping 192.168.10.10      # VLAN 10 - Blocked
ping 192.168.20.20      # VLAN 20 - Blocked
ping 192.168.40.11      # VLAN 40 - Blocked
ping 192.168.50.1       # VLAN 50 - Blocked
ping 192.168.60.1       # VLAN 60 - Blocked

# Should WORK - Internet and DNS
ping 8.8.8.8
nslookup google.com 192.168.90.53
```

| Test | From IoT (192.168.30.x) | Expected |
|------|-------------------------|----------|
| Ping workstation | `ping 192.168.10.10` | **BLOCKED** |
| Ping NAS | `ping 192.168.20.31` | **BLOCKED** |
| Ping Docker | `ping 192.168.40.13` | **BLOCKED** |
| Internet | `ping 8.8.8.8` | Success |

---

### Test 4: Management PC Full Access (Rules 15-18)

**Test from Kratos PC (192.168.10.10):**

```bash
# Should ALL WORK - Full management access
# VLAN 20 Access
ssh root@192.168.20.20                    # Proxmox node01
ssh root@192.168.20.21                    # Proxmox node02
ssh root@192.168.20.22                    # Proxmox node03
ssh hermes-admin@192.168.20.30            # Ansible
curl -k https://192.168.20.20:8006        # Proxmox Web UI
curl http://192.168.20.31:5000            # NAS DSM HTTP
curl -k https://192.168.20.31:5001        # NAS DSM HTTPS

# VLAN 40 Access
ssh hermes-admin@192.168.40.11            # Docker Media
ssh hermes-admin@192.168.40.13            # Docker Utilities
curl http://192.168.40.11:7878            # Radarr direct
curl http://192.168.40.13:3030            # Grafana direct
curl http://192.168.40.20:80              # Traefik direct

# VLAN 90 Access
curl http://192.168.90.53:80              # Pi-hole admin
ssh root@192.168.90.53                    # Pi-hole SSH (if enabled)

# VLAN 91 Access
curl -k https://192.168.91.30             # OPNsense Web UI
ssh root@192.168.91.30                    # OPNsense SSH
```

| Test | From Kratos (192.168.10.10) | Expected |
|------|----------------------------|----------|
| SSH Proxmox node01 | `ssh root@192.168.20.20` | Success |
| SSH Proxmox node02 | `ssh root@192.168.20.21` | Success |
| SSH Ansible | `ssh hermes-admin@192.168.20.30` | Success |
| Proxmox Web UI | `curl -k https://192.168.20.20:8006` | Success |
| NAS DSM | `curl -k https://192.168.20.31:5001` | Success |
| SSH Docker Media | `ssh hermes-admin@192.168.40.11` | Success |
| SSH Docker Utilities | `ssh hermes-admin@192.168.40.13` | Success |
| Radarr direct | `curl http://192.168.40.11:7878` | Success |
| Grafana direct | `curl http://192.168.40.13:3030` | Success |
| Pi-hole admin | `curl http://192.168.90.53/admin` | Success |
| OPNsense WebUI | `curl -k https://192.168.91.30` | Success |

---

### Test 5: Internal Workstations Limited Access (Rules 19-28)

**Test from a non-Kratos workstation on VLAN 10 (e.g., 192.168.10.50):**

```bash
# Should WORK - Allowed services
curl http://192.168.40.20:80              # Traefik HTTP
curl -k https://192.168.40.20:443         # Traefik HTTPS
curl -k https://192.168.20.20:8006        # Proxmox Web UI
curl http://192.168.20.31:5000            # NAS DSM HTTP
curl http://192.168.20.31:32400/web       # Plex
curl -k https://192.168.20.50:8007        # PBS Web UI
curl http://192.168.40.13:3030            # Grafana
curl http://192.168.40.11:8096            # Jellyfin
ssh hermes-admin@192.168.20.30            # Ansible SSH

# Should be BLOCKED - Not allowed
ssh root@192.168.20.20                    # Proxmox SSH - BLOCKED
ssh hermes-admin@192.168.40.11            # Docker Media SSH - BLOCKED
curl http://192.168.40.11:7878            # Radarr direct - BLOCKED
curl http://192.168.40.13:9090            # Prometheus direct - BLOCKED
```

| Test | From Other VLAN 10 PC (not Kratos) | Expected |
|------|-----------------------------------|----------|
| Traefik HTTP | `curl http://192.168.40.20:80` | Success |
| Proxmox Web UI | `curl -k https://192.168.20.20:8006` | Success |
| NAS DSM | `curl http://192.168.20.31:5000` | Success |
| NAS Plex | `curl http://192.168.20.31:32400` | Success |
| PBS Web UI | `curl -k https://192.168.20.50:8007` | Success |
| Grafana | `curl http://192.168.40.13:3030` | Success |
| Jellyfin | `curl http://192.168.40.11:8096` | Success |
| Ansible SSH | `ssh hermes-admin@192.168.20.30` | Success |
| Proxmox SSH | `ssh root@192.168.20.20` | **BLOCKED** |
| Docker Media SSH | `ssh hermes-admin@192.168.40.11` | **BLOCKED** |
| Radarr direct | `curl http://192.168.40.11:7878` | **BLOCKED** |

---

### Test 6: Infrastructure Internal Communication (Rules 29-39)

**Test from Proxmox node01 (192.168.20.20):**

```bash
# Should WORK - Inter-node communication
ssh root@192.168.20.21                    # node02
ssh root@192.168.20.22                    # node03
ping 192.168.20.21                        # Corosync/cluster
ping 192.168.20.22

# Should WORK - NFS to NAS
showmount -e 192.168.20.31                # NFS exports
mount 192.168.20.31:/volume1/share /mnt   # NFS mount test

# Should WORK - PBS backup
curl -k https://192.168.20.50:8007        # PBS API
```

**Test from Ansible (192.168.20.30):**

```bash
# Should WORK - SSH to all managed hosts
ssh root@192.168.20.20                    # Proxmox node01
ssh root@192.168.20.21                    # Proxmox node02
ssh hermes-admin@192.168.40.11            # Docker Media
ssh hermes-admin@192.168.40.13            # Docker Utilities
ssh hermes-admin@192.168.40.20            # Traefik
```

| Test | From | To | Expected |
|------|------|-----|----------|
| Proxmox cluster | node01 → node02 | `ssh root@192.168.20.21` | Success |
| Proxmox to NAS NFS | node01 → NAS | `showmount -e 192.168.20.31` | Success |
| Proxmox to PBS | node01 → PBS | `curl -k https://192.168.20.50:8007` | Success |
| K8s ctrl to worker | k8s-ctrl01 → k8s-worker01 | `ssh 192.168.20.40` | Success |
| Ansible to VLAN 20 | Ansible → Proxmox | `ssh root@192.168.20.20` | Success |
| Ansible to VLAN 40 | Ansible → Docker | `ssh hermes-admin@192.168.40.13` | Success |

---

### Test 7: Services Dependencies (Rules 40-48)

**Test from Docker Media (192.168.40.11):**

```bash
# Should WORK - NFS to NAS for media
showmount -e 192.168.20.31
ls /mnt/media                             # If NFS mounted

# Should WORK - VLAN 40 internal
curl http://192.168.40.13:9090            # Prometheus
curl http://192.168.40.20:80              # Traefik
```

**Test from Docker Utilities (192.168.40.13):**

```bash
# Should WORK - Prometheus scraping
curl http://192.168.20.20:9100/metrics    # node_exporter on Proxmox
curl http://192.168.20.21:9100/metrics
curl http://192.168.20.22:9100/metrics

# Should WORK - SNMP to NAS
snmpwalk -v2c -c public 192.168.20.31

# Should WORK - PBS metrics
curl http://192.168.20.50:9101/metrics

# Should WORK - Sentinel SSH to Proxmox
ssh root@192.168.20.20
```

**Test from Docker Glance (192.168.40.12):**

```bash
# Should WORK - NAS API for storage info
curl http://192.168.20.31:5000/webapi/...
curl -k https://192.168.20.31:5001/webapi/...
```

| Test | From | To | Expected |
|------|------|-----|----------|
| Media NFS | Docker Media → NAS | `showmount -e 192.168.20.31` | Success |
| Immich NFS | Immich → NAS | NFS mount | Success |
| Prometheus node_exporter | Utilities → Proxmox:9100 | `curl http://192.168.20.20:9100/metrics` | Success |
| Prometheus SNMP | Utilities → NAS:161 | `snmpwalk 192.168.20.31` | Success |
| Sentinel SSH | Utilities → Proxmox:22 | `ssh root@192.168.20.20` | Success |
| Glance NAS API | Glance → NAS:5001 | `curl -k https://192.168.20.31:5001` | Success |
| GitLab Runner | Runner → GitLab:443 | `curl https://192.168.40.23` | Success |

---

### Test 8: Traefik Backend Access (Rules 49-56)

**Test from Traefik (192.168.40.20):**

```bash
# Should WORK - All backend services
# Media backends
curl http://192.168.40.11:7878            # Radarr
curl http://192.168.40.11:8989            # Sonarr
curl http://192.168.40.11:8096            # Jellyfin
curl http://192.168.40.11:8686            # Lidarr
curl http://192.168.40.11:9696            # Prowlarr
curl http://192.168.40.11:6767            # Bazarr
curl http://192.168.40.11:5056            # Jellyseerr
curl http://192.168.40.11:8112            # Deluge
curl http://192.168.40.11:8081            # qBittorrent

# Utility backends
curl http://192.168.40.13:3001            # Uptime Kuma
curl http://192.168.40.13:3030            # Grafana
curl http://192.168.40.13:5678            # n8n
curl http://192.168.40.13:9090            # Prometheus
curl http://192.168.40.13:16686           # Jaeger
curl http://192.168.40.13:5051            # Sentinel webhook

# Other backends
curl http://192.168.40.12:8080            # Glance
curl http://192.168.40.21:9000            # Authentik
curl http://192.168.40.22:2283            # Immich
curl http://192.168.40.23:80              # GitLab
curl -k https://192.168.20.50:8007        # PBS
curl -k https://192.168.20.20:8006        # Proxmox
```

| Test | From Traefik (192.168.40.20) | Expected |
|------|------------------------------|----------|
| Radarr | `curl http://192.168.40.11:7878` | Success |
| Sonarr | `curl http://192.168.40.11:8989` | Success |
| Jellyfin | `curl http://192.168.40.11:8096` | Success |
| Grafana | `curl http://192.168.40.13:3030` | Success |
| Glance | `curl http://192.168.40.12:8080` | Success |
| Authentik | `curl http://192.168.40.21:9000` | Success |
| Immich | `curl http://192.168.40.22:2283` | Success |
| GitLab | `curl http://192.168.40.23:80` | Success |
| PBS | `curl -k https://192.168.20.50:8007` | Success |
| Proxmox | `curl -k https://192.168.20.20:8006` | Success |

---

### Test 9: Sonos Access (Rules 57-60)

**Test from Internal (VLAN 10) to Sonos (VLAN 60):**

```bash
# Should WORK - Control Sonos speakers
curl http://192.168.60.x:1400/xml/device_description.xml
# Open Sonos app - should discover speakers
```

**Test from Sonos speaker (VLAN 60) - if you can access shell:**

```bash
# Should WORK - Access NAS for music
curl http://192.168.20.31:5000            # NAS SMB/HTTP

# Should be BLOCKED
ping 192.168.20.20                        # Proxmox - BLOCKED
ping 192.168.40.11                        # Docker - BLOCKED
```

| Test | From/To | Expected |
|------|---------|----------|
| VLAN 10 → Sonos control | `curl http://192.168.60.x:1400` | Success |
| Sonos → NAS music | Sonos → 192.168.20.31 | Success |
| Sonos → Proxmox | `ping 192.168.20.20` | **BLOCKED** |
| Sonos → Docker | `ping 192.168.40.11` | **BLOCKED** |

---

### Test 10: Default Inter-VLAN Blocks (Rules 61-62)

**Test from VLAN 40 to VLAN 20 (should be blocked except explicit allows):**

```bash
# From Docker Media (192.168.40.11)
# Should be BLOCKED - No NFS rule for this host to Proxmox
ssh root@192.168.20.20                    # BLOCKED (no allow rule)
curl -k https://192.168.20.20:8006        # BLOCKED (no allow rule)
```

**Test from VLAN 20 to VLAN 40 (should be blocked except explicit allows):**

```bash
# From NAS (192.168.20.31)
curl http://192.168.40.11:7878            # BLOCKED
ssh hermes-admin@192.168.40.13            # BLOCKED
```

| Test | From | To | Expected |
|------|------|-----|----------|
| Unauthorized VLAN40→20 | Docker Media → Proxmox SSH | **BLOCKED** |
| Unauthorized VLAN20→40 | NAS → Docker services | **BLOCKED** |

---

### Quick Validation Script

Run this from Kratos (192.168.10.10) to quickly validate key rules:

```bash
#!/bin/bash
# ACL Validation Script - Run from Kratos (192.168.10.10)

echo "=== ACL Rule Validation ==="
echo ""

# Test 1: DNS
echo "[1] DNS Access..."
nslookup google.com 192.168.90.53 > /dev/null 2>&1 && echo "  ✓ Pi-hole DNS" || echo "  ✗ Pi-hole DNS FAILED"

# Test 4: Management PC Full Access
echo "[4] Management PC Access..."
timeout 3 bash -c "echo > /dev/tcp/192.168.20.20/22" 2>/dev/null && echo "  ✓ Proxmox SSH" || echo "  ✗ Proxmox SSH FAILED"
timeout 3 bash -c "echo > /dev/tcp/192.168.40.13/22" 2>/dev/null && echo "  ✓ Docker Utils SSH" || echo "  ✗ Docker Utils SSH FAILED"
timeout 3 bash -c "echo > /dev/tcp/192.168.20.31/5001" 2>/dev/null && echo "  ✓ NAS DSM" || echo "  ✗ NAS DSM FAILED"
timeout 3 bash -c "echo > /dev/tcp/192.168.90.53/80" 2>/dev/null && echo "  ✓ Pi-hole Admin" || echo "  ✗ Pi-hole Admin FAILED"

# Test 8: Traefik
echo "[8] Web Services via Traefik..."
curl -s -o /dev/null -w "%{http_code}" https://grafana.hrmsmrflrii.xyz -k | grep -q "200\|302" && echo "  ✓ Grafana" || echo "  ✗ Grafana FAILED"
curl -s -o /dev/null -w "%{http_code}" https://glance.hrmsmrflrii.xyz -k | grep -q "200\|302" && echo "  ✓ Glance" || echo "  ✗ Glance FAILED"

echo ""
echo "=== Validation Complete ==="
```

---

### Omada ACL Logs

To verify rules are being hit:

1. Navigate to **Insight → Logs → ACL Logs**
2. Filter by:
   - **Type**: Gateway ACL
   - **Action**: Deny (to see blocked traffic)
   - **Source/Destination**: Specific IPs
3. Look for your test traffic in the logs

---

## Troubleshooting

### Service Not Working After ACL

1. Check if the required port is in the allow rule
2. Verify rule order (allow rules must be above deny rules)
3. Check Omada logs: **Insight → Logs → Gateway ACL Logs**

### Adding New Services

When adding a new service, you may need to:
1. Add its IP to an existing IP Group, or create a new one
2. Add Traefik backend rule if exposed via reverse proxy
3. Add any specific port requirements

### Common Ports Reference

| Service | Ports |
|---------|-------|
| SSH | 22 |
| DNS | 53 |
| HTTP/HTTPS | 80, 443 |
| NFS | 2049, 111 |
| Proxmox Web | 8006 |
| PBS Web | 8007 |
| Grafana | 3030 |
| Prometheus | 9090 |
| node_exporter | 9100 |
| SNMP | 161 |

---

## Summary

**Total IP Groups**: 17
**Total ACL Rules**: 62
**ACL Type**: All Gateway ACL (Layer 3 inter-VLAN routing)

This configuration provides:
- **Management PC full access** (Kratos 192.168.10.10) to all infrastructure
- Complete Guest/IoT isolation
- Controlled Internal workstation access (other VLAN 10 devices)
- Infrastructure-to-infrastructure communication
- Service dependencies for monitoring
- Traefik access to all backends
- Default deny for unspecified inter-VLAN traffic

---

## Related Documents

- [[07 - Deployed Services|Deployed Services]]
- [[03 - Network Topology|Network Topology]]
- [[11 - Credentials|Credentials]]

---

*Document created: January 13, 2026*
*For: Hermes Homelab - Omada OC300 Controller*
