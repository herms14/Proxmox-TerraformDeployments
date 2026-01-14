# The Complete Homelab Guide
## From Trip Photos to Production-Grade Infrastructure

> A comprehensive guide to building, managing, and scaling a homelab environment based on real-world experience deploying 18 VMs, 30+ containers, and a 9-node Kubernetes cluster.

---

# Table of Contents

1. [[#Part I Foundation|Part I: Foundation]]
   - [[#Chapter 1 The Accidental Homelab|Chapter 1: The Accidental Homelab]]
   - [[#Chapter 2 Planning Your Infrastructure|Chapter 2: Planning Your Infrastructure]]
   - [[#Chapter 3 Choosing Your Hypervisor|Chapter 3: Choosing Your Hypervisor]]

2. [[#Part II Infrastructure|Part II: Infrastructure]]
   - [[#Chapter 4 Proxmox Cluster Setup|Chapter 4: Proxmox Cluster Setup]]
   - [[#Chapter 5 Network Architecture|Chapter 5: Network Architecture]]
   - [[#Chapter 6 Storage Design|Chapter 6: Storage Design]]

3. [[#Part III Automation|Part III: Automation]]
   - [[#Chapter 7 Infrastructure as Code with Terraform|Chapter 7: Infrastructure as Code with Terraform]]
   - [[#Chapter 8 Configuration Management with Ansible|Chapter 8: Configuration Management with Ansible]]
   - [[#Chapter 9 Container Orchestration|Chapter 9: Container Orchestration]]

4. [[#Part IV Services|Part IV: Services]]
   - [[#Chapter 10 Reverse Proxy and SSL|Chapter 10: Reverse Proxy and SSL]]
   - [[#Chapter 11 Identity and Access Management|Chapter 11: Identity and Access Management]]
   - [[#Chapter 12 Media Stack|Chapter 12: Media Stack]]
   - [[#Chapter 13 Productivity Services|Chapter 13: Productivity Services]]

5. [[#Part V Operations|Part V: Operations]]
   - [[#Chapter 14 Monitoring and Alerting|Chapter 14: Monitoring and Alerting]]
   - [[#Chapter 15 Observability and Tracing|Chapter 15: Observability and Tracing]]
   - [[#Chapter 16 Automated Updates|Chapter 16: Automated Updates]]
   - [[#Chapter 17 Discord Bot Automation|Chapter 17: Discord Bot Automation]]

6. [[#Part VI Advanced Topics|Part VI: Advanced Topics]]
   - [[#Chapter 18 Kubernetes at Home|Chapter 18: Kubernetes at Home]]
   - [[#Chapter 19 CI CD Pipelines|Chapter 19: CI/CD Pipelines]]
   - [[#Chapter 20 External Access|Chapter 20: External Access]]

7. [[#Part VII Wisdom|Part VII: Wisdom]]
   - [[#Chapter 21 Troubleshooting Guide|Chapter 21: Troubleshooting Guide]]
   - [[#Chapter 22 Lessons Learned|Chapter 22: Lessons Learned]]
   - [[#Chapter 23 Cost Analysis|Chapter 23: Cost Analysis]]

8. [[#Part VIII Cloud Integration|Part VIII: Cloud Integration]]
   - [[#Chapter 24 Azure Cloud Environment|Chapter 24: Azure Cloud Environment]]
   - [[#Chapter 25 Azure Hybrid Lab Active Directory|Chapter 25: Azure Hybrid Lab (Active Directory)]]
   - [[#Chapter 26 Backup and Disaster Recovery|Chapter 26: Backup and Disaster Recovery]]
   - [[#Chapter 27 Glance Dashboard|Chapter 27: Glance Dashboard]]

9. [[#Appendices|Appendices]]
   - [[#Appendix A Complete IP Map|Appendix A: Complete IP Map]]
   - [[#Appendix B Service URLs|Appendix B: Service URLs]]
   - [[#Appendix C Configuration Templates|Appendix C: Configuration Templates]]
   - [[#Appendix D Docker Services Reference|Appendix D: Docker Services Reference]]

---

# Part I: Foundation

## Chapter 1: The Accidental Homelab

### How It All Started

Every homelab has an origin story. Mine began with a simple problem: I had thousands of photos from trips that needed a proper home. Google Photos was getting expensive, and I wanted control over my own data. What started as "I'll just set up a photo server" evolved into a full-blown infrastructure project spanning 18 virtual machines, a 9-node Kubernetes cluster, and over 30 Docker containers.

This journey taught me more about enterprise infrastructure than any course or certification ever could. The difference? Every mistake directly impacted something I cared about, making the lessons stick.

### What You'll Learn

This book documents everything I learned building a production-grade homelab:

- **Infrastructure Design**: How to plan VLANs, storage, and compute resources
- **Automation First**: Using Terraform and Ansible from day one
- **Service Architecture**: Deploying services that actually work together
- **Operations**: Monitoring, updating, and troubleshooting at scale
- **Hard Lessons**: The mistakes that cost hours and how to avoid them

### The Final Architecture

Before diving into details, here's what we're building:

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERNET                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ISP Router / Firewall                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Core Router (ER605)                            │
│                   OPNsense (192.168.91.30)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
        ┌─────────┐     ┌─────────┐     ┌─────────┐
        │ VLAN 20 │     │ VLAN 40 │     │ VLAN 10 │
        │  Infra  │     │Services │     │   NAS   │
        └────┬────┘     └────┬────┘     └────┬────┘
             │               │               │
    ┌────────┴────────┐      │               │
    │                 │      │               │
    ▼                 ▼      ▼               ▼
┌────────┐      ┌─────────────────┐    ┌─────────┐
│Proxmox │      │  Docker Hosts   │    │Synology │
│Cluster │      │  + Kubernetes   │    │   NAS   │
│(3 nodes)│     │                 │    │         │
└────────┘      └─────────────────┘    └─────────┘
```

**By the Numbers:**

| Metric | Value |
|--------|-------|
| Proxmox Nodes | 3 |
| Virtual Machines | 18 |
| Docker Containers | 30+ |
| Kubernetes Nodes | 9 |
| Total vCPUs | 38 |
| Total RAM | 138 GB |
| Storage | 390 GB (NFS) |
| VLANs | 8 |
| Services | 40+ |

---

## Chapter 2: Planning Your Infrastructure

### Start With Why

Before buying hardware or spinning up VMs, answer these questions:

1. **What problem are you solving?**
   - Photo storage → Immich
   - Media streaming → Jellyfin + Arr stack
   - Learning Kubernetes → K8s cluster
   - Development environment → GitLab + CI/CD

2. **What's your budget?**
   - Used enterprise gear: $500-2000
   - Mini PCs: $300-800 per node
   - Power costs: $20-100/month

3. **What's your tolerance for complexity?**
   - Simple: Single Docker host
   - Moderate: Proxmox + Docker
   - Advanced: Full K8s cluster

### The Three Pillars

Every homelab needs three foundational elements:

#### 1. Compute (Where Things Run)

Options ranked by complexity:

| Option | Pros | Cons | Best For |
|--------|------|------|----------|
| Raspberry Pi | Cheap, quiet, low power | Limited resources, ARM | Learning, simple services |
| Mini PC (Intel NUC) | Compact, x86, good performance | Single point of failure | Small labs |
| Used Enterprise Server | Massive resources, cheap | Loud, power hungry | Serious workloads |
| Proxmox Cluster | HA, flexible, professional | Complex setup | Production-grade labs |

**My Choice**: Proxmox cluster on 3 mini PCs. Balance of power, noise, and capability.

#### 2. Network (How Things Talk)

The network is where most homelabs fail. Plan for:

- **Segmentation**: Separate infrastructure from services
- **DNS**: Internal resolution for service names
- **VLANs**: Logical separation without physical switches
- **Firewall**: Control traffic between segments

**My Design**:
```
VLAN 20 (192.168.20.0/24) - Infrastructure
├── Proxmox nodes
├── Kubernetes cluster
└── Ansible controller

VLAN 40 (192.168.40.0/24) - Services
├── Docker hosts
├── Reverse proxy
└── Applications
```

#### 3. Storage (Where Things Live)

Storage strategy determines your backup and disaster recovery capabilities:

| Type | Use Case | Speed | Reliability |
|------|----------|-------|-------------|
| Local SSD | VM disks, fast access | Fast | Single disk failure = data loss |
| NFS Share | Shared data, backups | Moderate | NAS handles redundancy |
| Ceph | Distributed, HA | Variable | Complex but resilient |

**My Design**: Synology NAS with NFS exports. One export per use case:
- VMDisks: Proxmox VM storage
- ISOs: Installation media
- Media: Arr stack content
- Photos: Immich uploads

### Naming Conventions

Consistent naming saves hours of confusion later:

```
Pattern: {type}-{purpose}{number}

Examples:
- docker-vm-core-utilities01    # First utilities Docker host
- docker-vm-media01        # Media services host
- k8s-controller01         # First K8s controller
- k8s-worker01             # First K8s worker
- traefik-vm01             # Reverse proxy
- authentik-vm01           # SSO server
```

### IP Addressing Scheme

Plan your IP ranges before deployment:

```
VLAN 20 - Infrastructure (192.168.20.0/24)
├── .1        Gateway
├── .20-.22   Proxmox nodes
├── .30       Ansible controller
├── .31       NAS
├── .32-.34   K8s controllers
└── .40-.45   K8s workers

VLAN 40 - Services (192.168.40.0/24)
├── .1        Gateway
├── .10       Utilities (Glance, n8n, monitoring)
├── .11       Media (Jellyfin, Arr stack)
├── .20       Reverse proxy (Traefik)
├── .21       SSO (Authentik)
├── .22       Photos (Immich)
├── .23       DevOps (GitLab)
└── .24       CI/CD (GitLab Runner)
```

---

## Chapter 3: Choosing Your Hypervisor

### The Contenders

| Hypervisor | License | Best For | Complexity |
|------------|---------|----------|------------|
| Proxmox VE | Free (open source) | Homelabs, SMB | Medium |
| VMware ESXi | Free tier limited | Enterprise experience | High |
| Hyper-V | Included with Windows | Windows shops | Low-Medium |
| XCP-ng | Free (open source) | XenServer alternative | Medium |

### Why Proxmox Won

After evaluating all options, Proxmox VE became the clear choice:

**Pros:**
- Completely free and open source
- Native KVM/QEMU virtualization
- LXC containers built-in
- Web UI is excellent
- Clustering is straightforward
- Terraform provider exists
- Active community

**Cons:**
- Learning curve for enterprise users
- No official support without subscription
- Some features require CLI

### Proxmox Architecture

Understanding Proxmox's architecture helps with troubleshooting:

```
┌─────────────────────────────────────────────────┐
│              Proxmox VE Node                     │
├─────────────────────────────────────────────────┤
│  Web UI (Port 8006)                             │
├─────────────────────────────────────────────────┤
│  API (pvesh, Terraform provider)                │
├─────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐               │
│  │     VMs     │  │     LXC     │               │
│  │   (QEMU)    │  │ (Containers)│               │
│  └─────────────┘  └─────────────┘               │
├─────────────────────────────────────────────────┤
│  Storage (local, NFS, Ceph, ZFS)                │
├─────────────────────────────────────────────────┤
│  Network (Linux bridge, OVS, VLAN)              │
├─────────────────────────────────────────────────┤
│  Debian Linux Base                               │
└─────────────────────────────────────────────────┘
```

### VMs vs LXC Containers

Proxmox offers both. Use the right tool:

| Feature | VM (KVM) | LXC Container |
|---------|----------|---------------|
| Isolation | Full (hardware level) | Partial (kernel shared) |
| Overhead | Higher | Minimal |
| Boot time | 30-60 seconds | 1-5 seconds |
| Resource usage | More | Less |
| OS support | Any (Windows, Linux) | Linux only |
| Docker support | Full | Requires nesting |
| Use case | Production services | Development, utilities |

**My Strategy:**
- VMs for Docker hosts (full isolation, nested virtualization support)
- VMs for Kubernetes (kubelet expects full OS)
- LXC for simple services (Pi-hole, utilities)

### Initial Cluster Setup

Setting up a Proxmox cluster requires careful planning:

```bash
# On first node (becomes initial cluster member)
pvecm create homelab-cluster

# On subsequent nodes
pvecm add 192.168.20.20

# Verify cluster status
pvecm status
```

**Critical Requirements:**
- All nodes must have unique hostnames
- All nodes need time sync (NTP)
- Corosync requires multicast OR unicast configuration
- Storage must be accessible from all nodes

> [!warning] Cluster Network
> Never cluster over a network that might have issues. Corosync is sensitive to latency and packet loss. A flaky cluster is worse than no cluster.

---

# Part II: Infrastructure

## Chapter 4: Proxmox Cluster Setup

### Hardware Specifications

My three-node cluster:

| Node | Hostname | IP | Role | Specs |
|------|----------|-----|------|-------|
| 1 | pve-node01 | 192.168.20.20 | VM Host | 12 cores, 64GB RAM |
| 2 | pve-node02 | 192.168.20.21 | Service Host | 12 cores, 48GB RAM |
| 3 | pve-node03 | 192.168.20.22 | K8s Host | 12 cores, 32GB RAM |

### Installation Process

1. **Download Proxmox VE ISO** from proxmox.com
2. **Create bootable USB** using Rufus or Etcher
3. **Boot and install** on each node
4. **Configure network** during installation:
   - Set static IP
   - Configure gateway
   - Set DNS servers

### Post-Installation Configuration

After installation, configure each node:

```bash
# Update package repositories (remove enterprise repo if no subscription)
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription repository
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update system
apt update && apt full-upgrade -y

# Install useful tools
apt install -y vim htop iotop nfs-common
```

### VLAN-Aware Bridge Configuration

For VLAN support, configure the network bridge:

```bash
# /etc/network/interfaces
auto lo
iface lo inet loopback

iface eno1 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.20.20/24
    gateway 192.168.20.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

> [!important] VLAN-Aware Bridge
> The `bridge-vlan-aware yes` and `bridge-vids 2-4094` lines are critical. Without them, VMs cannot use VLAN tags and all traffic stays on the native VLAN.

### Cloud-Init Template Creation

Templates enable rapid VM deployment:

```bash
# Download Ubuntu cloud image
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Create VM from image
qm create 9000 --name "tpl-ubuntu-24.04" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Import disk
qm importdisk 9000 noble-server-cloudimg-amd64.img VMDisks

# Attach disk
qm set 9000 --scsihw virtio-scsi-pci --scsi0 VMDisks:vm-9000-disk-0

# Configure boot and cloud-init
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --ide2 VMDisks:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# Set cloud-init defaults
qm set 9000 --ciuser hermes-admin
qm set 9000 --sshkeys ~/.ssh/authorized_keys
qm set 9000 --ipconfig0 ip=dhcp

# Convert to template
qm template 9000
```

### Boot Mode: UEFI vs BIOS

> [!danger] Critical Configuration
> Boot mode mismatch is one of the most common VM issues. If your template uses UEFI (ovmf), all VMs cloned from it must also use UEFI.

Check VM boot mode:
```bash
qm config <vmid> | grep -E "bios|efidisk"
```

- `bios: ovmf` + `efidisk0` = UEFI boot
- No bios line = Legacy BIOS boot

**Symptoms of mismatch:**
- VM hangs at boot with no output
- "No bootable device" errors
- Cloud-init never runs

### API User for Automation

Create a dedicated Terraform user:

```bash
# Create user
pveum user add terraform-deployment-user@pve

# Create API token
pveum user token add terraform-deployment-user@pve tf --privsep=0

# Grant permissions
pveum aclmod / -user terraform-deployment-user@pve -role PVEAdmin
```

Save the token ID and secret - you'll need them for Terraform.

---

## Chapter 5: Network Architecture

### Physical Topology

Understanding your physical layout prevents troubleshooting nightmares:

```
┌─────────────┐
│  ISP Modem  │
└──────┬──────┘
       │
┌──────▼──────┐
│   ER605     │ Core Router
│  (Router)   │ Inter-VLAN routing
└──────┬──────┘
       │
┌──────▼──────┐
│   SG3210    │ Core Switch (Managed)
│  (Switch)   │ VLAN trunking
└──────┬──────┘
       │
   ┌───┴───┬───────────┬───────────┐
   │       │           │           │
┌──▼──┐ ┌──▼──┐    ┌───▼───┐   ┌───▼───┐
│Node1│ │Node2│    │  NAS  │   │  APs  │
└─────┘ └─────┘    └───────┘   └───────┘
```

### VLAN Design

VLANs provide logical network separation:

| VLAN ID | Network | Purpose | Notes |
|---------|---------|---------|-------|
| 1 | Native | Management | Switch/AP management |
| 10 | 192.168.10.0/24 | Storage | NAS dedicated network |
| 20 | 192.168.20.0/24 | Infrastructure | Proxmox, K8s, Ansible |
| 30 | 192.168.30.0/24 | IoT | Smart home devices |
| 40 | 192.168.40.0/24 | Services | Docker hosts, apps |
| 50 | 192.168.50.0/24 | Guest | Isolated guest WiFi |
| 90 | 192.168.90.0/24 | VPN | WireGuard clients |
| 91 | 192.168.91.0/24 | Security | Firewall, DNS |

### Switch Configuration

For VLAN trunking to Proxmox nodes, configure switch ports:

```
Port 1-3 (Proxmox nodes): Trunk, All VLANs (1,10,20,40)
Port 4 (NAS): Access, VLAN 10
Port 5-8 (APs): Trunk, VLANs (1,30,50)
```

### DNS Architecture

Internal DNS is essential for service discovery:

```
                    ┌─────────────────┐
                    │    OPNsense     │
                    │  192.168.91.30  │
                    │   (DNS Server)  │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
    *.hrmsmrflrii.xyz   Internal hosts     Upstream
    (wildcard → Traefik) (host overrides)   (Cloudflare)
```

**Host Overrides in OPNsense:**

| Hostname | IP | Purpose |
|----------|-----|---------|
| proxmox.hrmsmrflrii.xyz | 192.168.20.21 | Proxmox UI |
| traefik.hrmsmrflrii.xyz | 192.168.40.20 | Reverse proxy |
| auth.hrmsmrflrii.xyz | 192.168.40.20 | Authentik (via Traefik) |
| photos.hrmsmrflrii.xyz | 192.168.40.20 | Immich (via Traefik) |

### SSL Certificate Strategy

Wildcard certificates simplify SSL management:

```
┌─────────────────────────────────────────────────────────┐
│                    Cloudflare                            │
│              (DNS for hrmsmrflrii.xyz)                   │
└─────────────────────────────────────────────────────────┘
                          │
                          │ DNS-01 Challenge
                          ▼
┌─────────────────────────────────────────────────────────┐
│                      Traefik                             │
│              (Certificate Resolver)                      │
│                                                          │
│  Requests: *.hrmsmrflrii.xyz                            │
│  Provider: Cloudflare DNS                                │
│  Storage: /letsencrypt/acme.json                        │
└─────────────────────────────────────────────────────────┘
```

**Traefik Certificate Configuration:**

```yaml
# /opt/traefik/config/traefik.yml
certificatesResolvers:
  cloudflare:
    acme:
      email: your-email@example.com
      storage: /letsencrypt/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
```

### Firewall Rules

Control traffic between VLANs:

```
# Allow VLAN 40 (Services) to access VLAN 10 (Storage)
Source: 192.168.40.0/24
Destination: 192.168.10.0/24
Port: 2049 (NFS), 445 (SMB)
Action: Allow

# Allow VLAN 20 (Infra) to access VLAN 40 (Services)
Source: 192.168.20.0/24
Destination: 192.168.40.0/24
Port: Any
Action: Allow

# Block IoT from accessing other VLANs
Source: 192.168.30.0/24
Destination: !192.168.30.0/24
Action: Deny
```

### Network Segmentation with ACLs

Beyond basic firewall rules, Gateway ACLs on the Omada OC300 controller provide granular inter-VLAN traffic control. This is essential for proper network segmentation.

#### ACL Types Explained

| ACL Type | Layer | Use Case |
|----------|-------|----------|
| **Gateway ACL** | L3 (Network) | Inter-VLAN traffic control - **All 62 rules use this** |
| **Switch ACL** | L2 (Data Link) | Port/MAC-based filtering within a VLAN |
| **EAP ACL** | L2/L3 | Wireless client filtering per-SSID |

#### ACL Rule Summary

The homelab implements 62 Gateway ACL rules organized into 10 rule sets:

| Rule Set | Rules | Purpose |
|----------|-------|---------|
| **DNS Access** | 1-2 | Allow ALL VLANs to reach Pi-hole (192.168.90.53) and OPNsense (192.168.91.30) |
| **Guest Isolation** | 3-9 | Block Guest VLAN (50) from ALL internal networks |
| **IoT Isolation** | 10-14 | Block IoT VLAN (30) from trusted networks |
| **Management PC** | 15-18 | Full unrestricted access for admin workstation (192.168.10.10) |
| **Internal Workstations** | 19-28 | Limited access for VLAN 10 - specific ports via Traefik only |
| **Infrastructure** | 29-39 | Proxmox cluster, K8s communication, Ansible SSH |
| **Services Dependencies** | 40-48 | NFS mounts, Prometheus scraping, Sentinel SSH to Proxmox |
| **Traefik Backend** | 49-56 | Reverse proxy access to all backend services |
| **Sonos** | 57-60 | Speaker control from VLAN 10, NAS music access |
| **Default Deny** | 61-62 | Catch-all blocks with logging enabled |

#### IP Groups (17 Total)

IP Groups simplify rule management by grouping related hosts:

| Group | IP Addresses | Purpose |
|-------|--------------|---------|
| `PROXMOX_NODES` | 192.168.20.20, .21, .22 | Proxmox cluster |
| `K8S_CONTROLLERS` | 192.168.20.32, .33, .34 | Kubernetes control plane |
| `K8S_WORKERS` | 192.168.20.40-.45 | Kubernetes worker nodes |
| `SYNOLOGY_NAS` | 192.168.20.31 | Network storage |
| `DOCKER_MEDIA` | 192.168.40.11 | Jellyfin, *arr stack |
| `DOCKER_UTILITIES` | 192.168.40.13 | Grafana, Prometheus, Sentinel |
| `TRAEFIK` | 192.168.40.20 | Reverse proxy |
| `MANAGEMENT_PC` | 192.168.10.10 | Admin workstation (Kratos) |
| `PIHOLE` | 192.168.90.53 | DNS server |
| `OPNSENSE` | 192.168.91.30 | Firewall/DNS |

#### Rule Processing Order

ACL rules are processed top-to-bottom. First match wins:

```
DNS Allow (1-2)           ← Evaluated first - ensures DNS works for all VLANs
        ↓
Guest/IoT Deny (3-14)     ← Blocks untrusted networks early
        ↓
Management PC (15-18)     ← Admin PC bypasses restrictions
        ↓
Specific Allows (19-60)   ← Service-specific permits
        ↓
Default Deny (61-62)      ← Catch-all - logged for troubleshooting
```

#### Key Security Principles

1. **Default-deny approach**: Everything is blocked unless explicitly allowed
2. **DNS first**: Rules 1-2 ensure all VLANs can resolve DNS (essential for internet access)
3. **Management exception**: One trusted admin PC (192.168.10.10) has full access for emergencies
4. **Least privilege**: Regular workstations access services via Traefik, not directly
5. **Logging on catch-all**: Rules 61-62 log blocked traffic for troubleshooting

#### Testing ACL Rules

After implementing, verify rules work as expected:

```bash
# From Management PC (should work - full access)
ssh root@192.168.20.20              # Proxmox SSH
curl http://192.168.40.11:7878      # Radarr direct

# From regular VLAN 10 workstation (should be blocked)
ssh root@192.168.20.20              # BLOCKED - no direct SSH
curl http://192.168.40.11:7878      # BLOCKED - must use Traefik

# From Guest VLAN (should be blocked)
ping 192.168.20.31                  # BLOCKED - no internal access
ping 8.8.8.8                        # WORKS - internet access OK
```

> **Pro Tip**: Check `Insight → Logs → ACL Logs` in Omada Controller to see which rules are being hit and troubleshoot connectivity issues.

---

## Chapter 6: Storage Design

### Storage Philosophy

> [!tip] Golden Rule
> One NFS export = One Proxmox storage pool. This prevents state ambiguity and makes troubleshooting straightforward.

### NFS Export Design

```
Synology NAS (192.168.20.31)
├── /volume2/ProxmoxCluster-VMDisks
│   └── Proxmox storage: VMDisks
│   └── Purpose: VM disk images
│
├── /volume2/ProxmoxCluster-ISOs
│   └── Proxmox storage: ISOs
│   └── Purpose: Installation media
│
├── /volume2/Proxmox-Media
│   └── Mount: /mnt/media on Docker hosts
│   └── Purpose: Arr stack unified storage
│
└── /volume2/Immich Photos
    └── Mount: /mnt/immich-uploads
    └── Purpose: Photo uploads
```

### Proxmox Storage Configuration

Add NFS storage via UI or CLI:

```bash
# Add VMDisks storage
pvesm add nfs VMDisks \
  --server 192.168.20.31 \
  --export /volume2/ProxmoxCluster-VMDisks \
  --content images,rootdir

# Add ISOs storage
pvesm add nfs ISOs \
  --server 192.168.20.31 \
  --export /volume2/ProxmoxCluster-ISOs \
  --content iso,vztmpl
```

### VM Storage Configuration

NFS mounts in VMs require proper fstab entries:

```bash
# /etc/fstab on Docker hosts
192.168.20.31:/volume2/Proxmox-Media  /mnt/media  nfs  defaults,_netdev  0  0
```

> [!warning] _netdev Flag
> The `_netdev` flag is critical. It tells systemd to wait for network before mounting. Without it, boot fails if NFS is unavailable.

### The Unified Path Strategy

For the Arr stack (Radarr, Sonarr, etc.), unified paths enable hardlinks:

```
Host Path                    Container Path    Service
────────────────────────────────────────────────────────
/mnt/media                   /data             All services
├── /mnt/media/Movies        /data/Movies      Radarr root
├── /mnt/media/Series        /data/Series      Sonarr root
├── /mnt/media/Music         /data/Music       Lidarr root
├── /mnt/media/Completed     /data/Completed   Download output
├── /mnt/media/Downloading   /data/Downloading Active downloads
└── /mnt/media/Incomplete    /data/Incomplete  Partial downloads
```

> [!important] Why Unified Paths Matter
> When Radarr imports a movie, it can use a hardlink (instant, no disk space) instead of copying (slow, doubles space). This only works if both paths are on the same filesystem.

**Wrong Way (separate paths):**
```yaml
# DON'T DO THIS
radarr:
  volumes:
    - /opt/arr-stack/downloads:/downloads
    - /mnt/media/Movies:/movies

deluge:
  volumes:
    - /opt/arr-stack/downloads:/downloads
```
Result: Different host paths → Copy instead of hardlink → Wastes space and time

**Right Way (unified paths):**
```yaml
# DO THIS
radarr:
  volumes:
    - /mnt/media:/data

deluge:
  volumes:
    - /mnt/media:/data
```
Result: Same host path → Hardlink works → Instant import

### Backup Strategy

Implement 3-2-1 backup rule:
- **3** copies of data
- **2** different media types
- **1** offsite copy

```
Production Data (Synology)
        │
        ├── Local Backup (Second Synology volume)
        │
        └── Offsite Backup (Backblaze B2 / Cloud)
```

---

# Part III: Automation

## Chapter 7: Infrastructure as Code with Terraform

### Why Terraform?

Manual VM creation doesn't scale. Terraform provides:

- **Reproducibility**: Same config = same infrastructure
- **Version control**: Track changes in Git
- **Documentation**: Config IS documentation
- **Disaster recovery**: Rebuild from code

### Provider Configuration

```hcl
# providers.tf
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://192.168.20.20:8006/api2/json"
  pm_api_token_id     = "terraform-deployment-user@pve!tf"
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}
```

### VM Module Structure

```hcl
# modules/linux-vm/main.tf
resource "proxmox_vm_qemu" "vm" {
  count       = var.count
  name        = "${var.name_prefix}${format("%02d", count.index + 1)}"
  target_node = var.target_node
  clone       = var.template

  cores   = var.cores
  memory  = var.memory

  disk {
    storage = var.storage
    size    = var.disk_size
    type    = "scsi"
  }

  network {
    model    = "virtio"
    bridge   = "vmbr0"
    tag      = var.vlan_tag
  }

  ipconfig0 = "ip=${var.ip_base}${count.index + var.ip_offset}/24,gw=${var.gateway}"

  ciuser     = var.ssh_user
  sshkeys    = var.ssh_public_key
  nameserver = var.nameserver
}
```

### Main Configuration

```hcl
# main.tf
locals {
  vm_groups = {
    ansible-controller = {
      count       = 1
      starting_ip = "192.168.20.30"
      template    = "tpl-ubuntu-24.04"
      cores       = 2
      memory      = 8192
      disk_size   = "20G"
      vlan_tag    = null  # VLAN 20 is native
    }

    k8s-controller = {
      count       = 3
      starting_ip = "192.168.20.32"
      template    = "tpl-ubuntu-24.04"
      cores       = 2
      memory      = 4096
      disk_size   = "20G"
      vlan_tag    = null
    }

    k8s-worker = {
      count       = 6
      starting_ip = "192.168.20.40"
      template    = "tpl-ubuntu-24.04"
      cores       = 2
      memory      = 8192
      disk_size   = "30G"
      vlan_tag    = null
    }

    docker-vm-utilities = {
      count       = 1
      starting_ip = "192.168.40.13"
      template    = "tpl-ubuntu-24.04"
      cores       = 4
      memory      = 8192
      disk_size   = "30G"
      vlan_tag    = 40
      gateway     = "192.168.40.1"
    }

    docker-vm-media = {
      count       = 1
      starting_ip = "192.168.40.11"
      template    = "tpl-ubuntu-24.04"
      cores       = 4
      memory      = 16384
      disk_size   = "50G"
      vlan_tag    = 40
      gateway     = "192.168.40.1"
    }
  }
}

module "vms" {
  source   = "./modules/linux-vm"
  for_each = local.vm_groups

  name_prefix = each.key
  count       = each.value.count
  # ... rest of configuration
}
```

### Deployment Workflow

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Target specific resources
terraform apply -target=module.vms["docker-vm-utilities"]

# View outputs
terraform output vm_summary
```

### State Management

> [!warning] Terraform State
> State files contain sensitive information. Never commit `terraform.tfstate` to Git. Use remote state for teams.

```bash
# .gitignore
*.tfstate
*.tfstate.*
.terraform/
terraform.tfvars
```

---

## Chapter 8: Configuration Management with Ansible

### Ansible Architecture

```
┌─────────────────────────────────────────────────────────┐
│           Ansible Controller (192.168.20.30)            │
├─────────────────────────────────────────────────────────┤
│  ~/ansible/                                             │
│  ├── inventory/                                         │
│  │   └── hosts.yml        # Target definitions         │
│  ├── playbooks/                                         │
│  │   ├── docker/          # Docker installation        │
│  │   ├── traefik/         # Reverse proxy              │
│  │   ├── authentik/       # SSO                        │
│  │   └── k8s/             # Kubernetes cluster         │
│  ├── roles/               # Reusable components        │
│  └── callback_plugins/    # Discord notifications      │
└─────────────────────────────────────────────────────────┘
                          │
                          │ SSH
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    Managed Hosts                         │
│  - Docker VMs (192.168.40.12-24)                        │
│  - K8s nodes (192.168.20.32-45)                         │
│  - LXC containers                                        │
└─────────────────────────────────────────────────────────┘
```

### Inventory Structure

```yaml
# inventory/hosts.yml
all:
  children:
    proxmox:
      hosts:
        pve-node01:
          ansible_host: 192.168.20.20
        pve-node02:
          ansible_host: 192.168.20.21
        pve-node03:
          ansible_host: 192.168.20.22
      vars:
        ansible_user: root

    docker_hosts:
      hosts:
        docker-vm-core-utilities01:
          ansible_host: 192.168.40.13
        docker-vm-media01:
          ansible_host: 192.168.40.11
        traefik-vm01:
          ansible_host: 192.168.40.20
        authentik-vm01:
          ansible_host: 192.168.40.21
        immich-vm01:
          ansible_host: 192.168.40.22
        gitlab-vm01:
          ansible_host: 192.168.40.23
      vars:
        ansible_user: hermes-admin
        ansible_become: yes

    k8s_controllers:
      hosts:
        k8s-controller01:
          ansible_host: 192.168.20.32
        k8s-controller02:
          ansible_host: 192.168.20.33
        k8s-controller03:
          ansible_host: 192.168.20.34

    k8s_workers:
      hosts:
        k8s-worker01:
          ansible_host: 192.168.20.40
        k8s-worker02:
          ansible_host: 192.168.20.41
        # ... more workers
```

### Playbook Example: Docker Installation

```yaml
# playbooks/docker/install-docker.yml
---
- name: Install Docker on target hosts
  hosts: docker_hosts
  become: yes

  tasks:
    - name: Install prerequisites
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
        state: present
        update_cache: yes

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
        state: present

    - name: Install Docker
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-compose-plugin
        state: present

    - name: Add user to docker group
      user:
        name: "{{ ansible_user }}"
        groups: docker
        append: yes

    - name: Start Docker service
      service:
        name: docker
        state: started
        enabled: yes
```

### Discord Notifications

Custom callback plugin for playbook notifications:

```python
# callback_plugins/discord_notify.py
from ansible.plugins.callback import CallbackBase
import requests

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'discord_notify'

    def __init__(self):
        super().__init__()
        self.webhook_url = "https://discord.com/api/webhooks/..."

    def v2_playbook_on_stats(self, stats):
        # Send summary to Discord
        hosts = sorted(stats.processed.keys())
        summary = []

        for h in hosts:
            s = stats.summarize(h)
            summary.append(f"{h}: ok={s['ok']} changed={s['changed']} failed={s['failures']}")

        payload = {
            "embeds": [{
                "title": "Ansible Playbook Complete",
                "description": "\n".join(summary),
                "color": 0x00ff00 if all(stats.summarize(h)['failures'] == 0 for h in hosts) else 0xff0000
            }]
        }

        requests.post(self.webhook_url, json=payload)
```

### Running Playbooks

```bash
# Check connectivity
ansible all -m ping

# Run playbook
ansible-playbook playbooks/docker/install-docker.yml

# Limit to specific hosts
ansible-playbook playbooks/traefik/deploy.yml -l traefik-vm01

# Check mode (dry run)
ansible-playbook playbooks/authentik/deploy.yml --check

# Verbose output
ansible-playbook playbooks/k8s/deploy-cluster.yml -vvv
```

---

## Chapter 9: Container Orchestration

### Docker Compose Best Practices

After deploying dozens of services, these patterns emerged as essential:

#### 1. Use Named Networks

```yaml
# Good: Named network with explicit configuration
networks:
  traefik:
    external: true
  internal:
    driver: bridge

services:
  app:
    networks:
      - traefik    # Exposed to reverse proxy
      - internal   # Internal communication only

  database:
    networks:
      - internal   # Not exposed externally
```

#### 2. Volume Mount Consistency

```yaml
# Pattern: Config directory + Data directory
services:
  radarr:
    volumes:
      - /opt/arr-stack/radarr:/config    # Application config
      - /mnt/media:/data                  # Media data (unified)
```

#### 3. Environment File Management

```yaml
# docker-compose.yml
services:
  app:
    env_file:
      - .env
    environment:
      - OVERRIDE_VAR=value  # Overrides .env

# .env (gitignored)
DB_PASSWORD=secure_password
API_KEY=secret_key
```

#### 4. Health Checks

```yaml
services:
  traefik:
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

#### 5. Restart Policies

```yaml
services:
  critical-service:
    restart: unless-stopped  # Survives host reboot, respects manual stop

  one-shot-task:
    restart: "no"  # Run once
```

### Docker Compose File Organization

```
/opt/service-name/
├── docker-compose.yml      # Main compose file
├── .env                    # Environment variables (gitignored)
├── config/                 # Application configuration
│   └── app.conf
└── data/                   # Persistent data
```

### Full Stack Example: Arr Stack

```yaml
# /opt/arr-stack/docker-compose.yml
version: "3.8"

services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"
    volumes:
      - /opt/arr-stack/jellyfin/config:/config
      - /mnt/media:/data
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Manila

  radarr:
    image: linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    ports:
      - "7878:7878"
    volumes:
      - /opt/arr-stack/radarr:/config
      - /mnt/media:/data
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Manila

  sonarr:
    image: linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    ports:
      - "8989:8989"
    volumes:
      - /opt/arr-stack/sonarr:/config
      - /mnt/media:/data
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Manila

  prowlarr:
    image: linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    ports:
      - "9696:9696"
    volumes:
      - /opt/arr-stack/prowlarr:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Manila

  deluge:
    image: linuxserver/deluge:latest
    container_name: deluge
    restart: unless-stopped
    ports:
      - "8112:8112"
      - "6881:6881"
      - "6881:6881/udp"
    volumes:
      - /opt/arr-stack/deluge:/config
      - /mnt/media:/data
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Manila

  sabnzbd:
    image: linuxserver/sabnzbd:latest
    container_name: sabnzbd
    restart: unless-stopped
    ports:
      - "8081:8080"
    volumes:
      - /opt/arr-stack/sabnzbd:/config
      - /mnt/media:/data
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Manila
```

---

# Part IV: Services

## Chapter 10: Reverse Proxy and SSL

### Why Traefik?

After evaluating Nginx, Caddy, and Traefik:

| Feature | Nginx | Caddy | Traefik |
|---------|-------|-------|---------|
| Auto SSL | Manual/scripted | Automatic | Automatic |
| Docker integration | Via config | Via labels | Native |
| Dynamic config | Reload required | Automatic | Automatic |
| Dashboard | Third-party | None | Built-in |
| Learning curve | Medium | Low | Medium |

**Winner**: Traefik for its native Docker integration and automatic SSL.

### Traefik Architecture

```
                     ┌─────────────────────┐
                     │      Internet       │
                     └──────────┬──────────┘
                                │
                     ┌──────────▼──────────┐
                     │   Cloudflare DNS    │
                     │  (*.hrmsmrflrii.xyz)│
                     └──────────┬──────────┘
                                │
                     ┌──────────▼──────────┐
                     │       Traefik       │
                     │   192.168.40.20     │
                     │                     │
                     │  :443 → HTTPS       │
                     │  :80  → HTTP→HTTPS  │
                     │  :8080 → Dashboard  │
                     │  :8082 → Ping       │
                     └──────────┬──────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│    Authentik    │  │     Immich      │  │    Jellyfin     │
│  192.168.40.21  │  │  192.168.40.22  │  │  192.168.40.11  │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Static Configuration

```yaml
# /opt/traefik/config/traefik.yml
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https

  websecure:
    address: ":443"
    http:
      tls:
        certResolver: cloudflare
        domains:
          - main: "hrmsmrflrii.xyz"
            sans:
              - "*.hrmsmrflrii.xyz"

  ping:
    address: ":8082"

ping:
  entryPoint: ping

providers:
  file:
    directory: /config/dynamic
    watch: true

certificatesResolvers:
  cloudflare:
    acme:
      email: your-email@example.com
      storage: /letsencrypt/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"

# OpenTelemetry tracing
tracing:
  otlp:
    http:
      endpoint: "http://192.168.40.13:4318/v1/traces"

metrics:
  prometheus:
    entryPoint: ping
```

### Dynamic Service Configuration

```yaml
# /opt/traefik/config/dynamic/services.yml
http:
  routers:
    authentik:
      rule: "Host(`auth.hrmsmrflrii.xyz`)"
      service: authentik
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare

    immich:
      rule: "Host(`photos.hrmsmrflrii.xyz`)"
      service: immich
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare
      middlewares:
        - authentik-auth

    jellyfin:
      rule: "Host(`jellyfin.hrmsmrflrii.xyz`)"
      service: jellyfin
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare

    radarr:
      rule: "Host(`radarr.hrmsmrflrii.xyz`)"
      service: radarr
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare
      middlewares:
        - authentik-auth

  services:
    authentik:
      loadBalancer:
        servers:
          - url: "http://192.168.40.21:9000"

    immich:
      loadBalancer:
        servers:
          - url: "http://192.168.40.22:2283"

    jellyfin:
      loadBalancer:
        servers:
          - url: "http://192.168.40.11:8096"

    radarr:
      loadBalancer:
        servers:
          - url: "http://192.168.40.11:7878"

  middlewares:
    authentik-auth:
      forwardAuth:
        address: "http://192.168.40.21:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
          - X-authentik-jwt
          - X-authentik-meta-jwks
          - X-authentik-meta-outpost
          - X-authentik-meta-provider
          - X-authentik-meta-app
          - X-authentik-meta-version
```

### Docker Compose for Traefik

```yaml
# /opt/traefik/docker-compose.yml
version: "3.8"

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
      - "8082:8082"
    volumes:
      - /opt/traefik/config:/config
      - /opt/traefik/letsencrypt:/letsencrypt
    environment:
      - CF_API_EMAIL=${CF_API_EMAIL}
      - CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}
    command:
      - "--configFile=/config/traefik.yml"
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 10s
      retries: 3
```

---

## Chapter 11: Identity and Access Management

### Authentik Overview

Authentik provides SSO for all internal services:

```
┌─────────────────────────────────────────────────────────┐
│                      Authentik                           │
│                   192.168.40.21:9000                     │
├─────────────────────────────────────────────────────────┤
│  ┌───────────────┐  ┌───────────────┐                   │
│  │    Server     │  │   PostgreSQL  │                   │
│  │   (Django)    │  │   (Database)  │                   │
│  └───────────────┘  └───────────────┘                   │
│  ┌───────────────┐  ┌───────────────┐                   │
│  │    Worker     │  │     Redis     │                   │
│  │   (Celery)    │  │   (Cache)     │                   │
│  └───────────────┘  └───────────────┘                   │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │              Embedded Outpost                      │  │
│  │  (Handles ForwardAuth for Traefik)                │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Authentication Flow

```
User Request → Traefik → ForwardAuth Middleware
                              │
                              ▼
                     ┌─────────────────┐
                     │ Authentik Check │
                     │                 │
                     │ Authenticated?  │
                     └────────┬────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
        ┌─────▼─────┐                   ┌─────▼─────┐
        │    NO     │                   │    YES    │
        │           │                   │           │
        │ Redirect  │                   │  Forward  │
        │ to Login  │                   │ to Service│
        └───────────┘                   └───────────┘
```

### Setting Up Authentik

```yaml
# /opt/authentik/docker-compose.yml
version: "3.8"

services:
  postgresql:
    image: postgres:15-alpine
    container_name: authentik-postgres
    restart: unless-stopped
    volumes:
      - /opt/authentik/database:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=${PG_PASS}
      - POSTGRES_USER=authentik
      - POSTGRES_DB=authentik

  redis:
    image: redis:alpine
    container_name: authentik-redis
    restart: unless-stopped
    command: --save 60 1 --loglevel warning

  server:
    image: ghcr.io/goauthentik/server:latest
    container_name: authentik-server
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9443:9443"
    volumes:
      - /opt/authentik/media:/media
      - /opt/authentik/custom-templates:/templates
    environment:
      - AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}
      - AUTHENTIK_POSTGRESQL__HOST=postgresql
      - AUTHENTIK_POSTGRESQL__USER=authentik
      - AUTHENTIK_POSTGRESQL__PASSWORD=${PG_PASS}
      - AUTHENTIK_POSTGRESQL__NAME=authentik
      - AUTHENTIK_REDIS__HOST=redis
    depends_on:
      - postgresql
      - redis
    command: server

  worker:
    image: ghcr.io/goauthentik/server:latest
    container_name: authentik-worker
    restart: unless-stopped
    volumes:
      - /opt/authentik/media:/media
      - /opt/authentik/certs:/certs
      - /opt/authentik/custom-templates:/templates
    environment:
      - AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}
      - AUTHENTIK_POSTGRESQL__HOST=postgresql
      - AUTHENTIK_POSTGRESQL__USER=authentik
      - AUTHENTIK_POSTGRESQL__PASSWORD=${PG_PASS}
      - AUTHENTIK_POSTGRESQL__NAME=authentik
      - AUTHENTIK_REDIS__HOST=redis
    depends_on:
      - postgresql
      - redis
    command: worker
```

### Creating a Proxy Provider

For each protected service:

1. **Create Provider** (Admin → Providers → Create)
   - Type: Proxy Provider
   - Name: `grafana-provider`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - External host: `https://grafana.hrmsmrflrii.xyz`
   - Mode: Forward auth (single application)

2. **Create Application** (Admin → Applications → Create)
   - Name: `Grafana`
   - Slug: `grafana`
   - Provider: `grafana-provider`

3. **Assign to Outpost** (THIS IS CRITICAL!)
   - Go to Admin → Outposts → authentik Embedded Outpost
   - Edit and add the application to "Selected Applications"
   - Save

> [!danger] Outpost Assignment
> Forgetting to assign the provider to the Embedded Outpost is the #1 cause of ForwardAuth "404 Not Found" errors. The provider exists, the application exists, but Traefik can't reach it because it's not bound to the outpost.

### Traefik ForwardAuth Middleware

```yaml
# In Traefik dynamic config
http:
  middlewares:
    authentik-auth:
      forwardAuth:
        address: "http://192.168.40.21:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
```

---

## Chapter 12: Media Stack

### The Arr Ecosystem

```
┌────────────────────────────────────────────────────────────┐
│                    Media Acquisition                        │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐                                           │
│  │  Prowlarr   │ ─────► Indexer Management                 │
│  │   :9696     │        (Syncs to all *arrs)               │
│  └──────┬──────┘                                           │
│         │                                                   │
│         │  Indexer Sync                                     │
│         │                                                   │
│  ┌──────▼──────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Radarr    │  │   Sonarr    │  │   Lidarr    │        │
│  │   :7878     │  │   :8989     │  │   :8686     │        │
│  │  (Movies)   │  │    (TV)     │  │  (Music)    │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                 │
│         └────────────────┼────────────────┘                 │
│                          │                                  │
│                          ▼                                  │
│              ┌─────────────────────┐                       │
│              │  Download Clients   │                       │
│              │                     │                       │
│              │ Deluge    SABnzbd   │                       │
│              │ :8112     :8081     │                       │
│              └──────────┬──────────┘                       │
│                         │                                   │
│                         ▼                                   │
│              ┌─────────────────────┐                       │
│              │   /data/Completed   │                       │
│              │   (Unified Storage) │                       │
│              └──────────┬──────────┘                       │
│                         │                                   │
│         ┌───────────────┼───────────────┐                  │
│         │               │               │                   │
│         ▼               ▼               ▼                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐           │
│  │/data/Movies│  │/data/Series│  │/data/Music │           │
│  │  (Radarr)  │  │  (Sonarr)  │  │  (Lidarr)  │           │
│  └──────┬─────┘  └──────┬─────┘  └─────┬──────┘           │
│         │               │               │                   │
│         └───────────────┼───────────────┘                   │
│                         │                                   │
│                         ▼                                   │
│              ┌─────────────────────┐                       │
│              │      Jellyfin       │                       │
│              │       :8096         │                       │
│              │   (Media Server)    │                       │
│              └─────────────────────┘                       │
│                         │                                   │
│                         ▼                                   │
│              ┌─────────────────────┐                       │
│              │     Jellyseerr      │                       │
│              │       :5056         │                       │
│              │  (Request Portal)   │                       │
│              └─────────────────────┘                       │
└────────────────────────────────────────────────────────────┘
```

### Service Configuration

#### Radarr Settings

1. **Media Management**
   - Root Folder: `/data/Movies`
   - Standard Movie Format: `{Movie Title} ({Release Year})`
   - Create empty folders: No
   - Delete empty folders: Yes

2. **Download Clients**
   - Add Deluge: `deluge:8112`
   - Add SABnzbd: `sabnzbd:8080`
   - Category: `radarr`

3. **Import Settings**
   - Use Hardlinks: Yes (critical for unified paths)

#### Sonarr Settings

1. **Media Management**
   - Root Folder: `/data/Series`
   - Standard Episode Format: `{Series Title} - S{season:00}E{episode:00}`

2. **Download Clients**
   - Same as Radarr but category: `sonarr`

#### Prowlarr Sync

1. Add indexers in Prowlarr
2. Go to Settings → Apps
3. Add Radarr, Sonarr, Lidarr with:
   - URL: `http://radarr:7878` (container network)
   - API Key: (from each app's Settings → General)
   - Sync Level: Full Sync

### Bazarr (Subtitles)

```yaml
bazarr:
  image: linuxserver/bazarr:latest
  container_name: bazarr
  restart: unless-stopped
  ports:
    - "6767:6767"
  volumes:
    - /opt/arr-stack/bazarr:/config
    - /mnt/media:/data
  environment:
    - PUID=1000
    - PGID=1000
    - TZ=Asia/Manila
```

Configuration:
1. Settings → Radarr: `radarr:7878` + API key
2. Settings → Sonarr: `sonarr:8989` + API key
3. Settings → Languages: Create profile for preferred languages
4. Settings → Providers: Add OpenSubtitles, Subscene, etc.

### Tdarr (Transcoding)

For automatic transcoding to save space:

```yaml
tdarr:
  image: ghcr.io/haveagitgat/tdarr:latest
  container_name: tdarr
  restart: unless-stopped
  ports:
    - "8265:8265"
    - "8266:8266"
  volumes:
    - /opt/arr-stack/tdarr/server:/app/server
    - /opt/arr-stack/tdarr/configs:/app/configs
    - /opt/arr-stack/tdarr/logs:/app/logs
    - /mnt/media:/data
    - /tmp/tdarr:/temp
  environment:
    - PUID=1000
    - PGID=1000
    - TZ=Asia/Manila
    - serverIP=0.0.0.0
    - serverPort=8266
    - webUIPort=8265
```

---

## Chapter 13: Productivity Services

### Immich (Photo Management)

The service that started it all:

```yaml
# /opt/immich/docker-compose.yml
version: "3.8"

services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    restart: unless-stopped
    ports:
      - "2283:2283"
    volumes:
      - /mnt/immich-uploads:/usr/src/app/upload
      - /mnt/synology-photos:/usr/src/app/external:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      - DB_HOSTNAME=immich-postgres
      - DB_USERNAME=postgres
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_DATABASE_NAME=immich
      - REDIS_HOSTNAME=immich-redis
    depends_on:
      - redis
      - database

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    container_name: immich-ml
    restart: unless-stopped
    volumes:
      - /opt/immich/model-cache:/cache
    environment:
      - MACHINE_LEARNING_CACHE_FOLDER=/cache

  redis:
    image: redis:7-alpine
    container_name: immich-redis
    restart: unless-stopped

  database:
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
    container_name: immich-postgres
    restart: unless-stopped
    volumes:
      - /opt/immich/postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_USER=postgres
      - POSTGRES_DB=immich
```

#### Dual Storage Architecture

```
Immich Storage
├── Active Uploads (Read/Write)
│   └── /mnt/immich-uploads → NFS /volume2/Immich Photos
│
└── Legacy Archive (Read Only)
    └── /mnt/synology-photos → Bind mount from homes/*/Photos
```

This allows:
- New uploads go to dedicated storage
- Old photos from phone backups are accessible read-only
- No migration needed for existing photos

### GitLab (DevOps Platform)

```yaml
# /opt/gitlab/docker-compose.yml
version: "3.8"

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab
    restart: unless-stopped
    hostname: gitlab.hrmsmrflrii.xyz
    ports:
      - "80:80"
      - "443:443"
      - "2222:22"
    volumes:
      - /opt/gitlab/config:/etc/gitlab
      - /opt/gitlab/logs:/var/log/gitlab
      - /opt/gitlab/data:/var/opt/gitlab
    shm_size: "256m"
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.hrmsmrflrii.xyz'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        nginx['listen_port'] = 80
        nginx['listen_https'] = false
        nginx['proxy_set_headers'] = {
          "X-Forwarded-Proto" => "https",
          "X-Forwarded-Ssl" => "on"
        }
```

### n8n (Workflow Automation)

```yaml
# /opt/n8n/docker-compose.yml
version: "3.8"

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    volumes:
      - /opt/n8n/data:/home/node/.n8n
    environment:
      - N8N_HOST=n8n.hrmsmrflrii.xyz
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.hrmsmrflrii.xyz/
      - GENERIC_TIMEZONE=Asia/Manila
```

### Paperless-ngx (Document Management)

```yaml
# /opt/paperless/docker-compose.yml
version: "3.8"

services:
  broker:
    image: redis:7
    container_name: paperless-redis
    restart: unless-stopped

  db:
    image: postgres:15
    container_name: paperless-postgres
    restart: unless-stopped
    volumes:
      - /opt/paperless/postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=paperless
      - POSTGRES_USER=paperless
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

  webserver:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    container_name: paperless
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - /opt/paperless/data:/usr/src/paperless/data
      - /opt/paperless/media:/usr/src/paperless/media
      - /opt/paperless/export:/usr/src/paperless/export
      - /opt/paperless/consume:/usr/src/paperless/consume
    environment:
      - PAPERLESS_REDIS=redis://broker:6379
      - PAPERLESS_DBHOST=db
      - PAPERLESS_SECRET_KEY=${SECRET_KEY}
      - PAPERLESS_URL=https://paperless.hrmsmrflrii.xyz
      - PAPERLESS_TIME_ZONE=Asia/Manila
      - PAPERLESS_OCR_LANGUAGE=eng
    depends_on:
      - db
      - broker
```

---

# Part V: Operations

## Chapter 14: Monitoring and Alerting

### Monitoring Stack Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Monitoring Stack                            │
│               docker-vm-core-utilities01                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐     ┌─────────────────┐                │
│  │   Prometheus    │────►│     Grafana     │                │
│  │     :9090       │     │     :3030       │                │
│  │                 │     │                 │                │
│  │ Time-series DB  │     │   Dashboards    │                │
│  └────────┬────────┘     └─────────────────┘                │
│           │                                                  │
│           │ Scrape                                           │
│           │                                                  │
│  ┌────────┴─────────────────────────────────────────────┐   │
│  │                    Targets                            │   │
│  │                                                       │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │   │
│  │  │ Proxmox  │  │ Traefik  │  │   OTEL   │           │   │
│  │  │ Exporter │  │ Metrics  │  │Collector │           │   │
│  │  └──────────┘  └──────────┘  └──────────┘           │   │
│  │                                                       │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │   │
│  │  │  Jaeger  │  │ Synology │  │  Docker  │           │   │
│  │  │ Metrics  │  │   SNMP   │  │  Stats   │           │   │
│  │  └──────────┘  └──────────┘  └──────────┘           │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────┐                                        │
│  │   Uptime Kuma   │                                        │
│  │     :3001       │                                        │
│  │                 │                                        │
│  │  Health Checks  │ ────► Discord Alerts                   │
│  └─────────────────┘                                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Prometheus Configuration

```yaml
# /opt/monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Proxmox cluster
  - job_name: 'proxmox'
    static_configs:
      - targets: ['192.168.20.20:9221', '192.168.20.21:9221', '192.168.20.22:9221']

  # Traefik
  - job_name: 'traefik'
    static_configs:
      - targets: ['192.168.40.20:8082']

  # OTEL Collector
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['localhost:8889']

  # Jaeger
  - job_name: 'jaeger'
    static_configs:
      - targets: ['localhost:14269']

  # Docker hosts
  - job_name: 'docker'
    static_configs:
      - targets:
        - '192.168.40.13:9323'  # utilities
        - '192.168.40.11:9323'  # media
        - '192.168.40.20:9323'  # traefik
        - '192.168.40.21:9323'  # authentik
        - '192.168.40.22:9323'  # immich
        - '192.168.40.23:9323'  # gitlab

  # Synology NAS
  - job_name: 'synology'
    static_configs:
      - targets: ['localhost:9101']
    metrics_path: /snmp
    params:
      module: [synology]
      target: ['192.168.10.31']
```

### Docker Compose for Monitoring

```yaml
# /opt/monitoring/docker-compose.yml
version: "3.8"

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
      - '--storage.tsdb.retention.size=10GB'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3030:3000"
    volumes:
      - /opt/monitoring/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
      - GF_SERVER_ROOT_URL=https://grafana.hrmsmrflrii.xyz

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - /opt/monitoring/uptime-kuma:/app/data

volumes:
  prometheus_data:
```

### Uptime Kuma Monitors

| Monitor | Type | Target | Interval |
|---------|------|--------|----------|
| Proxmox Node 01 | ICMP Ping | 192.168.20.20 | 60s |
| Proxmox Node 02 | ICMP Ping | 192.168.20.21 | 60s |
| Proxmox Node 03 | ICMP Ping | 192.168.20.22 | 60s |
| Traefik | HTTP | https://traefik.hrmsmrflrii.xyz/ping | 60s |
| Authentik | HTTP | https://auth.hrmsmrflrii.xyz/-/health/live/ | 60s |
| Jellyfin | HTTP | http://192.168.40.11:8096/health | 60s |
| Radarr | HTTP | http://192.168.40.11:7878/ping | 60s |
| Sonarr | HTTP | http://192.168.40.11:8989/ping | 60s |
| K8s API | TCP | 192.168.20.32:6443 | 60s |

### Grafana Dashboards

Essential dashboards to import:

| Dashboard | ID | Purpose |
|-----------|-----|---------|
| Node Exporter Full | 1860 | Linux host metrics |
| Docker | 893 | Container metrics |
| Traefik | 17346 | Request rate, latency |
| Proxmox | 10347 | Cluster overview |

---

## Chapter 15: Observability and Tracing

### Why Distributed Tracing?

When a request flows through multiple services:

```
User → Traefik → Authentik → Service → Database
```

Traditional logging shows each service's view in isolation. Tracing shows the complete journey with timing.

### OpenTelemetry Collector

```yaml
# /opt/observability/otel-collector-config.yml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024

  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

  resource:
    attributes:
      - key: deployment.environment
        value: homelab
        action: upsert

exporters:
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true

  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: otel

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, resource]
      exporters: [jaeger]

    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
```

### Jaeger Configuration

```yaml
# In docker-compose.yml
jaeger:
  image: jaegertracing/all-in-one:latest
  container_name: jaeger
  restart: unless-stopped
  ports:
    - "16686:16686"  # UI
    - "14250:14250"  # Model.proto
    - "14268:14268"  # Jaeger.thrift
    - "14269:14269"  # Admin/health
    - "4317:4317"    # OTLP gRPC
    - "4318:4318"    # OTLP HTTP
  environment:
    - COLLECTOR_OTLP_ENABLED=true
    - SPAN_STORAGE_TYPE=memory
    - MEMORY_MAX_TRACES=50000
```

### Instrumenting Services

#### Traefik Tracing

```yaml
# traefik.yml
tracing:
  otlp:
    http:
      endpoint: "http://192.168.40.13:4318/v1/traces"
```

#### Python Application Example

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

# Setup
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

otlp_exporter = OTLPSpanExporter(
    endpoint="http://192.168.40.13:4318/v1/traces"
)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)

# Usage
with tracer.start_as_current_span("process_request") as span:
    span.set_attribute("user.id", user_id)
    # ... processing logic
```

### Demo Application

A test app for verifying tracing:

```python
# /opt/observability/demo-app/app.py
from flask import Flask, jsonify
from opentelemetry.instrumentation.flask import FlaskInstrumentor
import time
import random

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

@app.route('/api/data')
def get_data():
    # Simulate processing
    time.sleep(random.uniform(0.1, 0.3))
    return jsonify({"status": "success", "data": [1, 2, 3]})

@app.route('/api/slow')
def slow_endpoint():
    # Intentionally slow for testing
    time.sleep(random.uniform(1, 3))
    return jsonify({"status": "success", "message": "Slow response"})

@app.route('/api/error')
def error_endpoint():
    # 50% chance of error
    if random.random() > 0.5:
        raise Exception("Random error for testing")
    return jsonify({"status": "success"})
```

---

## Chapter 16: Automated Updates

### Watchtower Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Update Flow                                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Host 1  │  │ Host 2  │  │ Host 3  │  │ Host 4  │        │
│  │Watchtower│  │Watchtower│  │Watchtower│  │Watchtower│       │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
│       │            │            │            │               │
│       └────────────┴─────┬──────┴────────────┘               │
│                          │                                   │
│                          │ Webhook (update available)        │
│                          ▼                                   │
│              ┌───────────────────────┐                      │
│              │    Update Manager     │                      │
│              │   192.168.40.13:5050  │                      │
│              │                       │                      │
│              │  Flask + Discord.py   │                      │
│              └───────────┬───────────┘                      │
│                          │                                   │
│                          │ Discord Message                   │
│                          ▼                                   │
│              ┌───────────────────────┐                      │
│              │    Discord Channel    │                      │
│              │   #update-manager     │                      │
│              │                       │                      │
│              │  "radarr update       │                      │
│              │   available: 5.2.1"   │                      │
│              │                       │                      │
│              │  [✅] [❌]            │                      │
│              └───────────────────────┘                      │
│                          │                                   │
│                          │ User clicks ✅                    │
│                          ▼                                   │
│              ┌───────────────────────┐                      │
│              │    Update Manager     │                      │
│              │                       │                      │
│              │  SSH → docker pull    │                      │
│              │  SSH → docker restart │                      │
│              └───────────────────────┘                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Watchtower Configuration

```yaml
# On each Docker host
watchtower:
  image: containrrr/watchtower:latest
  container_name: watchtower
  restart: unless-stopped
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  environment:
    - WATCHTOWER_MONITOR_ONLY=true
    - WATCHTOWER_SCHEDULE=0 0 3 * * *  # 3 AM daily
    - WATCHTOWER_NOTIFICATIONS=shoutrrr
    - WATCHTOWER_NOTIFICATION_URL=generic+http://192.168.40.13:5050/webhook
    - WATCHTOWER_CLEANUP=true
```

> [!warning] Webhook URL Format
> The URL must be `generic+http://` not `generic://`. The scheme is part of the URL format and incorrect formatting causes TLS handshake errors.

### Update Manager Bot

```python
# /opt/update-manager/update_manager.py (simplified)
import discord
from discord.ext import commands
from flask import Flask, request
import paramiko
import threading

app = Flask(__name__)
bot = commands.Bot(command_prefix='!')

# Container → Host mapping
CONTAINER_HOSTS = {
    'radarr': '192.168.40.11',
    'sonarr': '192.168.40.11',
    'jellyfin': '192.168.40.11',
    'traefik': '192.168.40.20',
    'authentik-server': '192.168.40.21',
    'immich-server': '192.168.40.22',
    'gitlab': '192.168.40.23',
    'glance': '192.168.40.12',
    'prometheus': '192.168.40.13',
}

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    # Parse Watchtower notification
    # Send to Discord with reaction buttons
    return 'OK'

@bot.event
async def on_reaction_add(reaction, user):
    if str(reaction.emoji) == '✅':
        # Extract container name from message
        # SSH to host and update
        host = CONTAINER_HOSTS[container_name]
        update_container(host, container_name)

def update_container(host, container):
    ssh = paramiko.SSHClient()
    ssh.connect(host, username='hermes-admin', key_filename='/root/.ssh/id_ed25519')
    ssh.exec_command(f'docker pull {container}')
    ssh.exec_command(f'docker compose -f /opt/*/docker-compose.yml up -d {container}')
```

---

## Chapter 17: Discord Bot Automation

### Sentinel - Unified Homelab Bot

The homelab uses a single consolidated Discord bot called **Sentinel** that replaces the previous 4 separate bots (Argus, Chronos, Mnemosyne, Athena). This consolidation simplifies maintenance and provides a unified command interface.

| Property | Value |
|----------|-------|
| **Host** | docker-vm-core-utilities01 (192.168.40.13) |
| **Location** | `/opt/sentinel-bot/` |
| **Container** | `sentinel-bot` |
| **Webhook Port** | 5050 |
| **Framework** | discord.py 2.3+ with Quart async HTTP |

### Architecture

```
Discord Server
     │
     ▼
Sentinel Bot (discord.py 2.3+)
├── Core
│   ├── bot.py           → Main SentinelBot class
│   ├── database.py      → Async SQLite (aiosqlite)
│   ├── channel_router.py → Notification routing
│   ├── progress.py      → Progress bar utilities
│   └── ssh_manager.py   → Async SSH (asyncssh)
│
├── Cogs (8 modules)
│   ├── homelab.py       → Proxmox cluster management
│   ├── updates.py       → Container updates + reaction approvals
│   ├── media.py         → Download monitoring + Jellyseerr
│   ├── gitlab.py        → GitLab issue management
│   ├── tasks.py         → Claude task queue
│   ├── onboarding.py    → Service verification
│   ├── scheduler.py     → Daily reports (7pm, 9am)
│   └── power.py         → Cluster power management (WoL, shutdown)
│
├── Webhooks (Quart on port 5050)
│   ├── /webhook/watchtower  → Container update notifications
│   ├── /webhook/jellyseerr  → Media request notifications
│   └── /api/tasks           → Claude task queue REST API
│
└── Services (API integrations)
    ├── proxmox.py      → Prometheus + SSH
    ├── radarr.py       → Radarr v3 API
    ├── sonarr.py       → Sonarr v3 API
    └── jellyseerr.py   → Jellyseerr API
```

### Channel Routing

Each cog sends messages to a dedicated Discord channel:

| Cog | Channel | Purpose |
|-----|---------|---------|
| **Homelab** | `#homelab-infrastructure` | Proxmox status, VM/LXC/node management |
| **Updates** | `#container-updates` | Container updates with reaction approvals |
| **Media** | `#media-downloads` | Download progress, failed alerts, library stats |
| **GitLab** | `#project-management` | Issue creation and tracking |
| **Tasks** | `#claude-tasks` | Claude task queue management |
| **Onboarding** | `#new-service-onboarding-workflow` | Service verification checks |
| **Scheduler** | Various | Daily reports, download monitoring |
| **Power** | `#announcements` | Cluster power management |

### Key Commands

#### Homelab Management (`#homelab-infrastructure`)

| Command | Description |
|---------|-------------|
| `/help` | Show all Sentinel commands |
| `/insight` | Health check: memory, errors, storage, downloads |
| `/homelab status` | Cluster overview with resource bars |
| `/homelab uptime` | Uptime for all nodes/VMs/LXCs |
| `/node <name> status` | Detailed node status |
| `/vm <id> start/stop/restart` | Control a VM |
| `/lxc <id> start/stop/restart` | Control an LXC container |

#### Container Updates (`#container-updates`)

| Command | Description |
|---------|-------------|
| `/check` | Scan all containers for updates |
| `/update <container>` | Update specific container |
| `/updateall` | Update all with pending updates |
| `/containers` | List monitored containers |

#### Media (`#media-downloads`)

| Command | Description |
|---------|-------------|
| `/downloads` | Current download queue with progress bars |
| `/download <title>` | Search & add via Jellyseerr |
| `/library movies` | Movie library statistics |
| `/library shows` | TV library statistics |
| `/recent` | Recently added media |

#### Power Management (`#announcements`)

| Command | Description |
|---------|-------------|
| `/shutdownall` | Shutdown ALL VMs, LXCs, and Proxmox nodes |
| `/shutdown-nodns` | Shutdown all except Pi-hole (LXC 202) and node01 |
| `/startall` | Wake nodes via WoL, start all LXCs and VMs |

> **Safety Feature**: All power commands require ⚠️ reaction to confirm (60-second timeout). Shutdown order: VMs → LXCs → Nodes.

### Wake-on-LAN Configuration

For `/startall` to wake powered-off nodes:

| Node | MAC Address |
|------|-------------|
| node01 | `38:05:25:32:82:76` |
| node02 | `84:47:09:4d:7a:ca` |
| node03 | `d8:43:ae:a8:4c:a7` |

### Reaction-Based Update Approval

Sentinel uses Discord reactions for safe container updates:

```
1. Watchtower detects updates → posts embed to #container-updates
2. User reacts with 👍 to approve ALL updates
3. Number emojis (1️⃣, 2️⃣, etc.) for individual updates
4. Bot executes approved updates via SSH
5. Completion notification with status
```

### Scheduled Tasks

| Task | Time | Channel |
|------|------|---------|
| Update Availability Report | 7:00 PM daily | `#container-updates` |
| Onboarding Status Report | 9:00 AM daily | `#new-service-onboarding-workflow` |
| Download Completion Check | Every 60 seconds | `#media-downloads` |
| Failed Download Check | Every 5 minutes | `#media-downloads` |

### Deployment

```bash
# Deploy via Ansible
cd ~/ansible
ansible-playbook sentinel-bot/deploy-sentinel-bot.yml

# Manual restart
ssh hermes-admin@192.168.40.13 "cd /opt/sentinel-bot && sudo docker compose restart"

# View logs
ssh hermes-admin@192.168.40.13 "docker logs sentinel-bot --tail 50"
```

---

# Part VI: Advanced Topics

## Chapter 18: Kubernetes at Home

### When to Use Kubernetes

| Use Case | Docker Compose | Kubernetes |
|----------|----------------|------------|
| Single host | ✅ Perfect | ❌ Overkill |
| 2-3 hosts | ✅ Good | ⚠️ Maybe |
| HA requirements | ❌ Manual | ✅ Built-in |
| Auto-scaling | ❌ No | ✅ Yes |
| Learning | ✅ Start here | ✅ Then here |

**My reasoning**: I run Kubernetes primarily for learning. Most homelab services work fine with Docker Compose.

### Cluster Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Kubernetes Cluster                           │
│                    VLAN 20                                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Control Plane (HA)                      │    │
│  │                                                      │    │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │    │
│  │  │ Controller01 │ │ Controller02 │ │ Controller03 │ │    │
│  │  │192.168.20.32 │ │192.168.20.33 │ │192.168.20.34 │ │    │
│  │  │              │ │              │ │              │ │    │
│  │  │ kube-apiserver  kube-apiserver  kube-apiserver │ │    │
│  │  │ etcd            etcd            etcd           │ │    │
│  │  │ controller-mgr  controller-mgr  controller-mgr │ │    │
│  │  │ scheduler       scheduler       scheduler      │ │    │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           │ API (6443)                       │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  Worker Nodes                        │    │
│  │                                                      │    │
│  │  ┌────────┐ ┌────────┐ ┌────────┐                   │    │
│  │  │Worker01│ │Worker02│ │Worker03│                   │    │
│  │  │  .40   │ │  .41   │ │  .42   │                   │    │
│  │  └────────┘ └────────┘ └────────┘                   │    │
│  │                                                      │    │
│  │  ┌────────┐ ┌────────┐ ┌────────┐                   │    │
│  │  │Worker04│ │Worker05│ │Worker06│                   │    │
│  │  │  .43   │ │  .44   │ │  .45   │                   │    │
│  │  └────────┘ └────────┘ └────────┘                   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  Network: Calico v3.27.0                                    │
│  Container Runtime: containerd v1.7.28                      │
│  Kubernetes Version: v1.28.15                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Deployment with Ansible

```yaml
# k8s/k8s-deploy-all.yml
---
- name: Deploy Kubernetes Cluster
  hosts: k8s_controllers:k8s_workers
  become: yes

  tasks:
    - name: Install prerequisites
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
        state: present

    - name: Add Kubernetes GPG key
      apt_key:
        url: https://packages.cloud.google.com/apt/doc/apt-key.gpg
        state: present

    - name: Add Kubernetes repository
      apt_repository:
        repo: deb https://apt.kubernetes.io/ kubernetes-xenial main
        state: present

    - name: Install Kubernetes components
      apt:
        name:
          - kubelet=1.28.15-00
          - kubeadm=1.28.15-00
          - kubectl=1.28.15-00
        state: present

    - name: Hold Kubernetes packages
      dpkg_selections:
        name: "{{ item }}"
        selection: hold
      loop:
        - kubelet
        - kubeadm
        - kubectl

- name: Initialize first controller
  hosts: k8s-controller01
  become: yes

  tasks:
    - name: Initialize cluster
      command: >
        kubeadm init
        --control-plane-endpoint "192.168.20.32:6443"
        --upload-certs
        --pod-network-cidr=10.244.0.0/16
      register: kubeadm_init

    - name: Create .kube directory
      file:
        path: /home/hermes-admin/.kube
        state: directory
        owner: hermes-admin
        group: hermes-admin

    - name: Copy kubeconfig
      copy:
        src: /etc/kubernetes/admin.conf
        dest: /home/hermes-admin/.kube/config
        remote_src: yes
        owner: hermes-admin
        group: hermes-admin
```

### Kubelet Health Endpoint

For external monitoring (Glance, Prometheus), kubelet must bind to all interfaces:

```yaml
# /var/lib/kubelet/config.yaml (on each worker)
healthzBindAddress: 0.0.0.0
healthzPort: 10248
```

> [!important] Default Binding
> Kubelet defaults to `127.0.0.1:10248`, which blocks external health checks. Change to `0.0.0.0` for monitoring tools to access.

---

## Chapter 19: CI/CD Pipelines

### The Evolution to GitOps

When I first set up CI/CD, I used a monorepo approach with a central `homelab-services` repository. Every service definition lived in one place, and a complex change detection system figured out what to deploy. It worked, but it had problems:

- A bad commit could break all services
- The pipeline grew unwieldy with 13 stages
- Change detection was complex and error-prone
- Permissions were all-or-nothing

The solution? **GitOps with a polyrepo architecture.**

### GitOps Polyrepo Architecture

Instead of one repo for all services, each service gets its own repository:

```
gitlab.hrmsmrflrii.xyz/homelab/
├── glance-homelab/       # Glance dashboard
├── grafana-homelab/      # Grafana monitoring
├── jellyfin-homelab/     # Media server
├── sentinel-bot-homelab/ # Discord bot
└── ...                   # One repo per service
```

**Why This Works Better:**

| Aspect | Monorepo | Polyrepo |
|--------|----------|----------|
| **Blast Radius** | Bad commit breaks all | Bad commit breaks one service |
| **Deployment** | Complex change detection | Simple - any push deploys |
| **Permissions** | One key for everything | Per-repo access control |
| **History** | Mixed commits for all services | Clear history per service |
| **Pipelines** | One complex pipeline | Many simple pipelines |

### Repository Structure

Every service repo follows this structure:

```
<service>-homelab/
├── .gitlab-ci.yml          # 5-stage pipeline definition
├── service.yml             # GitOps metadata
├── config/
│   ├── docker-compose.yml  # Container definition
│   └── <service>.yml       # Service-specific config
├── assets/                 # Static files (optional)
└── README.md               # Service documentation
```

### The service.yml File

This is the "source of truth" for each service:

```yaml
service:
  name: glance
  display_name: Glance Dashboard
  category: dashboard
  version: "0.7.0"

deployment:
  target_host: docker-lxc-glance
  port: 8080
  install_path: /opt/glance
  secrets:
    - name: RADARR_API_KEY
      source: GLANCE_RADARR_API_KEY  # GitLab CI/CD variable

traefik:
  enabled: true
  subdomain: glance

notifications:
  discord:
    enabled: true
```

### The 5-Stage Pipeline

Every service uses this simple pipeline:

```
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ validate │→ │  deploy  │→ │configure │→ │  verify  │→ │  notify  │
└──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘
```

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - deploy
  - configure
  - verify
  - notify

variables:
  SERVICE_NAME: glance
  TARGET_IP: "192.168.40.12"
  INSTALL_PATH: /opt/glance
  PORT: "8080"

validate:yaml:
  stage: validate
  script:
    - yq eval '.' service.yml > /dev/null
    - yq eval '.' config/glance.yml > /dev/null

deploy:service:
  stage: deploy
  script:
    # Generate .env from GitLab secrets
    - cat > /tmp/.env << EOF
      RADARR_API_KEY=${GLANCE_RADARR_API_KEY}
      EOF
    # Copy files and deploy
    - scp config/* ${SSH_USER}@${TARGET_IP}:${INSTALL_PATH}/config/
    - ssh ${SSH_USER}@${TARGET_IP} "cd ${INSTALL_PATH} && docker compose up -d"

configure:traefik:
  stage: configure
  script:
    - scp traefik-route.yml root@192.168.40.20:/opt/traefik/config/dynamic/

verify:health:
  stage: verify
  script:
    - curl -sf http://${TARGET_IP}:${PORT}

notify:discord:
  stage: notify
  script:
    - curl -d '{"content":"Deployed: ${SERVICE_NAME}"}' ${DISCORD_WEBHOOK_URL}
```

### Making Changes with GitOps

The workflow is beautifully simple:

```bash
# 1. Clone the service repo
git clone git@gitlab.hrmsmrflrii.xyz:homelab/glance-homelab.git
cd glance-homelab

# 2. Make your change
vim config/glance.yml  # Add a new widget

# 3. Commit and push
git add .
git commit -m "Add Portainer bookmark to Home page"
git push

# 4. Watch the magic happen
# - Pipeline validates your YAML
# - Copies files to target host
# - Restarts the container
# - Verifies health
# - Sends Discord notification
```

That's it. No SSH. No manual docker commands. Just Git.

### Legacy: Monorepo Approach

For reference, here's the older monorepo approach (still works, but polyrepo is preferred):

### GitLab CI/CD for Service Onboarding

Automated pipeline for deploying new services:

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - deploy
  - configure_traefik
  - configure_dns
  - register_watchtower
  - configure_sso
  - notify

variables:
  ANSIBLE_HOST: 192.168.20.30

validate:
  stage: validate
  script:
    - python3 scripts/validate_service.py services/$SERVICE_NAME.yml
  only:
    - merge_requests

deploy:
  stage: deploy
  script:
    - ssh hermes-admin@$ANSIBLE_HOST "ansible-playbook deploy-service.yml -e @services/$SERVICE_NAME.yml"
  only:
    - main

configure_traefik:
  stage: configure_traefik
  script:
    - python3 scripts/add_traefik_route.py services/$SERVICE_NAME.yml
    - ssh hermes-admin@192.168.40.20 "docker exec traefik traefik reload"
  only:
    - main

configure_dns:
  stage: configure_dns
  script:
    - python3 scripts/add_dns_entry.py services/$SERVICE_NAME.yml
  only:
    - main

register_watchtower:
  stage: register_watchtower
  script:
    - python3 scripts/register_watchtower.py services/$SERVICE_NAME.yml
  only:
    - main

configure_sso:
  stage: configure_sso
  script:
    - python3 scripts/configure_authentik.py services/$SERVICE_NAME.yml
  when: manual  # Requires manual trigger
  only:
    - main

notify:
  stage: notify
  script:
    - python3 scripts/notify_discord.py "Service $SERVICE_NAME deployed successfully"
  only:
    - main
```

### Service Definition Schema

```yaml
# services/new-service.yml
name: new-service
display_name: New Service
description: A new service for the homelab

deployment:
  target_host: docker-vm-core-utilities01
  port: 8080
  image: organization/new-service:latest
  volumes:
    - /opt/new-service/config:/config
    - /opt/new-service/data:/data
  environment:
    TZ: Asia/Manila
    PUID: 1000
    PGID: 1000

traefik:
  enabled: true
  domain: new-service.hrmsmrflrii.xyz

authentik:
  enabled: true
  provider_type: proxy

watchtower:
  enabled: true
  notify: true
```

---

## Chapter 20: External Access

### Cloudflare Tunnel

Secure external access without port forwarding:

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet                                 │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  Cloudflare Edge                             │
│            (DDoS protection, SSL termination)                │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Encrypted Tunnel
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    cloudflared                               │
│               (192.168.40.13 - Homelab)                      │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      Traefik                                 │
│                  192.168.40.20                               │
└─────────────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
     Jellyfin       Jellyseerr        Other
```

### cloudflared Configuration

```yaml
# /opt/cloudflared/docker-compose.yml
version: "3.8"

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=${TUNNEL_TOKEN}
```

### Tunnel Routes

Configure in Cloudflare Zero Trust dashboard:

| Public Hostname | Service | Internal URL |
|-----------------|---------|--------------|
| jellyfin.domain.com | Jellyfin | http://192.168.40.11:8096 |
| jellyseerr.domain.com | Jellyseerr | http://192.168.40.11:5056 |

### Security Considerations

1. **Jellyfin**: Has its own authentication, safe to expose
2. **Jellyseerr**: Should be behind Authentik for SSO
3. **Admin interfaces**: Never expose directly

---

# Part VII: Wisdom

## Chapter 21: Troubleshooting Guide

### Methodology

When something breaks, follow this process:

```
1. Identify symptoms (what's failing?)
2. Check logs (where's the error?)
3. Isolate the problem (what changed?)
4. Form hypothesis (why might this happen?)
5. Test hypothesis (does the fix work?)
6. Document (how do we prevent this?)
```

### Common Issues and Solutions

#### Proxmox

**Issue: VM hangs at boot with no output**

Symptoms:
- Console shows nothing after BIOS
- Cloud-init never runs
- VM appears stuck

Root Cause: UEFI/BIOS boot mode mismatch

Fix:
```bash
# Check boot mode
qm config <vmid> | grep -E "bios|efidisk"

# If template uses UEFI but VM doesn't have efidisk:
qm set <vmid> -bios ovmf -efidisk0 VMDisks:0,format=qcow2
```

**Issue: Corosync crashes with SIGSEGV**

Symptoms:
- `corosync[pid]: Caught signal 11 (SIGSEGV)`
- Cluster loses quorum randomly

Root Cause: NSS crypto library corruption

Fix:
```bash
apt reinstall libnss3 libknet1
systemctl restart corosync
```

#### Kubernetes

**Issue: kubectl works on controller01 but not controller02/03**

Symptoms:
- `The connection to the server localhost:8080 was refused`
- Only first controller can manage cluster

Root Cause: kubeconfig not distributed after cluster init

Fix:
```bash
# On controller01
scp /etc/kubernetes/admin.conf hermes-admin@k8s-controller02:~/.kube/config
scp /etc/kubernetes/admin.conf hermes-admin@k8s-controller03:~/.kube/config
```

**Issue: Kubelet health check fails from external monitoring**

Symptoms:
- Glance/Uptime Kuma can't reach kubelet healthz
- Prometheus scrape fails

Root Cause: Kubelet binds to localhost by default

Fix:
```yaml
# /var/lib/kubelet/config.yaml
healthzBindAddress: 0.0.0.0
healthzPort: 10248
```

Then:
```bash
systemctl restart kubelet
```

#### Authentication

**Issue: Authentik ForwardAuth returns 404 "Outpost not found"**

Symptoms:
- Traefik returns 404 for protected services
- Authentik logs show "outpost not found"

Root Cause: Provider not assigned to Embedded Outpost

Fix:
1. Go to Authentik Admin → Outposts
2. Edit "authentik Embedded Outpost"
3. Add application to "Selected Applications"
4. Save

> [!danger] This is the #1 Authentik mistake
> Creating provider + application is not enough. You MUST assign to the Embedded Outpost.

#### Container Issues

**Issue: Watchtower webhook fails with TLS error**

Symptoms:
- `TLS handshake error`
- Updates never reach Discord

Root Cause: Wrong URL scheme format

Fix:
```yaml
# Wrong
WATCHTOWER_NOTIFICATION_URL: "generic://192.168.40.13:5050/webhook"

# Correct
WATCHTOWER_NOTIFICATION_URL: "generic+http://192.168.40.13:5050/webhook"
```

**Issue: Jellyfin shows empty library despite files existing**

Symptoms:
- Movies/shows exist in filesystem
- Jellyfin library scan finds nothing
- Logs show "folder inaccessible or empty"

Root Cause: Path mismatch between download clients and media managers

Fix: Use unified path structure:
```yaml
# All services use same mount
volumes:
  - /mnt/media:/data

# Radarr root: /data/Movies
# Sonarr root: /data/Series
# Deluge download: /data/Completed
```

#### Network Issues

**Issue: NFS mount fails at boot**

Symptoms:
- Services fail because mounts aren't ready
- Manual mount works fine

Root Cause: Missing `_netdev` flag

Fix:
```bash
# /etc/fstab
192.168.20.31:/volume2/Media  /mnt/media  nfs  defaults,_netdev  0  0
```

### Diagnostic Commands

```bash
# Proxmox cluster status
pvecm status

# VM configuration
qm config <vmid>

# Container logs
docker logs <container> --tail 100 -f

# Kubernetes cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A

# Network connectivity
ping <ip>
nc -zv <ip> <port>
curl -v http://<ip>:<port>/health

# Service status
systemctl status <service>
journalctl -u <service> -f

# Disk space
df -h
du -sh /opt/*

# Memory usage
free -h
top -bn1 | head -20

# Process list
ps aux | grep <process>
```

---

## Chapter 22: Lessons Learned

### Infrastructure Lessons

1. **Always verify boot mode**
   - UEFI templates need UEFI VMs
   - BIOS/UEFI mismatch causes silent boot failures
   - Check with `qm config <vmid>` before troubleshooting

2. **One NFS export = One storage pool**
   - Prevents state confusion
   - Makes troubleshooting easier
   - Avoids UI issues in Proxmox

3. **Unified paths are essential for media**
   - Hardlinks only work on same filesystem
   - Different container paths = copy instead of hardlink
   - All Arr services need identical `/mnt/media:/data` mount

4. **VLAN-aware bridge is required**
   - Without it, VLAN tags don't work
   - Add `bridge-vlan-aware yes` to network config
   - Common cause of "can't reach VLAN 40" issues

### Automation Lessons

5. **Document everything as you go**
   - Future you will forget
   - Use three-tier documentation (docs/, wiki, Obsidian)
   - Include the "why", not just the "what"

6. **Test playbooks with --check first**
   - Ansible dry-run catches most issues
   - Saves rollback pain

7. **Keep secrets out of git**
   - Use `.env` files (gitignored)
   - Use Ansible vault for sensitive vars
   - Never hardcode API keys

### Service Lessons

8. **Authentik outpost assignment is mandatory**
   - Creating provider isn't enough
   - Must bind to Embedded Outpost
   - Most common SSO failure

9. **Webhook URL formats matter**
   - `generic+http://` not `generic://`
   - `http://` vs `https://` causes TLS errors
   - Check documentation for exact format

10. **Glance config changed in v0.7.0**
    - Directory mount required (`./config:/app/config`)
    - Single file mount no longer works
    - Check release notes when updating

### Operational Lessons

11. **Monitoring before you need it**
    - Set up Uptime Kuma first
    - Add Discord alerts early
    - You'll thank yourself at 2 AM

12. **Backup configs before changes**
    - `cp config config.bak` takes 2 seconds
    - Rollback takes hours without it

13. **Read logs before googling**
    - 90% of issues are in the logs
    - `docker logs <container> | tail -50`
    - Saves hours of wrong-path troubleshooting

### Growth Lessons

14. **Start simple, add complexity later**
    - Docker Compose before Kubernetes
    - Single host before cluster
    - Manual before automated

15. **Learn by breaking things**
    - Lab is for experiments
    - Every failure is a lesson
    - Document what went wrong

---

## Chapter 23: Cost Analysis

### Hardware Investment

| Component | Cost | Notes |
|-----------|------|-------|
| 3x Mini PCs | $900 | Used/refurbished |
| Synology NAS | $400 | DS220+ |
| 2x 4TB HDDs | $160 | WD Red |
| Managed Switch | $150 | TP-Link SG3210 |
| Router | $80 | TP-Link ER605 |
| WiFi APs | $200 | 3x EAP series |
| UPS | $150 | CyberPower 1500VA |
| **Total** | **~$2,040** | |

### Operating Costs

| Item | Monthly | Annual |
|------|---------|--------|
| Electricity (~150W avg) | $15 | $180 |
| Domain | $1.50 | $18 |
| Cloud backup (B2) | $5 | $60 |
| **Total** | **~$21.50** | **~$258** |

### Value Delivered

#### Services Replaced

| Service | Monthly Cost | Annual Savings |
|---------|--------------|----------------|
| Google Photos (2TB) | $10 | $120 |
| Plex Pass | $5 | $60 |
| VPN service | $10 | $120 |
| Password manager | $3 | $36 |
| Cloud storage | $15 | $180 |
| **Total Savings** | **~$43** | **~$516** |

#### Intangible Value

- **Privacy**: Data stays home
- **Learning**: Enterprise skills
- **Control**: No service shutdowns
- **Customization**: Exactly what you need

### ROI Calculation

```
Initial Investment:     $2,040
Annual Operating Cost:  $258
Annual Savings:         $516

Net Annual Benefit:     $258
Payback Period:         ~4 years
```

Plus: Priceless learning experience that translates directly to career skills.

---

# Part VIII: Cloud Integration

## Chapter 24: Azure Cloud Environment

### Extending the Homelab to the Cloud

While a homelab provides excellent learning opportunities, integrating cloud services extends your infrastructure's capabilities significantly. Azure provides enterprise-grade SIEM, centralized logging, and a platform for deploying hybrid workloads.

### Azure Architecture Overview

```
                              AZURE CLOUD
                         Subscription: FireGiants-Prod
                         Region: Southeast Asia

  +---------------------------------------------------------------------+
  |                        deployment-rg                                 |
  |  +---------------------------------------------------------------+  |
  |  |              ans-tf-vm01-vnet (10.90.10.0/29)                  |  |
  |  |                                                               |  |
  |  |    +-------------------+      +---------------------------+   |  |
  |  |    | ans-tf-vm01       |      | ubuntu-deploy-vm          |   |  |
  |  |    | Windows 11        |      | Ubuntu 22.04 LTS          |   |  |
  |  |    | 10.90.10.4        |      | 10.90.10.5                |   |  |
  |  |    |                   |      | Standard_D2s_v3           |   |  |
  |  |    | - WinRM enabled   |      | - Terraform               |   |  |
  |  |    | - Terraform       |      | - Ansible                 |   |  |
  |  |    | - Azure CLI       |      | - Azure CLI               |   |  |
  |  |    | - Managed ID      |      | - Managed ID (Contributor)|   |  |
  |  |    +-------------------+      +---------------------------+   |  |
  |  +---------------------------------------------------------------+  |
  +---------------------------------------------------------------------+
                                   |
                    +--------------+--------------+
                    |     Site-to-Site VPN        |
                    |   Azure <-> OPNsense        |
                    +--------------+--------------+
                                   |
                           HOMELAB (On-Premises)
```

### Quick Reference

| Property | Value |
|----------|-------|
| **Subscription** | FireGiants-Prod |
| **Subscription ID** | `2212d587-1bad-4013-b605-b421b1f83c30` |
| **Tenant ID** | `b6458a9a-9661-468c-bda3-5f496727d0b0` |
| **Region** | Southeast Asia |
| **VNet CIDR** | 10.90.10.0/29 |

### Deployment Virtual Machines

#### ubuntu-deploy-vm (Primary)

This VM handles all Terraform and Ansible deployments for Azure resources.

| Property | Value |
|----------|-------|
| **OS** | Ubuntu 22.04 LTS (Jammy) |
| **Size** | Standard_D2s_v3 (2 vCPU, 8 GB RAM) |
| **Private IP** | 10.90.10.5 |
| **Public IP** | None (NAT Gateway for outbound) |
| **Disk** | 64 GB Standard SSD |
| **Managed Identity** | System-assigned (Contributor role) |

**Installed Tools:**
- Terraform (Infrastructure as Code)
- Ansible (Configuration Management)
- Azure CLI (Azure Management)
- Git (Version Control)

```bash
# SSH Access (via VPN)
ssh ubuntu-deploy
# Or explicitly
ssh -i ~/.ssh/ubuntu-deploy-vm.pem hermes-admin@10.90.10.5
```

### Azure Sentinel (SIEM)

Azure Sentinel provides centralized security information and event management (SIEM) capabilities for the homelab.

| Resource | Name | Purpose |
|----------|------|---------|
| Log Analytics Workspace | law-homelab-sentinel | Log storage and querying |
| Sentinel | (attached to LAW) | SIEM analytics and detection |
| Data Collection Endpoint | dce-homelab-syslog | Ingestion endpoint for AMA |
| Data Collection Rule | dcr-homelab-syslog | Defines what logs to collect |

#### Log Flow Architecture

```
Homelab Devices
    │
    ▼
linux-syslog-server01 (192.168.40.5)
├── Azure Arc Agent
├── Azure Monitor Agent (AMA)
└── rsyslog (collects from Omada, etc.)
    │
    ▼ (via DCR/DCE)
Azure Sentinel
├── Analytics Rules
├── Workbooks
└── Incidents
```

#### Useful KQL Queries

```kusto
// View recent syslog entries
Syslog
| take 10

// Filter by facility
Syslog
| where Facility == "auth"
| take 100

// Omada-specific logs
Syslog
| where Computer == "linux-syslog-server01"
| where SyslogMessage contains "omada"
| take 50

// Error-level logs
Syslog
| where SeverityLevel in ("err", "crit", "alert", "emerg")
| order by TimeGenerated desc
| take 100
```

### Terraform Deployment Workflow

All Azure deployments should follow this workflow:

1. **Connect to Deployment VM**
   ```bash
   ssh ubuntu-deploy
   ```

2. **Login with Managed Identity**
   ```bash
   az login --identity
   az account show
   ```

3. **Create Terraform Configuration**
   ```bash
   mkdir -p /opt/terraform/my-project
   cd /opt/terraform/my-project
   # Create providers.tf, main.tf, variables.tf, outputs.tf
   ```

4. **Deploy**
   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

### Terraform Provider Template

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }
}

provider "azurerm" {
  features {}
  use_msi         = true
  subscription_id = "2212d587-1bad-4013-b605-b421b1f83c30"
}
```

### Cost Management

| Resource | Estimated Monthly Cost |
|----------|------------------------|
| ubuntu-deploy-vm (D2s_v3) | ~$70 USD |
| ans-tf-vm01 (stopped when not in use) | ~$0 (stopped) |
| Log Analytics (90-day retention) | ~$2.30/GB ingested |
| NAT Gateway | ~$32 USD + data processing |
| Sentinel | Free tier (first 10GB/day) |

---

## Chapter 25: Azure Hybrid Lab (Active Directory)

### Enterprise Active Directory Simulation

The Azure Hybrid Lab is a complete enterprise Active Directory environment spanning both on-premises infrastructure (Proxmox) and Azure cloud. This hybrid architecture provides hands-on experience with enterprise identity management, site-to-site VPN, hybrid identity with Entra ID Connect, and multi-site Active Directory replication.

Unlike simple cloud-only deployments, this lab simulates a real enterprise scenario where on-premises domain controllers must coexist and replicate with cloud-based infrastructure—exactly what you'd find in organizations migrating to or integrating with cloud services.

### Why Build a Hybrid Lab?

Building a hybrid Active Directory environment teaches skills that are invaluable in enterprise IT:

1. **Multi-Site AD Replication**: Understanding how domain controllers communicate across WAN links
2. **Site-to-Site VPN**: Configuring IPsec tunnels between on-premises and cloud
3. **Hybrid Identity**: Synchronizing identities between on-premises AD and Entra ID
4. **Enterprise Architecture**: Implementing Microsoft's tiered administration model
5. **Infrastructure as Code**: Automating Windows deployments with Packer and Terraform

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AZURE HYBRID LAB                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ON-PREMISES (Proxmox node03)                    AZURE                          │
│  ┌─────────────────────────────────┐              ┌──────────────────────────┐  │
│  │  VLAN 80: 192.168.80.0/24       │              │  VNet: 10.10.4.0/24      │  │
│  │                                  │              │                          │  │
│  │  DC01, DC02 (Domain Controllers)│    VPN      │  AZDC01, AZDC02          │  │
│  │  FS01, FS02 (File Servers)      │ ◄────────► │  AZRODC01, AZRODC02      │  │
│  │  SQL01 (SQL Server)             │   IPsec    │  (Azure DCs)             │  │
│  │  AADCON01 (Entra Connect)       │              │                          │  │
│  │  AADPP01/02 (Password Proxy)    │              └──────────────────────────┘  │
│  │  IIS01/02 (Web Servers)         │                                            │
│  │  CLIENT01/02 (Workstations)     │                                            │
│  └─────────────────────────────────┘                                            │
│                                                                                  │
│  Deployment: Packer Template → Terraform Clone → Ansible Configuration          │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

The architecture reflects real enterprise deployments:
- **On-premises** runs the primary domain controllers and member servers
- **Azure** hosts additional DCs for cloud workloads and disaster recovery
- **Site-to-Site VPN** connects both environments for AD replication

### Domain Configuration

| Property | Value |
|----------|-------|
| **Domain Name** | azurelab.local |
| **NetBIOS** | AZURELAB |
| **Forest Level** | Windows Server 2016 |
| **On-Premises Network** | 192.168.80.0/24 (VLAN 80) |
| **Azure VNet** | 10.10.4.0/24 |

### On-Premises Infrastructure (Proxmox)

The on-premises component consists of 12 Windows Server 2022 VMs deployed to Proxmox node03. These VMs are created from a Packer-built template, ensuring consistency and enabling rapid redeployment.

| VM | VMID | IP Address | Role | Resources |
|----|------|------------|------|-----------|
| **DC01** | 300 | 192.168.80.2 | Primary Domain Controller | 2 cores, 4 GB |
| **DC02** | 301 | 192.168.80.3 | Secondary Domain Controller | 2 cores, 4 GB |
| **FS01** | 302 | 192.168.80.4 | File Server | 2 cores, 2 GB |
| **FS02** | 303 | 192.168.80.5 | File Server | 2 cores, 2 GB |
| **SQL01** | 304 | 192.168.80.6 | SQL Server | 4 cores, 8 GB |
| **AADCON01** | 305 | 192.168.80.7 | Entra ID Connect | 2 cores, 4 GB |
| **AADPP01** | 306 | 192.168.80.8 | Password Protection Proxy | 2 cores, 2 GB |
| **AADPP02** | 307 | 192.168.80.9 | Password Protection Proxy | 2 cores, 2 GB |
| **IIS01** | 310 | 192.168.80.10 | Web Server | 2 cores, 2 GB |
| **IIS02** | 311 | 192.168.80.11 | Web Server | 2 cores, 2 GB |
| **CLIENT01** | 308 | 192.168.80.12 | Domain Workstation | 2 cores, 2 GB |
| **CLIENT02** | 309 | 192.168.80.13 | Domain Workstation | 2 cores, 2 GB |

**Total Resources**: 24 cores, 38 GB RAM, 720 GB storage

### Azure Domain Controllers

| Server | IP Address | Role |
|--------|------------|------|
| **AZDC01** | 10.10.4.4 | Azure Primary DC |
| **AZDC02** | 10.10.4.5 | Azure Secondary DC |
| **AZRODC01** | 10.10.4.6 | Azure Read-Only DC |
| **AZRODC02** | 10.10.4.7 | Azure Read-Only DC |

---

### Building the Windows Template with Packer

#### The Challenge of Windows Automation

Deploying Windows VMs in a homelab traditionally means clicking through installation wizards, configuring settings manually, and hoping you remember all the steps next time. This approach doesn't scale and makes disaster recovery painful.

Packer solves this by creating **golden images**—pre-configured VM templates that can be cloned instantly. For Windows, this requires:

1. **Unattended Installation**: Windows must install without human interaction
2. **Driver Injection**: VirtIO drivers must be loaded during installation (not after)
3. **Remote Management**: WinRM must be enabled for Packer and Ansible
4. **Sysprep**: The image must be generalized for cloning

#### How Packer Works with Windows

The Packer build process for Windows on Proxmox follows this flow:

```
1. Create VM      → Packer creates VM via Proxmox API
2. Attach ISOs    → Windows ISO + VirtIO drivers ISO
3. Boot           → VM boots from Windows ISO
4. Autounattend   → Windows reads autounattend.xml from floppy/HTTP
5. Installation   → Windows installs unattended with VirtIO drivers
6. First Boot     → Auto-logon, WinRM enabled via FirstLogonCommands
7. Provisioning   → Packer connects via WinRM, runs PowerShell scripts
8. Sysprep        → Image generalized for cloning
9. Template       → Packer converts VM to template
```

#### Key Files in the Packer Configuration

**windows-server-2022.pkr.hcl** - This is the main Packer template. It defines:
- Proxmox connection settings (API URL, token, node)
- VM hardware configuration (UEFI, VirtIO SCSI, 60GB disk)
- Network settings (VirtIO NIC on VLAN 80)
- WinRM communicator settings for connecting to Windows
- Provisioning scripts to run after installation

**autounattend.xml** - The Windows unattended answer file. This XML file tells Windows Setup:
- How to partition the disk (EFI partition, MSR, primary partition)
- Which Windows edition to install
- Administrator password
- Where to find VirtIO drivers (on the attached ISO)
- What commands to run at first logon (enable WinRM)

**sysprep-unattend.xml** - The answer file used after cloning. When a cloned VM boots:
- Sysprep runs using this answer file
- OOBE screens are skipped
- Administrator auto-logon is configured
- WinRM is re-enabled (Sysprep disables it)

#### The Idempotent WinRM Fix

One of the most frustrating issues when building Windows templates is WinRM connection drops. The problem: `Enable-PSRemoting` internally restarts the WinRM service, which terminates Packer's connection mid-script.

The solution is to make the script **idempotent**—check if WinRM is already configured before trying to enable it:

```powershell
# Check if PS Remoting is already enabled
$remotingEnabled = $false
try {
    $winrmService = Get-Service WinRM -ErrorAction Stop
    $listener = Get-WSManInstance -ResourceURI winrm/config/listener `
        -SelectorSet @{Address="*";Transport="HTTP"} -ErrorAction SilentlyContinue
    if ($winrmService.Status -eq 'Running' -and $listener) {
        $remotingEnabled = $true
        Write-Host "PS Remoting already enabled, skipping" -ForegroundColor Green
    }
} catch {
    Write-Host "WinRM not configured, will enable..." -ForegroundColor Yellow
}

# Only enable if not already configured
if (-not $remotingEnabled) {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
}
```

This simple check prevents the service restart that was causing Packer builds to fail.

#### Building the Template

```bash
# From the Ansible controller
cd ~/azure-hybrid-lab/packer/windows-server-2022-proxmox

# Initialize Packer plugins
packer init .

# Validate configuration
packer validate -var-file="variables.pkrvars.hcl" .

# Build the template (~7 minutes)
packer build -var-file="variables.pkrvars.hcl" .
```

The build takes about 7 minutes and creates template 9022 on node03.

---

### Deploying VMs with Terraform

#### Why Terraform for VM Deployment?

Once you have a template, you could manually clone it 12 times through the Proxmox UI. But that approach has problems:
- **Time-consuming**: Each clone requires multiple clicks and waits
- **Error-prone**: Easy to misconfigure a single VM
- **Not reproducible**: No record of exactly what was deployed
- **Hard to modify**: Changing all VMs requires manual updates

Terraform solves these problems by defining infrastructure as code. You describe what you want, and Terraform makes it happen.

#### The Terraform Configuration

The `bpg/proxmox` provider enables Terraform to manage Proxmox resources. The configuration uses `for_each` to create multiple VMs from a single resource block:

```hcl
resource "proxmox_virtual_environment_vm" "windows_vm_from_template" {
  for_each = var.use_template ? local.all_vms : {}

  name        = each.key          # DC01, DC02, etc.
  node_name   = each.value.node   # node03
  vm_id       = each.value.vmid   # 300, 301, etc.

  clone {
    vm_id = var.vm_template_id    # 9022
    full  = true                  # Full clone, not linked
  }

  cpu {
    cores = lookup(local.vm_hardware, each.key, { cores = 2 }).cores
  }

  memory {
    dedicated = lookup(local.vm_hardware, each.key, { memory = 2048 }).memory
  }
}
```

The `lookup` function allows customizing resources per VM—SQL01 gets 4 cores and 8GB RAM, while file servers get the defaults.

#### Deployment Process

```bash
# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Deploy all 12 VMs (~30 minutes)
terraform apply -auto-approve
```

Terraform clones all 12 VMs in parallel. Each 60GB disk clone takes 2-3 minutes, but since they run concurrently, the total deployment time is about 30 minutes.

#### What Happens During Deployment

1. **Terraform connects** to Proxmox API
2. **Clone operations** start for all 12 VMs simultaneously
3. **Disk copy** completes for each VM (60GB each)
4. **VM configuration** applied (CPU, memory, network)
5. **VMs start** and boot from cloned disk
6. **Sysprep runs** on first boot, reading sysprep-unattend.xml
7. **OOBE skipped**, Administrator auto-logon occurs
8. **WinRM enabled** via FirstLogonCommands
9. **VMs ready** for Ansible configuration

---

### Enterprise Tiering Model

The Active Directory implements Microsoft's Enterprise Access Model with three tiers:

```
DC=azurelab,DC=local
├── OU=Tier 0 (Domain Controllers, Privileged Access)
│   ├── OU=Admin Accounts
│   ├── OU=Admin Groups
│   ├── OU=Admin Workstations
│   ├── OU=Service Accounts
│   └── OU=Servers
├── OU=Tier 1 (Server Administration)
│   ├── OU=Admin Accounts
│   ├── OU=Admin Groups
│   ├── OU=Service Accounts
│   └── OU=Servers
│       ├── OU=Application Servers
│       ├── OU=Database Servers
│       ├── OU=Web Servers
│       └── OU=File Servers
├── OU=Tier 2 (Workstation Administration)
│   ├── OU=Admin Accounts
│   ├── OU=Admin Groups
│   ├── OU=Service Accounts
│   └── OU=Workstations
└── OU=Corporate (Standard Users)
    ├── OU=Users
    ├── OU=Groups
    └── OU=Departments (IT, Finance, HR, Sales, etc.)
```

### Security Groups

| Tier | Key Groups |
|------|------------|
| **Tier 0** | T0-Domain-Admins, T0-Enterprise-Admins, T0-Schema-Admins, T0-DC-Admins |
| **Tier 1** | T1-Server-Admins, T1-SQL-Admins, T1-Web-Admins, T1-App-Admins |
| **Tier 2** | T2-Workstation-Admins, T2-Helpdesk-L1, T2-Helpdesk-L2 |
| **Corporate** | All-Employees, Dept-IT, Dept-Finance, Dept-HR, VPN-Users |

### Access Methods

**RDP Access:**
```bash
# On-premises VM
mstsc /v:192.168.80.2

# Azure DC
mstsc /v:10.10.4.4

# Credentials
Username: Administrator (local) or AZURELAB\Administrator (domain)
```

**PowerShell Remoting:**
```powershell
$cred = Get-Credential -UserName "AZURELAB\Administrator"
Enter-PSSession -ComputerName 192.168.80.2 -Credential $cred
```

### Common Administrative Tasks

```powershell
# Check AD Replication
repadmin /replsummary
repadmin /showrepl

# Check DC Health
dcdiag /v

# List All Domain Controllers
Get-ADDomainController -Filter * | Select Name, IPv4Address, Site

# Force Replication
repadmin /syncall /APed
```

### Troubleshooting the Build Process

| Issue | Cause | Solution |
|-------|-------|----------|
| WinRM timeout during Packer build | `Enable-PSRemoting` restarts WinRM | Make script idempotent |
| VirtIO disk not found | Missing drivers in autounattend.xml | Add driver paths to specialize pass |
| Packer scripts deleted | Windows Defender quarantine | Add temp folder exclusion |
| OOBE prompts after clone | Missing sysprep answer file | Copy sysprep-unattend.xml before sysprep |
| Terraform 401 error | Wrong API token format | Use `user@realm!tokenid=secret` format |
| Clone fails "config exists" | Partial clone from previous attempt | Remove partial VM with `qm destroy` |

### Costs (Azure Components)

| Resource | Monthly Cost |
|----------|--------------|
| 4x Standard_B2s VMs | ~$120 USD |
| Data Disks | ~$5 USD |
| VPN Gateway | ~$30 USD |
| **Total** | **~$155 USD/month** |

> **Tip**: Deallocate Azure VMs when not in use. On-premises VMs have no recurring cost beyond electricity.

---

## Chapter 26: Backup and Disaster Recovery

### The 3-2-1 Backup Strategy

Every serious homelab needs a solid backup strategy. The 3-2-1 rule states:
- **3** copies of your data
- **2** different storage media
- **1** offsite backup

### Proxmox Backup Server (PBS)

PBS provides enterprise-grade backup for all Proxmox VMs and containers. Unlike the built-in vzdump backup, PBS offers:

- **Deduplication**: Only stores unique data blocks, saving ~70% storage
- **Incremental Backups**: After initial full backup, only changes transfer
- **Encryption**: Optional client-side encryption for sensitive data
- **Verification**: Checksums detect bit-rot and corruption
- **Fast Restore**: Can mount backups directly without full restore
- **Web UI**: Easy management at port 8007

#### Why a Tiered Datastore Approach?

We deploy PBS with **two separate datastores** for optimal performance:

1. **SSD Datastore (daily)**: Fast NVMe storage for frequent backups and quick restores
2. **HDD Datastore (main)**: Large capacity for long-term archival backups

This tiered approach optimizes for both speed and capacity—daily backups restore quickly while archived backups maximize storage efficiency.

### PBS Deployment Guide

#### Architecture

```
node03 (192.168.20.22) - Proxmox Host
├── Physical Storage
│   ├── /dev/sda (Seagate 4TB HDD)
│   │   ├── Mounted at: /mnt/pbs-backup
│   │   └── Purpose: Weekly/monthly archival backups
│   │
│   └── /dev/nvme0n1 (Kingston 1TB NVMe)
│       ├── Mounted at: /mnt/pbs-ssd
│       └── Purpose: Daily backups (fast restore)
│
└── PBS LXC Container (VMID 100)
    ├── IP: 192.168.20.50
    ├── Web UI: https://192.168.20.50:8007
    │
    ├── /backup (bind mount → main datastore)
    └── /backup-ssd (bind mount → daily datastore)
```

#### Step 1: Prepare Physical Storage

First, prepare the disks on the Proxmox host:

```bash
# SSH to node03
ssh root@192.168.20.22

# Wipe and partition HDD for archival storage
wipefs -a /dev/sda
parted /dev/sda --script mklabel gpt
parted /dev/sda --script mkpart primary ext4 0% 100%
mkfs.ext4 -L pbs-backup /dev/sda1

# Wipe and partition NVMe for fast daily backups
wipefs -a /dev/nvme0n1
parted /dev/nvme0n1 --script mklabel gpt
parted /dev/nvme0n1 --script mkpart primary ext4 0% 100%
mkfs.ext4 -L pbs-ssd /dev/nvme0n1p1

# Mount the drives
mkdir -p /mnt/pbs-backup /mnt/pbs-ssd
mount /dev/sda1 /mnt/pbs-backup
mount /dev/nvme0n1p1 /mnt/pbs-ssd

# Make mounts persistent (add to fstab)
echo 'UUID=<your-hdd-uuid> /mnt/pbs-backup ext4 defaults 0 2' >> /etc/fstab
echo 'UUID=<your-nvme-uuid> /mnt/pbs-ssd ext4 defaults 0 2' >> /etc/fstab
```

> **Why ext4?** It's mature, stable, supports large files, and well-supported by PBS. For backup workloads, ext4's reliability outweighs the advanced features of btrfs or ZFS.

#### Step 2: Create PBS Container

Create an LXC container to run PBS:

```bash
# Download Debian template
pveam update
pveam download local debian-12-standard_12.12-1_amd64.tar.zst

# Create datastore directories
mkdir -p /mnt/pbs-backup/datastore
mkdir -p /mnt/pbs-ssd/datastore

# Create privileged LXC container (required for bind mounts)
pct create 100 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname pbs-server \
  --cores 2 --memory 4096 \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.20.50/24,gw=192.168.20.1 \
  --features nesting=1 \
  --unprivileged 0

# Add bind mounts for datastores
pct set 100 -mp0 /mnt/pbs-backup/datastore,mp=/backup
pct set 100 -mp1 /mnt/pbs-ssd/datastore,mp=/backup-ssd

pct start 100
```

#### Step 3: Install PBS

Inside the container, install Proxmox Backup Server:

```bash
pct exec 100 -- bash

# Add Proxmox repository
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg \
  -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
echo "deb http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription" \
  > /etc/apt/sources.list.d/pbs.list

# Install
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-backup-server
```

#### Step 4: Configure Datastores and Permissions

```bash
# Create datastores
proxmox-backup-manager datastore create main /backup
proxmox-backup-manager datastore create daily /backup-ssd

# Create API user and token for Proxmox VE integration
proxmox-backup-manager user create backup@pbs
proxmox-backup-manager user generate-token backup@pbs pve

# CRITICAL: Grant permissions (this is where most setups fail!)
proxmox-backup-manager acl update / Audit --auth-id backup@pbs!pve
proxmox-backup-manager acl update /datastore/main DatastoreAdmin --auth-id backup@pbs!pve
proxmox-backup-manager acl update /datastore/daily DatastoreAdmin --auth-id backup@pbs!pve
```

> **Common Mistake**: Forgetting the root-level Audit permission causes "Cannot find datastore" errors when adding PBS to Proxmox VE.

### PBS Architecture Diagram

```
+------------------+     +------------------+     +------------------+
|       PBS        |     |   PBS Exporter   |     |    Prometheus    |
| 192.168.20.50    |<--->| 192.168.40.13    |<--->| 192.168.40.13    |
| LXC 100 (node03) |     | Port 9101        |     | Port 9090        |
+------------------+     +------------------+     +------------------+
                                                         |
                                                         v
                                              +------------------+
                                              |     Grafana      |
                                              | PBS Dashboard    |
                                              +------------------+
```

#### PBS Server Configuration

| Property | Value |
|----------|-------|
| Host | 192.168.20.50 |
| Node | node03 |
| Web UI | https://192.168.20.50:8007 |
| Version | 3.4 |

#### Storage Datastores

| Datastore | Storage Type | Capacity | Purpose |
|-----------|-------------|----------|---------|
| `daily` | Kingston 1TB NVMe | ~1TB | Daily backups (fast restore) |
| `main` | Seagate 4TB HDD | ~4TB | Weekly/monthly backups |

### Backup Schedule

| Schedule | Datastore | Retention | Purpose |
|----------|-----------|-----------|---------|
| Daily (2 AM) | daily | 7 days | Quick recovery for recent changes |
| Weekly (Sunday) | main | 4 weeks | Medium-term point-in-time recovery |
| Monthly (1st) | main | 6 months | Long-term archival |

### NAS Backup Replication

PBS backups are replicated to Synology NAS for the offsite copy:

```bash
# Automated rsync job (runs daily at 2 AM)
rsync -avz --delete /backup-ssd/ /mnt/nas-backup/daily/
rsync -avz --delete /backup/ /mnt/nas-backup/main/
```

### PBS Monitoring

#### Grafana Dashboard

| Property | Value |
|----------|-------|
| Dashboard | PBS Backup Status |
| UID | `pbs-backup-status` |
| URL | https://grafana.hrmsmrflrii.xyz/d/pbs-backup-status |

**Dashboard Sections:**
1. **PBS Status Overview** - Connection status, version, uptime
2. **Datastore Storage** - Pie charts and gauges per datastore
3. **Backup Snapshots** - Snapshot counts for daily and main
4. **Storage Usage Over Time** - Time series graphs
5. **PBS Host Metrics** - CPU, memory, and load graphs

#### Available Metrics

| Metric | Description |
|--------|-------------|
| `pbs_up` | 1 if exporter can connect to PBS |
| `pbs_size` | Total size of datastore in bytes |
| `pbs_used` | Used bytes in datastore |
| `pbs_snapshot_count` | Number of backup snapshots |
| `pbs_host_cpu_usage` | CPU usage (0-1) |
| `pbs_host_memory_used` | Used memory bytes |

### SMART Drive Health Monitoring

A custom API monitors drive health for the PBS storage drives:

| Property | Value |
|----------|-------|
| Host | node03 (192.168.20.22) |
| Port | 9101 |
| Endpoint | http://192.168.20.22:9101/health |

**Monitored Drives:**
| Drive | Device | Datastore |
|-------|--------|-----------|
| Seagate 4TB HDD | /dev/sda | main |
| Kingston 1TB NVMe | /dev/nvme1n1 | daily |

### Disaster Recovery Procedures

#### Complete VM Restore

1. **Access PBS Web UI** - https://192.168.20.50:8007
2. **Navigate to Datastore** - Select `daily` or `main`
3. **Find VM Backup** - Browse by VMID
4. **Restore** - Click "Restore" and select target node
5. **Verify** - Start VM and verify functionality

#### File-Level Recovery

```bash
# On Proxmox node
proxmox-backup-client restore vm/100 /path/to/restore
```

#### Bare Metal Recovery

For complete node failure:
1. Reinstall Proxmox VE on new hardware
2. Configure network and storage
3. Add PBS storage in Proxmox Datacenter
4. Restore VMs from PBS

### Verification Checklist

| Check | Frequency | Command |
|-------|-----------|---------|
| Backup job status | Daily | PBS Web UI or `pbs_up` metric |
| Datastore space | Weekly | `pbs_used / pbs_size * 100` |
| Drive health | Weekly | SMART Health API |
| NAS replication | Weekly | Check sync status in Glance |
| Test restore | Monthly | Restore random VM to verify |

### Application-Level Backups: Immich Photo Management

While PBS provides excellent VM-level backups, some applications benefit from **application-level backups** that capture the database state independently. Immich is a perfect example—its PostgreSQL database contains all photo metadata, albums, face recognition data, and user information.

#### Why Application-Level Backup for Immich?

| Advantage | Explanation |
|-----------|-------------|
| **Faster Recovery** | Database restore takes minutes vs. full VM restore |
| **Cross-Version Portable** | Can restore to different Immich versions |
| **Granular Recovery** | Fix specific data issues without full restore |
| **Independent of VM State** | DB dump works even if VM is damaged |

#### Immich Backup Architecture

```
IMMICH BACKUP STRATEGY
======================

┌─────────────────────────────────────────────────────────────────┐
│                    Immich VM (192.168.40.22)                    │
├─────────────────────────────────────────────────────────────────┤
│  LOCAL STORAGE              NFS STORAGE (Synology NAS)          │
│  /opt/immich/               /mnt/immich-uploads/                │
│  ├── docker-compose.yml     ├── upload/   (photos)              │
│  ├── .secrets               ├── thumbs/                         │
│  ├── postgres/  ◄─ DB       ├── library/                        │
│  └── model-cache/           └── db-backups/ ◄─ DB dumps         │
└─────────────────────────────────────────────────────────────────┘
              │                              │
              ▼                              ▼
┌────────────────────────┐    ┌──────────────────────────────────┐
│   PBS VM-Level Backup  │    │   Application-Level DB Backup    │
│   Daily @ 03:00        │    │   Daily @ 02:30                  │
│   pbs-daily (SSD)      │    │   NAS /db-backups/               │
│   Retention: 7 days    │    │   Retention: 7 days              │
└────────────────────────┘    └──────────────────────────────────┘
```

The backup timing is intentional: the database backup runs at 02:30, **before** PBS captures the VM at 03:00. This ensures PBS backs up a consistent state that includes the latest database dump.

#### Setting Up Immich Database Backup

```bash
# From Ansible controller
ssh hermes-admin@192.168.20.30
cd ~/ansible
ansible-playbook playbooks/backup/configure-immich-backup.yml -v
```

This playbook creates:
- `/opt/immich/backup-db.sh` - Automated backup script
- `/opt/immich/restore-db.sh` - Interactive restore script
- Cron job running at 02:30 daily

#### The Backup Script

The backup script performs a full PostgreSQL dump using `pg_dumpall`, which captures:
- All databases (including Immich's main database)
- User accounts and permissions
- Database schemas and data

```bash
# What the backup script does:
1. Check if PostgreSQL container is running
2. Execute pg_dumpall inside the container
3. Compress output with gzip
4. Store in /mnt/immich-uploads/db-backups/
5. Clean up backups older than 7 days
```

#### Restoring Immich from Database Backup

When things go wrong (corrupted albums, missing face data, etc.), the restore process is straightforward:

```bash
# SSH to Immich VM
ssh hermes-admin@192.168.40.22

# List available backups
sudo /opt/immich/restore-db.sh

# Output shows:
# Available Immich database backups:
# ==================================
# immich-db-20260114_023000.sql.gz    45M    2026-01-14 02:30:00
# immich-db-20260113_023000.sql.gz    44M    2026-01-13 02:30:00
# ...

# Restore from yesterday
sudo /opt/immich/restore-db.sh immich-db-20260113_023000.sql.gz
```

The restore script will:
1. Stop Immich services (keep PostgreSQL running)
2. Drop and recreate the database
3. Import the backup
4. Restart Immich services
5. Verify everything is working

#### Complete Disaster Recovery for Immich

For a complete Immich recovery (VM completely lost):

**Step 1: Restore VM from PBS**
```bash
# From Proxmox node
ssh root@192.168.20.20

# Restore Immich VM
qmrestore pbs-daily:backup/vm/115/latest 115 --storage local-lvm
qm start 115
```

**Step 2: Verify NFS Mounts**
```bash
# After VM boots
ssh hermes-admin@192.168.40.22
mount | grep immich

# If NFS failed, remount
sudo mount -a
```

**Step 3: Verify or Restore Database**
```bash
# Check if Immich works
curl -s http://localhost:2283/api/server/ping

# If database issues, restore from application backup
sudo /opt/immich/restore-db.sh
```

#### Photo Storage Backup (The Third Copy)

Remember the 3-2-1 rule! Photos stored on the NAS need their own offsite backup:

| Solution | Cost | Setup |
|----------|------|-------|
| **Synology Hyper Backup to B2** | ~$5/TB/month | DSM → Hyper Backup → Backblaze B2 |
| **Synology C2 Storage** | Variable | Native Synology cloud |
| **rsync to remote server** | Hosting cost | Custom script |

For most homelabs, **Backblaze B2** via Hyper Backup offers the best value—cheap, reliable, and easy to configure.

#### Recovery Time Summary

| Scenario | Recovery Method | Estimated Time |
|----------|-----------------|----------------|
| VM crash, data intact | Restart VM | 1-2 minutes |
| Corrupted database | Restore from db-backup | 5-10 minutes |
| Complete VM loss | PBS restore + verify | 15-20 minutes |
| VM + DB corruption | PBS restore + db-backup restore | 20-30 minutes |
| NAS failure | PBS restore + Hyper Backup restore | 2-4 hours |

---

## Chapter 27: Glance Dashboard

### Centralized Homelab Dashboard

Glance is a self-hosted dashboard that provides a central view of all homelab services, monitoring, and media statistics. It serves as the single pane of glass for the entire infrastructure.

### Quick Reference

| Item | Value |
|------|-------|
| **Dashboard URL** | https://glance.hrmsmrflrii.xyz |
| **Internal URL** | http://192.168.40.12:8080 |
| **Config Location** | `/opt/glance/config/glance.yml` |
| **CSS Location** | `/opt/glance/assets/custom-themes.css` |
| **Host** | LXC 200 (lxc-glance) on 192.168.40.12 |

### Dashboard Architecture

```
Glance Dashboard (Port 8080)
        │
        ├── Home Page
        │   ├── Life Progress Widget (API: 192.168.40.13:5051)
        │   ├── Service Health Monitors
        │   ├── GitHub Contributions
        │   └── Markets & News RSS
        │
        ├── Compute Tab
        │   ├── Proxmox Cluster Health (Grafana iframe)
        │   └── Container Monitoring (Grafana iframe)
        │
        ├── Storage Tab
        │   └── Synology NAS Dashboard (Grafana iframe)
        │
        ├── Network Tab
        │   ├── Network Utilization (Grafana iframe)
        │   └── Omada Network (Grafana iframe)
        │
        ├── Backup Tab
        │   ├── PBS Backup Status (Grafana iframe)
        │   ├── Drive Health (API: 192.168.20.22:9101)
        │   └── NAS Backup Status (API: 192.168.40.13:9102)
        │
        ├── Media Tab
        │   ├── Media Stats Grid (API: 192.168.40.13:5054)
        │   └── Recent Movies & RSS Feeds
        │
        ├── Web Tab
        │   └── Tech News Aggregator (RSS)
        │
        ├── Reddit Tab
        │   └── Reddit Feed Manager (API: 192.168.40.13:5053)
        │
        └── Sports Tab
            └── NBA Stats & Fantasy (API: 192.168.40.13:5060)
```

### Tab Structure

| Tab | Contents | Protected |
|-----|----------|-----------|
| **Home** | Clock, Weather, Bookmarks, Life Progress, Service Health, Markets | Yes |
| **Compute** | Proxmox Cluster Dashboard, Container Monitoring Dashboard | Yes |
| **Storage** | Synology NAS Storage Dashboard | Yes |
| **Network** | Network Utilization, Omada Network Dashboard, Speedtest | Yes |
| **Backup** | PBS Status, Drive Health, NAS Backup Sync | Yes |
| **Media** | Media Stats Grid, Recent Movies, RSS Feeds | Yes |
| **Web** | Tech News RSS, AI/ML News, Crypto, Stocks | No |
| **Reddit** | Dynamic Reddit Feed (via Reddit Manager API) | No |
| **Sports** | NBA Games, Standings, Yahoo Fantasy League | Yes |

### Custom APIs Powering Glance

| API | Port | Purpose |
|-----|------|---------|
| Media Stats API | 5054 | Radarr/Sonarr statistics for grid widget |
| Life Progress API | 5051 | Life progress percentage calculation |
| Reddit Manager | 5053 | Dynamic subreddit feed aggregation |
| NBA Stats API | 5060 | NBA scores, standings, fantasy data |
| SMART Health API | 9101 | PBS drive health status |
| NAS Backup Status | 9102 | PBS-to-NAS sync status |

### Embedded Grafana Dashboards

| Dashboard | UID | Height | Tab |
|-----------|-----|--------|-----|
| Proxmox Cluster Health | `proxmox-cluster-health` | 1100px | Compute |
| Container Monitoring | `containers-modern` | 1400px | Compute |
| Container Status History | `container-status` | 1250px | Compute |
| Synology NAS Storage | `synology-nas-modern` | 1350px | Storage |
| Omada Network | `omada-network` | 2200px | Network |
| Network Utilization | `network-utilization` | 1100px | Network |
| PBS Backup Status | `pbs-backup-status` | 600px | Backup |

### Home Page Layout

```
┌──────────────────┬──────────────────────────────────────────┬──────────────────┐
│   LEFT (small)   │              CENTER (full)                │  RIGHT (small)   │
├──────────────────┼──────────────────────────────────────────┼──────────────────┤
│ Chess.com Stats  │ Life Progress Widget                      │ Crypto Markets   │
│ Clock            │ GitHub Contributions (green, dark mode)   │ Stock Markets    │
│ Weather          │ Proxmox Cluster Monitor (3 nodes)         │ Tech News RSS    │
│ Sun Times        │ Storage Monitor                           │                  │
│ Calendar         │ Core Services Monitor                     │                  │
│ Daily Note       │ Media Services Monitor                    │                  │
│ Infrastructure   │ Monitoring Stack Monitor                  │                  │
│ Services         │                                           │                  │
└──────────────────┴──────────────────────────────────────────┴──────────────────┘
```

### Media Stats Widget

The Media Stats widget displays Radarr and Sonarr statistics in a colorful 3x2 tile grid:

```
┌──────────────┬──────────────┬──────────────┐
│ WANTED       │ MOVIES       │ MOVIES       │
│ MOVIES       │ DOWNLOADING  │ DOWNLOADED   │
│ (amber)      │ (blue)       │ (green)      │
├──────────────┼──────────────┼──────────────┤
│ WANTED       │ EPISODES     │ EPISODES     │
│ EPISODES     │ DOWNLOADING  │ DOWNLOADED   │
│ (red)        │ (purple)     │ (cyan)       │
└──────────────┴──────────────┴──────────────┘
```

### Deployment

```bash
# Deploy/Update Glance via Ansible
cd ~/ansible
ansible-playbook glance/deploy-glance-dashboard.yml

# Restart Glance (Glance is on LXC)
ssh root@192.168.40.12 "cd /opt/glance && docker compose restart"

# View Glance config
ssh root@192.168.40.12 "cat /opt/glance/config/glance.yml"

# View Glance logs
ssh root@192.168.40.12 "docker logs glance"
```

### Full-Width Display Configuration

By default, Glance limits content width. To enable full-width:

1. **glance.yml** - Add document-width to theme:
```yaml
theme:
  document-width: 100%
```

2. **custom-themes.css** - Override the content bounds:
```css
.content-bounds {
  max-width: 100% !important;
  width: 100% !important;
  margin-left: 10px !important;
  margin-right: 10px !important;
}
```

---

# Appendices

## Appendix A: Complete IP Map

### VLAN 20 - Infrastructure (192.168.20.0/24)

| IP | Hostname | Purpose |
|----|----------|---------|
| .1 | Gateway | Router |
| .20 | pve-node01 | Proxmox Node 1 |
| .21 | pve-node02 | Proxmox Node 2 |
| .22 | pve-node03 | Proxmox Node 3 |
| .30 | ansible-controller01 | Ansible |
| .31 | synology | NAS |
| .32 | k8s-controller01 | K8s Control Plane |
| .33 | k8s-controller02 | K8s Control Plane |
| .34 | k8s-controller03 | K8s Control Plane |
| .40 | k8s-worker01 | K8s Worker |
| .41 | k8s-worker02 | K8s Worker |
| .42 | k8s-worker03 | K8s Worker |
| .43 | k8s-worker04 | K8s Worker |
| .44 | k8s-worker05 | K8s Worker |
| .45 | k8s-worker06 | K8s Worker |

### VLAN 40 - Services (192.168.40.0/24)

| IP | Hostname | Services |
|----|----------|----------|
| .1 | Gateway | Router |
| .5 | linux-syslog-server01 | Centralized logging |
| .10 | docker-vm-core-utilities01 | Glance, n8n, Monitoring, Observability |
| .11 | docker-vm-media01 | Jellyfin, Arr stack |
| .20 | traefik-vm01 | Reverse proxy |
| .21 | authentik-vm01 | SSO |
| .22 | immich-vm01 | Photo management |
| .23 | gitlab-vm01 | DevOps platform |
| .24 | gitlab-runner-vm01 | CI/CD runner |

---

## Appendix B: Service URLs

### Infrastructure

| Service | Internal | External |
|---------|----------|----------|
| Proxmox | https://192.168.20.21:8006 | https://proxmox.hrmsmrflrii.xyz |
| Traefik Dashboard | http://192.168.40.20:8080 | https://traefik.hrmsmrflrii.xyz |
| Authentik | http://192.168.40.21:9000 | https://auth.hrmsmrflrii.xyz |

### Media

| Service | Internal | External |
|---------|----------|----------|
| Jellyfin | http://192.168.40.11:8096 | https://jellyfin.hrmsmrflrii.xyz |
| Radarr | http://192.168.40.11:7878 | https://radarr.hrmsmrflrii.xyz |
| Sonarr | http://192.168.40.11:8989 | https://sonarr.hrmsmrflrii.xyz |
| Lidarr | http://192.168.40.11:8686 | https://lidarr.hrmsmrflrii.xyz |
| Prowlarr | http://192.168.40.11:9696 | https://prowlarr.hrmsmrflrii.xyz |
| Bazarr | http://192.168.40.11:6767 | https://bazarr.hrmsmrflrii.xyz |
| Jellyseerr | http://192.168.40.11:5056 | https://jellyseerr.hrmsmrflrii.xyz |
| Deluge | http://192.168.40.11:8112 | https://deluge.hrmsmrflrii.xyz |
| SABnzbd | http://192.168.40.11:8081 | https://sabnzbd.hrmsmrflrii.xyz |

### Monitoring

| Service | Internal | External |
|---------|----------|----------|
| Uptime Kuma | http://192.168.40.13:3001 | https://uptime.hrmsmrflrii.xyz |
| Prometheus | http://192.168.40.13:9090 | https://prometheus.hrmsmrflrii.xyz |
| Grafana | http://192.168.40.13:3030 | https://grafana.hrmsmrflrii.xyz |
| Jaeger | http://192.168.40.13:16686 | https://jaeger.hrmsmrflrii.xyz |

### Productivity

| Service | Internal | External |
|---------|----------|----------|
| Immich | http://192.168.40.22:2283 | https://photos.hrmsmrflrii.xyz |
| GitLab | http://192.168.40.23:80 | https://gitlab.hrmsmrflrii.xyz |
| n8n | http://192.168.40.13:5678 | https://n8n.hrmsmrflrii.xyz |
| Glance | http://192.168.40.12:8080 | https://glance.hrmsmrflrii.xyz |

---

## Appendix C: Configuration Templates

### Docker Compose Service Template

```yaml
version: "3.8"

services:
  service-name:
    image: organization/image:latest
    container_name: service-name
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /opt/service-name/config:/config
      - /opt/service-name/data:/data
    environment:
      - TZ=Asia/Manila
      - PUID=1000
      - PGID=1000
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - default

networks:
  default:
    driver: bridge
```

### Traefik Service Route Template

```yaml
http:
  routers:
    service-name:
      rule: "Host(`service.hrmsmrflrii.xyz`)"
      service: service-name
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare
      middlewares:
        - authentik-auth  # Remove if no SSO needed

  services:
    service-name:
      loadBalancer:
        servers:
          - url: "http://192.168.40.XX:PORT"
```

### Ansible Service Deployment Template

```yaml
---
- name: Deploy Service Name
  hosts: target_host
  become: yes

  vars:
    service_name: service-name
    service_port: 8080
    service_dir: /opt/{{ service_name }}

  tasks:
    - name: Create service directory
      file:
        path: "{{ service_dir }}"
        state: directory
        owner: hermes-admin
        group: hermes-admin

    - name: Copy docker-compose file
      template:
        src: docker-compose.yml.j2
        dest: "{{ service_dir }}/docker-compose.yml"

    - name: Copy environment file
      template:
        src: env.j2
        dest: "{{ service_dir }}/.env"
        mode: '0600'

    - name: Start service
      community.docker.docker_compose:
        project_src: "{{ service_dir }}"
        state: present
```

---

## Appendix D: Docker Services Reference

A complete inventory of all Docker containers running in the homelab.

### Host Summary

| Host | IP | Purpose | Containers |
|------|-----|---------|------------|
| docker-vm-core-utilities01 | 192.168.40.13 | Monitoring, Utilities | 21 |
| docker-lxc-media | 192.168.40.11 | Media Stack | 12 |

### Core Utilities (192.168.40.13)

**Monitoring:**

| Service | Port | Purpose |
|---------|------|---------|
| Grafana | 3030 | Dashboards |
| Prometheus | 9090 | Metrics |
| Uptime Kuma | 3001 | Uptime monitoring |
| Jaeger | 16686 | Distributed tracing |
| cAdvisor | 8081 | Container metrics |

**Exporters:**

| Exporter | Port | Purpose |
|----------|------|---------|
| PVE Exporter | 9221 | Proxmox metrics |
| PBS Exporter | 9101 | Backup metrics |
| SNMP Exporter | 9116 | Network SNMP |

**Utilities:**

| Service | Port | Purpose |
|---------|------|---------|
| Paperless-ngx | 8000 | Document management |
| n8n | (Traefik) | Workflow automation |
| Speedtest Tracker | 3000 | Internet speed |
| Karakeep | 3005 | Bookmarks |

**Custom Apps:**

| Service | Port | Purpose |
|---------|------|---------|
| Sentinel Bot | 5050 | Discord notifications |
| Life Progress API | 5051 | Life tracking |
| NAS Backup Status | 9102 | Backup monitoring |
| Homelab Chronicle | 3010 | Activity logging |
| Wizarr | 5690 | Media invitations |
| Tracearr | 3002 | Download monitoring |

### Media Host (192.168.40.11)

**Media Server:**

| Service | Port | Purpose |
|---------|------|---------|
| Jellyfin | 8096 | Media streaming |

**Content Management:**

| Service | Port | Purpose |
|---------|------|---------|
| Radarr | 7878 | Movies |
| Sonarr | 8989 | TV Shows |
| Lidarr | 8686 | Music |
| Prowlarr | 9696 | Indexers |
| Bazarr | 6767 | Subtitles |

**Request Management:**

| Service | Port | Purpose |
|---------|------|---------|
| Overseerr | 5055 | Plex requests |
| Jellyseerr | 5056 | Jellyfin requests |

**Downloads:**

| Service | Port | Purpose |
|---------|------|---------|
| Deluge | 8112 | BitTorrent |
| SABnzbd | 8081 | Usenet |

**Automation:**

| Service | Port | Purpose |
|---------|------|---------|
| Autobrr | 7474 | IRC automation |
| Tdarr | 8265 | Transcoding |

### Quick Commands

```bash
# List all containers
ssh hermes-admin@192.168.40.13 "docker ps"
ssh hermes-admin@192.168.40.11 "docker ps"

# View logs
docker logs <container> --tail 100

# Restart
docker restart <container>

# Update all
docker compose pull && docker compose up -d
```

---

# Conclusion

Building a homelab is a journey, not a destination. What started as a simple photo server evolved into a comprehensive infrastructure that taught me more about system administration, networking, and automation than any formal education could.

The key takeaways:

1. **Start with a problem to solve** - Don't build infrastructure for its own sake
2. **Automate from day one** - Manual doesn't scale
3. **Document everything** - You will forget
4. **Embrace failure** - Every mistake is a lesson
5. **Keep it simple** - Complexity is the enemy of reliability

Whether you're storing family photos or learning Kubernetes, a homelab is the ultimate learning environment. You own it, you break it, you fix it - and in the process, you become a better engineer.

Welcome to homelabbing.

---

*This guide is based on real-world experience building and operating a production-grade homelab. All configurations, commands, and architectures have been tested in practice.*

*Last updated: January 2026*
