<div align="center">

<br><br><br><br>

# ═══════════════════════════════════════════════

# HERMES' HOMELAB PROJECT

# ═══════════════════════════════════════════════

<br><br>

### Infrastructure Technical Manual

<br><br><br>

**Started:** December 2024

**Documentation Version:** 2.2 | January 2026

<br><br><br><br>

---

**Author**

### Hermes Miraflor II

*with the assistance of*

### Claude Code

<br><br><br><br><br><br><br><br><br><br>

---

*"The best time to plant a tree was 20 years ago.*
*The second best time is now."*

— Chinese Proverb

<br><br>

</div>

<div style="page-break-after: always;"></div>

---

# Document History

This page tracks all major revisions made to this technical manual.

| Version | Date | Author | Changes |
|:-------:|:----:|:------:|---------|
| **2.2** | January 11, 2026 | Hermes + Claude | Added node03 (Ryzen 9 5900XT desktop) to cluster documentation, comprehensive power management section for node03 including CPU governor, AMD P-State, C-states, SATA/PCIe power management, systemd services |
| **2.1** | January 8, 2026 | Hermes + Claude | Added Storage Architecture (Section 8), Kubernetes Cluster with installation guide (Section 9), Observability Stack (Section 10), Watchtower Updates (Section 11), Sentinel Discord Bot (Section 12), SSH Configuration (Appendix D), WiFi SSID mapping, fixed ASCII diagram rendering |
| **2.0** | January 7, 2026 | Hermes + Claude | Complete rewrite with comprehensive technical documentation. Added Prologue story, expanded all sections with beginner-friendly explanations, added deployment workflows, Authentik integration |
| **1.0** | December 2024 | Hermes | Initial documentation covering basic Proxmox setup and network architecture |

---

## About This Manual

This manual serves as the complete technical reference for the Hermes Homelab—a passion project that grew from a simple NAS purchase into a full enterprise-grade infrastructure.

**What You'll Find Here:**
- Detailed explanations suitable for beginners and experts alike
- Step-by-step guides for every major component
- Architecture diagrams and data flows
- Troubleshooting procedures
- Best practices learned through real-world experience

**Living Document:** This manual is continuously updated as the infrastructure evolves. Each change is tracked in the version history above.

---

## Quick Reference

| Resource | Location |
|----------|----------|
| **GitHub Repository** | [Proxmox-TerraformDeployments](https://github.com/herms14/Proxmox-TerraformDeployments) |
| **Glance Dashboard** | https://glance.hrmsmrflrii.xyz |
| **Grafana Monitoring** | https://grafana.hrmsmrflrii.xyz |
| **Proxmox Web UI** | https://proxmox.hrmsmrflrii.xyz |

---

<div style="page-break-after: always;"></div>

# Homelab Infrastructure Technical Manual

> **Comprehensive Documentation for the Hermes Homelab & Azure Hybrid Environment**
>
> Version 2.1 | January 8, 2026

---

## Prologue: The Story Behind This Manual

### It Started With Sophia's Photos

In 2023, two things happened almost simultaneously. I traveled to Japan—exploring temples in Kyoto, watching the sun set over Mount Fuji, wandering through the neon-lit streets of Tokyo. I captured hundreds of photos and videos, moments I wanted to keep forever.

Around the same time, my daughter Sophia was growing up fast. Her first steps, her laughter, her tiny milestones—I was capturing everything. These weren't just files. They were irreplaceable memories.

Then Google Photos delivered the notification I'd been dreading: *"You've run out of storage. Upgrade to continue backing up your memories."*

That notification changed everything.

I did the math. If I kept paying monthly just to store my own memories, I would eventually spend enough to buy a NAS outright—and I would gain something the cloud could never give me: **real privacy and full control over my data**. My Japan trip photos, Sophia's milestones—these deserved to exist somewhere I truly owned.

So I bought a Synology NAS. Just to store photos. Just to save money.

*I had no idea what I was about to unleash.*

---

### The Escalation Trap

The NAS arrived, and within days it was running perfectly. Sophia's photos were safe, organized, and accessible from anywhere in our home. Mission accomplished.

But then I remembered an unused Raspberry Pi sitting in a drawer. *"What if I set up Pi-hole to block ads?"* One weekend project later, my entire household had cleaner, faster internet. Something in my brain flipped—once you optimize one part of your setup, your mind immediately starts looking for the next thing to improve.

With 10 TB of storage available, the next idea came naturally: *Why not self-host my media and stop paying for streaming subscriptions?* The state of streaming made the decision easy—shows vanishing without warning, prices increasing, content scattered across a dozen apps. I wanted a single place to organize the media I already owned.

That was the moment the homelab truly began.

A mini PC became a Docker host. Docker became Proxmox. One node became a cluster. The cluster needed proper networking. Proper networking needed VLANs. VLANs needed enterprise-grade switches. Enterprise switches needed a proper firewall. The firewall needed observability. Observability needed Prometheus. Prometheus needed Grafana. Grafana needed custom dashboards. Custom dashboards needed APIs. APIs needed CI/CD pipelines. Pipelines needed GitLab. GitLab needed... well, you get the idea.

The escalation never stopped.

---

### This Is My Passion. This Makes Me Happy.

Some people collect stamps. Some people restore cars. Some people tend gardens.

I build infrastructure.

**It's proof that passion, applied consistently, creates extraordinary things.**

Sophia's photos are still safe on that original NAS. But now they're backed up to Azure, replicated across nodes, monitored by custom dashboards, and protected by enterprise-grade security.

They're not just stored anymore. *They're loved.*

---

## Table of Contents

1. [Proxmox Cluster Infrastructure](#1-proxmox-cluster-infrastructure)
   - 1.1 [Understanding Proxmox VE](#11-understanding-proxmox-ve)
   - 1.2 [What is a Cluster?](#12-what-is-a-cluster)
   - 1.3 [Quorum and Qdevice](#13-quorum-and-qdevice)
   - 1.4 [Configuring Qdevice](#14-configuring-qdevice)
   - 1.5 [Node Specifications](#15-node-specifications)
   - 1.6 [Adding New Nodes](#16-adding-new-nodes)
   - 1.7 [Removing Nodes](#17-removing-nodes)
   - 1.8 [Updating Proxmox](#18-updating-proxmox)
   - 1.9 [Backup with PBS](#19-backup-with-proxmox-backup-server)
2. [Network Infrastructure](#2-network-infrastructure)
   - 2.1 [Physical Topology](#21-physical-topology)
   - 2.2 [Understanding VLANs](#22-understanding-vlans)
   - 2.3 [Switch Port Configuration Deep Dive](#23-switch-port-configuration-deep-dive)
   - 2.4 [DNS Architecture](#24-dns-architecture)
   - 2.5 [Remote Access with Tailscale](#25-remote-access-with-tailscale)
3. [VM Templates and Cloud-Init](#3-vm-templates-and-cloud-init)
   - 3.1 [Understanding Cloud-Init](#31-understanding-cloud-init)
   - 3.2 [Creating Templates Step-by-Step](#32-creating-templates-step-by-step)
   - 3.3 [Template Best Practices](#33-template-best-practices)
4. [Docker Services - Monitoring Stack](#4-docker-services---monitoring-stack)
   - 4.1 [Grafana Deep Dive](#41-grafana-deep-dive)
   - 4.2 [Prometheus Configuration](#42-prometheus-configuration)
   - 4.3 [Uptime Kuma](#43-uptime-kuma)
5. [Docker Services - Media Stack](#5-docker-services---media-stack)
   - 5.1 [The Arr Stack Architecture](#51-the-arr-stack-architecture)
   - 5.2 [Migration from VM to LXC](#52-migration-from-vm-to-lxc)
   - 5.3 [Service-by-Service Configuration](#53-service-by-service-configuration)
6. [Ansible Automation](#6-ansible-automation)
   - 6.1 [Installing Ansible](#61-installing-ansible)
   - 6.2 [Inventory Structure](#62-inventory-structure)
   - 6.3 [How Ansible Connects](#63-how-ansible-connects)
7. [Deployment Workflows](#7-deployment-workflows)
   - 7.1 [Complete Deployment Flow](#71-complete-deployment-flow)
   - 7.2 [Authentik Integration](#72-authentik-integration)
   - 7.3 [Service Dependencies](#73-service-dependencies)
8. [Storage Architecture](#8-storage-architecture)
   - 8.1 [Storage Design Philosophy](#81-storage-design-philosophy)
   - 8.2 [Synology NAS Configuration](#82-synology-nas-configuration)
   - 8.3 [Manual NFS Mounts](#83-manual-nfs-mounts)
   - 8.4 [LXC Bind Mount Strategy](#84-lxc-bind-mount-strategy)
9. [Kubernetes Cluster](#9-kubernetes-cluster)
   - 9.1 [Cluster Overview](#91-cluster-overview)
   - 9.2 [Node Architecture](#92-node-architecture)
   - 9.3 [Installing Kubernetes (kubeadm)](#93-installing-kubernetes-kubeadm)
   - 9.4 [Cluster Management](#94-cluster-management)
   - 9.5 [High Availability](#95-high-availability)
10. [Observability Stack](#10-observability-stack)
    - 10.1 [Architecture Overview](#101-architecture-overview)
    - 10.2 [Components](#102-components)
    - 10.3 [Service URLs](#103-service-urls)
    - 10.4 [Traefik OTEL Configuration](#104-traefik-otel-configuration)
    - 10.5 [Using Jaeger](#105-using-jaeger)
11. [Watchtower Interactive Updates](#11-watchtower-interactive-updates)
    - 11.1 [Overview](#111-overview)
    - 11.2 [Architecture](#112-architecture)
    - 11.3 [Watchtower Configuration](#113-watchtower-configuration)
    - 11.4 [Update Approval Flow](#114-update-approval-flow)
12. [Sentinel Discord Bot](#12-sentinel-discord-bot)
    - 12.1 [Overview](#121-overview)
    - 12.2 [Architecture](#122-architecture)
    - 12.3 [Channel Routing](#123-channel-routing)
    - 12.4 [Commands](#124-commands)
    - 12.5 [Management](#125-management)

---

# 1. Proxmox Cluster Infrastructure

## 1.1 Understanding Proxmox VE

### What is Proxmox VE?

**Proxmox Virtual Environment (Proxmox VE)** is an open-source server virtualization platform that combines two virtualization technologies:

1. **KVM (Kernel-based Virtual Machine)**: Full virtualization for running complete operating systems
2. **LXC (Linux Containers)**: Lightweight container-based virtualization

Think of Proxmox as the foundation that turns physical servers into virtual hosting platforms. It provides a web-based management interface and command-line tools to create, manage, and monitor virtual machines and containers.

### Why Proxmox for a Homelab?

| Feature | Benefit for Homelabs |
|---------|---------------------|
| **Free and Open Source** | No licensing costs unlike VMware or Hyper-V |
| **Web UI** | Easy management from any browser |
| **Clustering** | High availability without enterprise pricing |
| **LXC Support** | Lightweight containers for simple services |
| **ZFS Integration** | Enterprise storage features built-in |
| **Active Community** | Extensive forums and documentation |

### Current Deployment

| Property | Value |
|----------|-------|
| **Version** | Proxmox VE 9.1.2 |
| **Cluster Name** | MorpheusCluster |
| **Nodes** | 2 (node01, node02) |
| **Web UI** | https://192.168.20.21:8006 |
| **API Endpoint** | https://192.168.20.21:8006/api2/json |

---

## 1.2 What is a Cluster?

### Cluster Concepts

A **Proxmox cluster** is a group of Proxmox nodes that work together as a single unit. All nodes share:

- **Configuration database**: VM/container definitions, user permissions, storage definitions
- **Authentication**: Users and API tokens work across all nodes
- **Migration capability**: VMs can move between nodes

```text
┌─────────────────────────────────────────────────────────────────┐
│                      MorpheusCluster                             │
│                                                                  │
│  ┌──────────────────┐              ┌──────────────────┐         │
│  │     node01       │◄────────────►│     node02       │         │
│  │  192.168.20.20   │   Corosync   │  192.168.20.21   │         │
│  │                  │   (UDP 5404) │                  │         │
│  │ • K8s nodes      │              │ • Traefik        │         │
│  │ • Docker LXCs    │              │ • Authentik      │         │
│  │ • Ansible VM     │              │ • GitLab         │         │
│  └──────────────────┘              └──────────────────┘         │
│           │                                 │                    │
│           └──────────┬──────────────────────┘                    │
│                      │                                           │
│                      ▼                                           │
│              ┌──────────────┐                                    │
│              │   Qdevice    │                                    │
│              │ 192.168.20.51│                                    │
│              │   (Quorum)   │                                    │
│              └──────────────┘                                    │
└─────────────────────────────────────────────────────────────────┘
```

### How Clustering Works

Proxmox clustering uses **Corosync** for cluster communication:

1. **Corosync**: Handles cluster membership and messaging between nodes
2. **pmxcfs**: Proxmox Cluster File System - a database-driven filesystem that replicates configuration across all nodes
3. **Quorum**: A voting system that determines if the cluster is operational

### Cluster Benefits

| Benefit | Explanation |
|---------|-------------|
| **Centralized Management** | Manage all nodes from any node's web UI |
| **Live Migration** | Move running VMs between nodes without downtime |
| **High Availability** | Automatic VM restart on another node if one fails |
| **Shared Configuration** | Changes propagate to all nodes automatically |

---

## 1.3 Quorum and Qdevice

### The Quorum Problem

**Quorum** is the minimum number of votes required for the cluster to operate. Without quorum, Proxmox considers the cluster "unsafe" and stops all operations to prevent split-brain scenarios.

#### What is Split-Brain?

Split-brain occurs when network issues cause cluster nodes to lose communication. Without proper quorum handling:

- Node01 thinks Node02 is dead → starts VMs that were on Node02
- Node02 thinks Node01 is dead → keeps running its VMs
- Result: Same VMs running on both nodes → data corruption

#### Vote Calculation

| Nodes | Total Votes | Quorum Needed | Problem |
|:-----:|:-----------:|:-------------:|---------|
| 1 | 1 | 1 | No HA possible |
| 2 | 2 | 2 | If 1 node fails, cluster stops |
| 3 | 3 | 2 | One node can fail |
| 4 | 4 | 3 | One node can fail |

**Problem with 2-Node Clusters**: If one node fails, you have only 1 vote but need 2 for quorum. The entire cluster stops working!

### The Qdevice Solution

A **Qdevice (Quorum Device)** is a third-party witness that provides an additional vote without being a full cluster member.

```
Without Qdevice (2 nodes):
┌─────────┐     ┌─────────┐
│ Node01  │     │ Node02  │
│ 1 vote  │     │ 1 vote  │
└─────────┘     └─────────┘
Total: 2 votes, Quorum: 2
If either fails → No quorum → Cluster stops

With Qdevice (2 nodes + 1 Qdevice):
┌─────────┐     ┌─────────┐     ┌─────────┐
│ Node01  │     │ Node02  │     │ Qdevice │
│ 1 vote  │     │ 1 vote  │     │ 1 vote  │
└─────────┘     └─────────┘     └─────────┘
Total: 3 votes, Quorum: 2
If one node fails → 2 votes remain → Cluster continues!
```

---

## 1.4 Configuring Qdevice

### Prerequisites

- A separate Linux system (VM or LXC) to run as Qdevice
- Recommended: Debian/Ubuntu-based system
- Qdevice should NOT be on the same physical hardware as cluster nodes

### Step 1: Prepare the Qdevice Host

SSH into your future Qdevice system (192.168.20.51 in this case):

```bash
# Update system
apt update && apt upgrade -y

# Install corosync-qdevice daemon
apt install -y corosync-qnetd
```

**Package Explanation**:
- `corosync-qnetd`: The Qdevice network daemon that accepts connections from cluster nodes

### Step 2: Start the Qnetd Service

```bash
# Enable and start the Qnet daemon
systemctl enable corosync-qnetd
systemctl start corosync-qnetd

# Verify it's running
systemctl status corosync-qnetd
```

**Expected Output**:
```
● corosync-qnetd.service - Corosync Qdevice Network Daemon
     Loaded: loaded (/lib/systemd/system/corosync-qnetd.service; enabled)
     Active: active (running)
```

### Step 3: Add Qdevice to Cluster (From Any Cluster Node)

SSH into node01 or node02:

```bash
# Add the Qdevice to the cluster
pvecm qdevice setup 192.168.20.51
```

**What This Command Does**:
1. Generates TLS certificates for secure communication
2. Copies certificates to the Qdevice host
3. Configures corosync to use the Qdevice
4. Restarts cluster services

**Expected Output**:
```
Setting up SSH connection to 192.168.20.51...
Initializing qnetd on 192.168.20.51...
Adding qdevice to cluster configuration...
Restarting corosync...
Qdevice setup successful!
```

### Step 4: Verify Qdevice Status

```bash
# Check cluster status
pvecm status

# Should show:
# Membership information
# Nodes: 2
# Expected votes: 3 (2 nodes + 1 Qdevice)
# Quorum: 2 (majority of 3)
```

```bash
# Detailed Qdevice status
pvecm qdevice status

# Expected output:
# Qdevice information
# Model: Net
# Status: Connected
# Tie-breaker: Enabled
```

### Troubleshooting Qdevice

| Issue | Solution |
|-------|----------|
| Connection refused | Check firewall allows port 5403 (TCP) |
| Certificate error | Re-run `pvecm qdevice setup` |
| Qdevice not in quorum | Restart `corosync-qnetd` on Qdevice host |
| Vote count wrong | Check `pvecm expected` on cluster nodes |

---

## 1.5 Node Specifications

### Hardware Details

| Property | node01 | node02 | node03 |
|----------|--------|--------|--------|
| **Hostname** | node01 | node02 | node03 |
| **IP Address** | 192.168.20.20 | 192.168.20.21 | 192.168.20.22 |
| **Tailscale IP** | 100.89.33.5 | 100.96.195.27 | - |
| **CPU** | AMD Ryzen 9 PRO 8945HS | AMD Ryzen 9 6900HX | AMD Ryzen 9 5900XT |
| **Cores/Threads** | 8 cores / 16 threads | 8 cores / 16 threads | 16 cores / 32 threads |
| **RAM** | 64 GB DDR5 | 32 GB DDR5 | 32 GB DDR4 |
| **Internal Storage** | 512 GB NVMe | 512 GB NVMe | 2x 1TB NVMe + 1TB SSD + 4TB HDD |
| **Network** | 2.5 GbE | 2.5 GbE | 2.5 GbE |
| **Form Factor** | Minisforum MS-01 | Minisforum HX90G | Desktop PC |
| **MAC Address** | 38:05:25:32:82:76 | 84:47:09:4D:7A:CA | TBD |

### Role Distribution

| Node | Primary Role | VMs/Containers |
|------|--------------|----------------|
| **node01** | Primary VM Host | Ansible, K8s cluster (9 nodes), Docker LXCs |
| **node02** | Service Host | Traefik, Authentik |
| **node03** | Desktop Node | GitLab, Immich, Syslog Server |

### Why This Distribution?

**node01 (64 GB RAM)**: Kubernetes requires significant memory for multiple nodes. The K8s cluster has 9 VMs, each consuming RAM.

**node02 (32 GB RAM)**: Running individual service VMs that don't need as much total memory but benefit from dedicated resources.

**node03 (32 GB RAM)**: Desktop PC repurposed as a server. Runs heavier workloads like GitLab and Immich that benefit from the Ryzen 9's 16 cores. Configured with power-saving optimizations to reduce idle power consumption.

### Node03 Power Management

Node03 is a desktop PC with power-saving optimizations to reduce idle power from ~100-150W to ~40-60W:

| Setting | Value | Effect |
|---------|-------|--------|
| CPU Governor | `powersave` | Reduces clock speed at idle |
| AMD P-State | `amd-pstate-epp` | Modern AMD power management driver |
| Max C-State | `9` | Enables deep CPU sleep states |
| SATA Policy | `med_power_with_dipm` | SATA link power management |
| PCIe ASPM | `powersave` | PCIe Active State Power Management |
| HDD Spindown | 20 minutes | Spins down 4TB HDD when idle |

**GRUB Configuration** (`/etc/default/grub`):
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_pstate=active processor.max_cstate=9"
```

**Systemd Services**:
- `power-save.service` - Applies CPU governor, SATA, PCIe, NVMe settings at boot
- `powertop.service` - Runs powertop auto-tune at boot

**Power-Save Script** (`/usr/local/bin/power-save.sh`):
- Sets all CPU cores to powersave governor
- Enables SATA link power management
- Configures PCIe ASPM
- Sets NVMe power tolerance
- Enables audio codec power save

**Verify Power Settings**:
```bash
# Check CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor  # Should show: powersave

# Check scaling driver
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver   # Should show: amd-pstate-epp

# Check services
systemctl status power-save powertop

# Monitor power impact
powertop
```

---

## 1.6 Adding New Nodes

### Prerequisites for New Node

Before adding a node to the cluster:

1. **Fresh Proxmox Installation**: Do NOT configure anything before joining
2. **Network Connectivity**: Node must reach existing cluster nodes
3. **Same Proxmox Version**: Major version must match (e.g., all on PVE 9.x)
4. **Unique Hostname**: Cannot duplicate existing node names
5. **NTP Synced**: Time must be synchronized across all nodes

### Step-by-Step: Add node03 to Cluster

#### Step 1: Install Proxmox on New Hardware

Install Proxmox VE on the new machine. During installation:
- Set hostname: `node03`
- Set IP: `192.168.20.22` (next available in your scheme)
- Set gateway: `192.168.20.1`

#### Step 2: Verify Network Connectivity

From node03, verify it can reach existing nodes:

```bash
# Ping existing nodes
ping -c 3 192.168.20.20    # node01
ping -c 3 192.168.20.21    # node02

# Verify DNS resolution
nslookup node01
nslookup node02
```

#### Step 3: Add to Hosts File (If No DNS)

```bash
# On node03, add entries
echo "192.168.20.20 node01" >> /etc/hosts
echo "192.168.20.21 node02" >> /etc/hosts
```

#### Step 4: Join the Cluster

From **node03** (the new node):

```bash
# Join existing cluster
pvecm add 192.168.20.20

# You will be prompted for:
# - Root password of node01
# - Confirmation to join
```

**What Happens During Join**:

1. SSH connection established to node01
2. Cluster configuration copied from node01
3. Corosync configuration updated
4. pmxcfs synced to new node
5. All existing VMs/containers become visible (but don't migrate automatically)

#### Step 5: Verify Join Success

```bash
# On any node, check cluster status
pvecm status

# Should show:
# Membership information
# Nodes: 3
# Expected votes: 4 (3 nodes + 1 Qdevice)
```

```bash
# Verify in web UI
# Navigate to Datacenter → Cluster → Nodes
# All three nodes should appear with green status
```

### Post-Join Configuration

After joining, configure node03:

```bash
# 1. Install Tailscale for remote access
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up

# 2. Enable Wake-on-LAN
ethtool -s nic0 wol g

# 3. Configure VLAN-aware bridge (if needed)
# Edit /etc/network/interfaces

# 4. Add NFS storage mounts
# Datacenter → Storage → Add NFS
```

---

## 1.7 Removing Nodes

### When to Remove a Node

- Hardware failure requiring permanent removal
- Downsizing the cluster
- Replacing with different hardware

### Prerequisites for Removal

**CRITICAL**: Before removing a node, you MUST:

1. **Migrate all VMs/containers** off the node
2. **Stop all running workloads** on the node
3. **Ensure cluster maintains quorum** after removal

### Step-by-Step: Remove node03 from Cluster

#### Step 1: Migrate Workloads

From the web UI or command line, migrate all VMs:

```bash
# List VMs on node03
qm list

# Migrate each VM to another node (e.g., VM 100 to node01)
qm migrate 100 node01

# For LXC containers
pct migrate 200 node01
```

#### Step 2: Verify No Workloads Remain

```bash
# On node03
qm list       # Should be empty
pct list      # Should be empty
```

#### Step 3: Shutdown the Node

```bash
# On node03
shutdown -h now
```

#### Step 4: Remove from Cluster

From **another node** (node01 or node02):

```bash
# Remove node03 from cluster
pvecm delnode node03
```

**What Happens**:
1. Node removed from cluster membership
2. Corosync configuration updated
3. Vote count recalculated
4. Node's SSH keys removed from authorized_keys

#### Step 5: Clean Up the Removed Node (Optional)

If you want to reuse node03 as a standalone Proxmox:

```bash
# On node03 after power on
systemctl stop pve-cluster
systemctl stop corosync
pmxcfs -l    # Start in local mode

# Remove cluster configuration
rm /etc/pve/corosync.conf
rm /etc/corosync/*

# Restart in standalone mode
killall pmxcfs
systemctl start pve-cluster
```

---

## 1.8 Updating Proxmox

### Update Strategy

**IMPORTANT**: Always update one node at a time. Never update all nodes simultaneously.

### Pre-Update Checklist

- [ ] Verify current versions on all nodes
- [ ] Check Proxmox forums for known issues with new version
- [ ] Ensure backups are current
- [ ] Plan maintenance window
- [ ] Verify cluster is healthy (`pvecm status`)

### Step 1: Check Current Version

```bash
# On each node
pveversion -v

# Example output:
# proxmox-ve: 9.1.2 (running kernel: 6.8.12-3-pve)
# pve-manager: 8.3.2
# ...
```

### Step 2: Update Package Lists

```bash
# Update apt repositories
apt update
```

### Step 3: Review Available Updates

```bash
# List upgradable packages
apt list --upgradable

# Check specifically for PVE packages
apt list --upgradable | grep pve
```

### Step 4: Perform the Upgrade

```bash
# Full system upgrade
apt full-upgrade -y

# Or use the Proxmox-specific command
pveupgrade
```

**Important Flags Explained**:
- `full-upgrade`: Upgrades packages and handles dependency changes (may remove obsolete packages)
- `dist-upgrade`: Alias for full-upgrade
- `-y`: Auto-confirm (use cautiously)

### Step 5: Reboot if Required

```bash
# Check if reboot needed (kernel updates require reboot)
cat /var/run/reboot-required

# If file exists, reboot
reboot
```

### Step 6: Verify After Update

```bash
# Check version
pveversion -v

# Verify cluster health
pvecm status

# Check all services
systemctl status pve-cluster
systemctl status pvedaemon
systemctl status pveproxy
```

### Step 7: Repeat for Other Nodes

Wait for the first node to fully come back online, then repeat for the next node.

### Troubleshooting Updates

| Issue | Solution |
|-------|----------|
| `apt update` fails | Check `/etc/apt/sources.list.d/pve-enterprise.list` - comment out if no subscription |
| Kernel panic after reboot | Boot previous kernel from GRUB menu |
| Cluster won't form | Check corosync status: `systemctl status corosync` |
| Web UI unreachable | Restart pveproxy: `systemctl restart pveproxy` |

### No-Subscription Repository

For homelab use without a Proxmox subscription:

```bash
# Disable enterprise repo (if enabled)
mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.disabled

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update
apt update
```

---

## 1.9 Backup with Proxmox Backup Server

### What is PBS?

**Proxmox Backup Server (PBS)** is a dedicated backup solution designed specifically for Proxmox VE. It provides:

- **Deduplication**: Only stores unique data blocks
- **Encryption**: Client-side encryption option
- **Incremental backups**: Fast backups after initial full backup
- **Web UI**: Easy management interface

### PBS vs vzdump

| Feature | vzdump (Built-in) | PBS |
|---------|-------------------|-----|
| Backup Type | Full backup each time | Incremental with deduplication |
| Storage Efficiency | Low (full images) | High (deduplicated blocks) |
| Restore Speed | Fast | Very fast (can mount backups) |
| Encryption | No | Yes (client-side) |
| Verification | Basic | Bit-rot detection with checksums |

### Setting Up PBS

#### Option 1: PBS as LXC Container

```bash
# Download PBS CT template
pveam download local vzdump-ct-pbs-latest.tar.zst

# Create LXC for PBS
pct create 250 local:vztmpl/vzdump-ct-pbs-latest.tar.zst \
  --hostname pbs \
  --cores 2 \
  --memory 4096 \
  --rootfs local-lvm:50 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.20.50/24,gw=192.168.20.1 \
  --onboot 1

# Start container
pct start 250
```

#### Option 2: PBS as VM

Download PBS ISO from Proxmox website and install as a VM with:
- 2+ CPU cores
- 4+ GB RAM
- Large storage for backups (dedicated disk recommended)

### Adding PBS to Proxmox VE

#### Step 1: In PBS Web UI (https://192.168.20.50:8007)

1. Create a **Datastore** (Storage → Datastore → Add)
2. Create an **API Token** (Configuration → Access Control → API Token)

#### Step 2: In Proxmox VE Web UI

1. Navigate to **Datacenter → Storage → Add → Proxmox Backup Server**
2. Fill in details:

| Field | Value | Explanation |
|-------|-------|-------------|
| ID | pbs | Storage name in PVE |
| Server | 192.168.20.50 | PBS IP address |
| Username | root@pam | PBS user |
| Password | (your password) | Or use API token |
| Datastore | backups | Name of datastore in PBS |
| Fingerprint | (from PBS) | SSL certificate fingerprint |

### Creating Backup Jobs

#### Via Web UI

1. **Datacenter → Backup → Add**
2. Configure:
   - Storage: pbs
   - Schedule: 0 3 * * * (3 AM daily)
   - Selection: All VMs or specific VMs
   - Mode: Snapshot (recommended for running VMs)
   - Compression: ZSTD (best ratio/speed)

#### Via Command Line

```bash
# Backup a specific VM to PBS
vzdump 100 --storage pbs --mode snapshot --compress zstd

# Backup all VMs on this node
vzdump --all --storage pbs --mode snapshot --compress zstd
```

**Command Breakdown**:
- `vzdump`: Proxmox backup utility
- `100`: VM ID to backup
- `--storage pbs`: Use PBS storage
- `--mode snapshot`: Take snapshot for consistent backup
- `--compress zstd`: Use ZSTD compression

### Restoring from PBS

#### Via Web UI

1. Navigate to PBS storage in Proxmox VE
2. Select backup to restore
3. Click "Restore"
4. Choose target node and storage
5. Optionally change VM ID

#### Via Command Line

```bash
# Restore VM 100 from latest backup
qmrestore pbs:backup/vm/100/2026-01-07T03:00:00Z 100 --storage VMDisks
```

### Verification and Maintenance

```bash
# Verify backup integrity (run on PBS)
proxmox-backup-client verify backup/vm/100/2026-01-07T03:00:00Z

# Run garbage collection to free space
proxmox-backup-manager gc run backups

# Check datastore status
proxmox-backup-manager datastore status backups
```

---

# 2. Network Infrastructure

## 2.1 Physical Topology

### Network Diagram

```
                                    Internet
                                        │
                                        ▼
                              ┌─────────────────┐
                              │   ISP Router    │
                              │  192.168.100.1  │
                              │   (Converge)    │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │  ER605 Router   │ ◄─── Core Gateway
                              │   192.168.0.1   │      Inter-VLAN routing
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │  Atreus Switch  │ ◄─── First Floor
                              │    ES20GP       │      POE for APs
                              │  192.168.90.51  │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │   Core Switch   │ ◄─── Distribution Layer
                              │     SG3210      │      VLAN Trunking
                              │  192.168.90.2   │
                              └────────┬────────┘
                                       │
          ┌────────────┬───────────────┼───────────────┬────────────┐
          │            │               │               │            │
          ▼            ▼               ▼               ▼            ▼
    ┌──────────┐ ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────┐
    │ Morpheus │ │ OPNsense │  │ Synology │  │  Wireless │  │  Kratos  │
    │  Switch  │ │ Firewall │  │   NAS    │  │    APs    │  │    PC    │
    │ SG2210P  │ │  .91.30  │  │  .20.31  │  │ EAP225/   │  │  .10.10  │
    │  .90.3   │ │          │  │          │  │ EAP610    │  │          │
    └────┬─────┘ └──────────┘  └──────────┘  └───────────┘  └──────────┘
         │
    ┌────┼────┬────┐
    │    │    │    │
    ▼    ▼    ▼    ▼
  Node01 Node02 NAS  EAP
  (.20) (.21) (.31) (.12)
```

### Hardware Inventory

| Device | Model | IP Address | MAC Address | Purpose |
|--------|-------|------------|-------------|---------|
| Core Router | ER605 v2.20 | 192.168.0.1 | 8C:90:2D:4B:D9:6C | Gateway, NAT, inter-VLAN |
| Core Switch | SG3210 v3.20 | 192.168.90.2 | 40:AE:30:B7:96:74 | Main distribution |
| Morpheus Switch | SG2210P v5.20 | 192.168.90.3 | DC:62:79:2A:0D:66 | Proxmox connectivity |
| Atreus Switch | ES20GP v1.0 | 192.168.90.51 | A8:29:48:96:C7:12 | First floor |
| Living Room EAP | EAP610 v3.0 | 192.168.90.10 | 3C:64:CF:37:96:EC | Primary WiFi |
| Outdoor EAP | EAP603 v1.0 | 192.168.90.11 | 78:20:51:C1:EA:A6 | Outdoor WiFi |
| Computer Room EAP | EAP225 v4.0 | 192.168.90.12 | 0C:EF:15:50:39:52 | Computer room WiFi |

---

## 2.2 Understanding VLANs

### What is a VLAN?

A **VLAN (Virtual Local Area Network)** is a logical grouping of network devices that appear to be on the same LAN regardless of their physical location.

Think of it like apartments in a building:
- **Physical building** = Your switch
- **Apartments** = VLANs
- **Hallways** = Trunk ports (shared corridors)
- **Front doors** = Access ports (one apartment entrance)

### Why Use VLANs?

| Reason | Explanation |
|--------|-------------|
| **Security** | Isolate IoT devices from main network |
| **Performance** | Reduce broadcast traffic |
| **Organization** | Group devices by function |
| **Traffic Control** | Apply policies per VLAN |

### VLAN Terminology Deep Dive

| Term | Definition | Example |
|------|------------|---------|
| **VLAN ID** | Numeric identifier (1-4094) | VLAN 40 |
| **Tagged (802.1Q)** | Frame carries VLAN ID in header | Proxmox node receiving multiple VLANs |
| **Untagged** | Frame has no VLAN tag | Simple device on one VLAN |
| **Native VLAN** | VLAN for untagged traffic on trunk | VLAN 1 (default) |
| **Access Port** | Port in single VLAN (untagged) | NAS port |
| **Trunk Port** | Port carrying multiple VLANs (tagged) | Switch-to-switch link |
| **PVID** | Port VLAN ID - default VLAN for incoming untagged traffic | PVID 20 on Proxmox port |

### Complete VLAN Configuration

| VLAN ID | Name | Network | Gateway | Purpose | DHCP Range |
|:-------:|------|---------|---------|---------|------------|
| 1 | Default | 192.168.0.0/24 | 192.168.0.1 | Management fallback | .100-.199 |
| 10 | Internal | 192.168.10.0/24 | 192.168.10.1 | Main LAN (PCs, NAS) | .50-.254 |
| **20** | **Homelab** | **192.168.20.0/24** | **192.168.20.1** | **Proxmox, K8s** | .50-.254 |
| 30 | IoT | 192.168.30.0/24 | 192.168.30.1 | Smart devices | .50-.254 |
| **40** | **Production** | **192.168.40.0/24** | **192.168.40.1** | **Docker services** | .50-.254 |
| 50 | Guest | 192.168.50.0/24 | 192.168.50.1 | Guest WiFi | .50-.254 |
| 60 | Sonos | 192.168.60.0/24 | 192.168.60.1 | Speakers | .50-.100 |
| 90 | Management | 192.168.90.0/24 | 192.168.90.1 | Network devices | .50-.254 |
| 91 | Firewall | 192.168.91.0/24 | 192.168.91.1 | OPNsense | Static only |

### WiFi SSID to VLAN Mapping

Each VLAN has a dedicated WiFi SSID, providing wireless access to the appropriate network segment:

| SSID | VLAN | Purpose |
|------|:----:|---------|
| NKD5380-Internal | 10 | Main home network (phones, laptops) |
| NHN7476-Homelab | 20 | Homelab devices requiring VLAN 20 access |
| WOC321-IoT | 30 | Smart home devices (isolated) |
| NAZ9229-Production | 40 | Direct access to Docker services |
| EAD6167-Guest | 50 | Visitor access (rate limited) |
| NAZ9229-Sonos | 60 | Sonos speakers |
| NCP5653-Management | 90 | Network device management |

> **Security Note**: WiFi passwords are stored separately in the Obsidian vault credentials file. All SSIDs use WPA3 when supported, with WPA2 fallback.

---

## 2.3 Switch Port Configuration Deep Dive

### Understanding Port Modes

#### Access Mode
- **One VLAN** per port
- Traffic leaves switch **untagged**
- Used for: End devices (PCs, printers, simple servers)

```text
┌─────────────┐                ┌─────────────┐
│   Device    │  Untagged     │   Switch    │
│   (PC)      │◄─────────────►│  Port 1     │
└─────────────┘   VLAN 10     │  (Access)   │
                              └─────────────┘
```

#### Trunk Mode
- **Multiple VLANs** per port
- Traffic leaves switch **tagged with VLAN ID**
- Used for: Switch-to-switch, switch-to-router, hypervisors

```text
┌─────────────┐                ┌─────────────┐
│  Proxmox    │  Tagged       │   Switch    │
│   Node      │◄─────────────►│  Port 2     │
└─────────────┘   VLAN 10,20  │  (Trunk)    │
                   40 tagged  └─────────────┘
                   VLAN 20 native (untagged)
```

### Morpheus Switch (SG2210P) - Detailed Port Configuration

**Role**: Connects Proxmox nodes, provides PoE for access points

| Port | Device | Mode | Native VLAN | Tagged VLANs | Explanation |
|:----:|--------|:----:|:-----------:|--------------|-------------|
| 1 | Core Switch Uplink | Trunk | 1 | 1,10,20,30,40,50,90 | Carries all VLANs to distribution |
| 2 | **Proxmox Node 01** | Trunk | 20 | 10, 40 | Native 20 for host, tagged 10/40 for VMs |
| 3 | (Empty) | - | - | - | Reserved for expansion |
| 4 | (Empty) | - | - | - | Reserved for expansion |
| 5 | Computer Room EAP | Trunk | 1 | 10,20,30,40,50,90 | All SSIDs need their VLANs |
| 6 | **Proxmox Node 02** | Trunk | 20 | 10, 40 | Native 20 for host, tagged 10/40 for VMs |
| 7 | Synology NAS (eth0) | Access | 10 | - | Internal LAN access |
| 8 | Synology NAS (eth1) | Access | 20 | - | Homelab/Proxmox access |
| 9-10 | (SFP ports) | - | - | - | Unused |

**Why Proxmox Ports are Trunk with Native VLAN 20**:

1. **Native VLAN 20**: The Proxmox host itself (management interface) uses VLAN 20. Untagged traffic goes to VLAN 20.
2. **Tagged VLAN 10**: Some VMs need access to the Internal network (VLAN 10)
3. **Tagged VLAN 40**: Service VMs (Docker hosts, Traefik, etc.) live on VLAN 40

When a VM on Proxmox is configured with VLAN 40:
- Proxmox adds an 802.1Q tag (VLAN 40) to the VM's traffic
- Switch receives tagged traffic, forwards to VLAN 40
- Return traffic tagged by switch, stripped by Proxmox bridge, delivered to VM

### Core Switch (SG3210) - Detailed Port Configuration

**Role**: Main distribution switch, connects all other switches

| Port | Device | Mode | Native VLAN | Tagged VLANs | Explanation |
|:----:|--------|:----:|:-----------:|--------------|-------------|
| 1 | OC300 Controller | Trunk | 1 | All | Controller needs all VLANs for management |
| 2 | OPNsense Port | Access | 90 | - | Firewall on management VLAN |
| 3-4 | (Empty) | - | - | - | Reserved |
| 5 | Zephyrus Laptop | Access | 10 | - | Laptop on Internal VLAN |
| 6 | Morpheus Switch Uplink | Trunk | 1 | 10,20,30,40,50,90 | Link to Proxmox rack |
| 7 | Kratos PC | Trunk | 10 | 20 | PC on VLAN 10, can reach VLAN 20 for Hyper-V |
| 8 | Atreus Switch Uplink | Trunk | 1 | All | Link to first floor |
| 9-10 | (SFP) | - | - | - | Unused |

**Why Kratos PC Needs Trunk with Tagged VLAN 20**:

The main PC sometimes runs Hyper-V VMs that need to be on VLAN 20 (Homelab). Instead of creating a separate physical connection:
- Native VLAN 10: PC's main Windows interface
- Tagged VLAN 20: Hyper-V virtual switch can tag traffic for VLAN 20

### Configuring Ports in Omada Controller

#### To Set Access Port:

1. Navigate to **Devices → (Switch) → Ports**
2. Select port → Edit
3. Set Profile to the VLAN name (e.g., "Internal")
4. Apply

#### To Set Trunk Port:

1. Navigate to **Devices → (Switch) → Ports**
2. Select port → Edit
3. Set Profile to "General" or create custom profile
4. Specify:
   - PVID (Native VLAN)
   - Tagged VLANs (check boxes)
   - Untagged VLAN (usually same as PVID)
5. Apply

---

## 2.4 DNS Architecture

### Components

```text
┌────────────────────────────────────────────────────────────────┐
│                     DNS Resolution Flow                         │
│                                                                 │
│   Client Device                                                 │
│        │                                                        │
│        │ Query: grafana.hrmsmrflrii.xyz                        │
│        ▼                                                        │
│   ┌──────────────┐                                             │
│   │   Pi-hole    │  Local DNS: *.hrmsmrflrii.xyz → 192.168.40.20│
│   │192.168.90.53 │                                             │
│   └──────┬───────┘                                             │
│          │                                                      │
│          │ Not local? Forward to Unbound                       │
│          ▼                                                      │
│   ┌──────────────┐                                             │
│   │   Unbound    │  Recursive resolution                       │
│   │127.0.0.1:5335│  (No public DNS dependency)                 │
│   └──────┬───────┘                                             │
│          │                                                      │
│          ▼                                                      │
│   Root DNS Servers                                              │
└────────────────────────────────────────────────────────────────┘
```

### Pi-hole Configuration

**IP Address**: 192.168.90.53 (VLAN 90 - Management)
**Version**: Pi-hole v6

**Local DNS Records** (in Pi-hole → Local DNS → DNS Records):

| Domain | IP Address | Purpose |
|--------|------------|---------|
| *.hrmsmrflrii.xyz | 192.168.40.20 | Wildcard to Traefik |
| proxmox.hrmsmrflrii.xyz | 192.168.20.21 | Proxmox Web UI |
| nas.hrmsmrflrii.xyz | 192.168.20.31 | Synology DSM |

### Unbound Configuration

Unbound runs as a recursive resolver, querying root servers directly instead of forwarding to Google/Cloudflare:

```yaml
# /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    # Listen on localhost
    interface: 127.0.0.1
    port: 5335

    # Don't be an open resolver
    access-control: 127.0.0.0/8 allow
    access-control: 0.0.0.0/0 refuse

    # Performance
    num-threads: 2
    msg-cache-size: 50m
    rrset-cache-size: 100m

    # Security
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
```

---

## 2.5 Remote Access with Tailscale

### Architecture

Tailscale creates a mesh VPN using WireGuard, allowing secure access from anywhere without port forwarding.

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Tailscale Network                            │
│                                                                 │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │   MacBook    │     │   node01     │     │   node02     │    │
│  │100.90.207.58 │     │ 100.89.33.5  │     │100.96.195.27 │    │
│  └──────┬───────┘     │SUBNET ROUTER │     └──────────────┘    │
│         │             └──────┬───────┘                          │
│         │                    │                                  │
│         └────────────────────┤                                  │
│                              │ Advertises:                      │
│                              │ • 192.168.20.0/24               │
│                              │ • 192.168.40.0/24               │
│                              │ • 192.168.91.0/24               │
└──────────────────────────────┼──────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
              ┌─────▼─────┐        ┌──────▼─────┐
              │VLAN 20    │        │VLAN 40     │
              │192.168.20 │        │192.168.40  │
              │Proxmox,K8s│        │Services    │
              └───────────┘        └────────────┘
```

### Subnet Router Configuration on node01

```bash
# 1. Enable IP forwarding (required for routing)
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf

# 2. Start Tailscale with subnet routes
tailscale up \
  --advertise-routes=192.168.20.0/24,192.168.40.0/24,192.168.91.0/24 \
  --accept-routes

# 3. Approve routes in Tailscale Admin Console
# https://login.tailscale.com/admin/machines
# Find node01 → Edit route settings → Enable all routes
```

**Flags Explained**:
- `--advertise-routes`: Tell Tailscale "I can route traffic to these networks"
- `--accept-routes`: Accept routes advertised by other nodes
- Routes must be approved in admin console for security

---

# 3. VM Templates and Cloud-Init

## 3.1 Understanding Cloud-Init

### What is Cloud-Init?

**Cloud-init** is an industry-standard tool for initializing cloud instances. It runs on first boot and configures:

- Hostname
- Network settings
- SSH keys
- User accounts
- Package installation
- Custom scripts

Think of it like this: A cloud-init template is a "blank" VM image. When you clone it, cloud-init fills in the blanks (hostname, IP, etc.) automatically.

### Why Use Cloud-Init?

| Approach | Effort per VM | Consistency | Scalability |
|----------|--------------|-------------|-------------|
| Manual install | 30+ minutes | Varies | Poor |
| Cloned VM | 5 minutes | Good | Moderate |
| **Cloud-Init Template** | **30 seconds** | **Perfect** | **Excellent** |

### How Cloud-Init Works in Proxmox

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Cloud-Init Boot Process                       │
│                                                                  │
│  1. Clone template → New VM created                              │
│  2. Start VM                                                     │
│  3. Cloud-init runs (first boot only):                          │
│     • Reads config from "NoCloud" datasource (ide2 drive)       │
│     • Sets hostname                                              │
│     • Configures network (IP, gateway, DNS)                     │
│     • Creates user with SSH key                                  │
│     • Resizes root partition                                     │
│     • Runs custom scripts (if configured)                        │
│  4. VM ready in ~30 seconds                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3.2 Creating Templates Step-by-Step

### Prerequisites

- Proxmox VE installed
- Internet access from Proxmox host
- NFS storage mounted (for shared templates)

### Step 1: Download Cloud Image

```bash
# SSH into Proxmox node
ssh root@192.168.20.20

# Navigate to ISO storage
cd /var/lib/vz/template/iso

# Download Ubuntu 24.04 cloud image
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

**Why this image?**
- `.img` format is a raw disk image
- Cloud images are pre-configured for cloud-init
- Minimal size (~600MB) unlike full ISO (~2GB)
- Includes QEMU guest agent

### Step 2: Create Base VM

```bash
# Create VM with ID 9000 (convention: 9xxx for templates)
qm create 9000 \
  --name "tpl-ubuntu-24.04-cloudinit" \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0
```

**Parameter Breakdown**:
| Parameter | Value | Purpose |
|-----------|-------|---------|
| `9000` | VM ID | High number indicates template |
| `--name` | Template name | Descriptive name |
| `--memory` | 2048 | 2GB RAM (can be changed per clone) |
| `--cores` | 2 | 2 CPU cores (can be changed per clone) |
| `--net0` | virtio,bridge=vmbr0 | Network interface using virtio driver |

### Step 3: Import Cloud Image as Disk

```bash
# Import the downloaded image as a disk
qm importdisk 9000 noble-server-cloudimg-amd64.img VMDisks
```

**What Happens**:
1. Proxmox converts the cloud image to qcow2 format
2. Disk is stored in VMDisks storage
3. Disk is NOT attached yet (shows as "Unused Disk 0")

### Step 4: Attach the Disk

```bash
# Attach as SCSI disk with VirtIO SCSI controller
qm set 9000 \
  --scsihw virtio-scsi-single \
  --scsi0 VMDisks:vm-9000-disk-0
```

**Why VirtIO SCSI?**
- Better performance than IDE or SATA
- `virtio-scsi-single` uses one controller per disk (optimal for NVMe-like performance)
- Modern Linux kernels include VirtIO drivers

### Step 5: Add Cloud-Init Drive

```bash
# Create cloud-init drive on IDE bus
qm set 9000 --ide2 VMDisks:cloudinit
```

**What This Does**:
- Creates a small "NoCloud" datasource drive
- Cloud-init reads configuration from this drive
- Contains: user-data, meta-data, network-config

### Step 6: Set Boot Order

```bash
# Boot from SCSI disk
qm set 9000 --boot order=scsi0
```

### Step 7: Enable UEFI Boot

```bash
# Enable UEFI with OVMF firmware
qm set 9000 \
  --bios ovmf \
  --machine q35 \
  --efidisk0 VMDisks:1,efitype=4m,pre-enrolled-keys=1
```

**Parameter Breakdown**:
| Parameter | Value | Purpose |
|-----------|-------|---------|
| `--bios ovmf` | OVMF | UEFI firmware instead of legacy BIOS |
| `--machine q35` | Q35 chipset | Modern chipset with PCIe support |
| `--efidisk0` | EFI vars disk | Stores UEFI variables |
| `efitype=4m` | Size | 4MB EFI variable store |
| `pre-enrolled-keys=1` | Secure Boot keys | Enables Secure Boot if needed |

### Step 8: Enable QEMU Guest Agent

```bash
qm set 9000 --agent enabled=1
```

**Why Guest Agent?**
- Allows Proxmox to gracefully shutdown VM
- Enables IP address display in Proxmox UI
- Required for filesystem freeze during backup

### Step 9: Configure Cloud-Init Defaults

```bash
# Set default user
qm set 9000 --ciuser hermes-admin

# Add SSH public key
qm set 9000 --sshkeys ~/.ssh/authorized_keys

# Set default network to DHCP (will override per-clone)
qm set 9000 --ipconfig0 ip=dhcp
```

### Step 10: Convert to Template

```bash
# Convert VM to template (makes it read-only)
qm template 9000
```

**After This**:
- VM 9000 shows with template icon in Proxmox UI
- Cannot start a template directly
- Can only clone from template

---

## 3.3 Template Best Practices

### Naming Convention

```
tpl-<os>-<version>-<variant>
Examples:
- tpl-ubuntu-24.04-cloudinit
- tpl-debian-12-minimal
- tpl-rocky-9-docker
```

### Template Storage

| Storage Type | Good For Templates? | Why |
|--------------|--------------------|----- |
| Local LVM | Yes | Fast cloning |
| Local ZFS | Yes | Fast cloning with snapshots |
| NFS | Yes | Shared across cluster |
| Ceph | Excellent | Distributed, fast cloning |

### Cloning Templates with Terraform

```hcl
# main.tf
resource "proxmox_vm_qemu" "docker_host" {
  name        = "docker-vm-01"
  target_node = "node01"
  clone       = "tpl-ubuntu-24.04-cloudinit"
  full_clone  = true

  cores   = 4
  memory  = 8192

  # Cloud-init configuration
  os_type    = "cloud-init"
  ciuser     = "hermes-admin"
  cipassword = var.vm_password
  sshkeys    = file("~/.ssh/homelab_ed25519.pub")

  ipconfig0 = "ip=192.168.40.50/24,gw=192.168.40.1"
  nameserver = "192.168.90.53"

  disk {
    storage = "VMDisks"
    size    = "50G"
  }
}
```

---

# 4. Docker Services - Monitoring Stack

## 4.1 Grafana Deep Dive

### What is Grafana?

**Grafana** is an open-source analytics and visualization platform. It connects to various data sources (Prometheus, InfluxDB, MySQL, etc.) and displays metrics as dashboards with graphs, gauges, and alerts.

### Current Deployment

| Property | Value |
|----------|-------|
| **Host** | docker-vm-core-utilities01 (192.168.40.13) |
| **Port** | 3030 (internal), 3000 (container) |
| **Version** | Latest (auto-updates via Watchtower) |
| **URL** | https://grafana.hrmsmrflrii.xyz |
| **Storage** | /opt/monitoring/grafana/ |

### Docker Compose Configuration

```yaml
# /opt/monitoring/docker-compose.yml
services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3030:3000"           # Host:Container port mapping
    volumes:
      - ./grafana/data:/var/lib/grafana                    # Persistent data
      - ./grafana/provisioning:/etc/grafana/provisioning   # Auto-provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards   # Dashboard JSON files
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
      - GF_SERVER_ROOT_URL=https://grafana.hrmsmrflrii.xyz
      - GF_SECURITY_ALLOW_EMBEDDING=true      # CRITICAL for Glance iframes
      - GF_AUTH_ANONYMOUS_ENABLED=true        # Allow anonymous view
      - GF_AUTH_ANONYMOUS_ORG_NAME=Main Org.
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
      - TZ=Asia/Manila
    networks:
      - monitoring
```

**Line-by-Line Explanation**:

| Line | Purpose |
|------|---------|
| `image: grafana/grafana:latest` | Official Grafana image, latest version |
| `ports: - "3030:3000"` | Map host port 3030 to container port 3000 |
| `./grafana/data:/var/lib/grafana` | Persist dashboards, users, settings |
| `./grafana/provisioning:/etc/grafana/provisioning` | Auto-configure datasources/dashboards |
| `GF_SECURITY_ALLOW_EMBEDDING=true` | **Required** for embedding in Glance iframes |
| `GF_AUTH_ANONYMOUS_ENABLED=true` | Allow viewing dashboards without login |
| `GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer` | Anonymous users can only view, not edit |

### How Grafana Connects to Prometheus

Grafana doesn't collect metrics itself—it queries data sources. The connection to Prometheus is configured via provisioning:

```yaml
# /opt/monitoring/grafana/provisioning/datasources/datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
      httpMethod: "POST"
```

**How It Works**:
1. Grafana dashboard panel has a query (PromQL)
2. Grafana sends query to Prometheus URL
3. Prometheus returns time-series data
4. Grafana renders visualization

### Grafana Dashboards

We have four main Grafana dashboards embedded in Glance:

#### 1. Container Status Dashboard

**UID**: `container-status`
**Purpose**: Shows Docker container health across all hosts
**Iframe Height**: 1500px

**Key Queries (PromQL)**:

```promql
# Count of running containers per host
count by (instance) (
  container_running{instance=~"$host"}
)

# Container CPU usage percentage
sum by (name) (
  rate(container_cpu_usage_seconds_total{instance=~"$host"}[5m])
) * 100

# Container memory usage in bytes
container_memory_usage_bytes{instance=~"$host"}
```

**Query Explanation**:
- `count by (instance)`: Count metrics grouped by host
- `container_running{instance=~"$host"}`: Filter by selected host variable
- `rate(...[5m])`: Calculate per-second rate over 5 minutes
- `sum by (name)`: Sum values grouped by container name

#### 2. Synology NAS Dashboard

**UID**: `synology-nas-modern`
**Purpose**: Monitor NAS storage, RAID health, CPU, temperatures
**Iframe Height**: 1350px

**RAID Status Panels** (Added January 8, 2026):

The dashboard includes RAID array health monitoring, which is different from individual disk health:

| Panel | Metric | Description |
|-------|--------|-------------|
| RAID Status | `synologyRaidStatus{raidIndex="0"}` | Storage Pool 1 (HDD array) |
| SSD Cache Status | `synologyRaidStatus{raidIndex="1"}` | SSD Cache Pool |

**RAID Status Values**:
| Value | Status | Color |
|-------|--------|-------|
| 1 | Normal | Green |
| 2 | REPAIRING | Orange |
| 7 | SYNCING | Blue |
| 11 | DEGRADED | Red |
| 12 | CRASHED | Red |

> **Why RAID Status Matters**: Individual disk health (`synologyDiskHealthStatus`) only shows per-disk SMART status. A degraded RAID can have all disks showing "Healthy" while the array rebuilds. RAID status (`synologyRaidStatus`) shows the true array-level health.

**Key Queries (PromQL)**:

```promql
# RAID array status
synologyRaidStatus{job="synology", raidIndex="0"}

# Disk usage percentage
100 - (
  (hrStorageSize{instance="192.168.20.31"} - hrStorageUsed{instance="192.168.20.31"})
  / hrStorageSize{instance="192.168.20.31"}
  * 100
)

# CPU load average
hrProcessorLoad{instance="192.168.20.31"}

# System temperature
synologySystemTemperature{instance="192.168.20.31"}

# Volume used space (TB)
(hrStorageUsed * hrStorageAllocationUnits) / 1099511627776
```

**Query Explanation**:
- `synologyRaidStatus`: Synology RAID array status (1=Normal, 2=Repairing, 7=Syncing, 11=Degraded, 12=Crashed)
- `hrStorage*`: SNMP metrics from Host Resources MIB
- `synologySystemTemperature`: Synology-specific SNMP OID
- Division by 1099511627776: Convert bytes to terabytes (1024^4)

#### 3. Omada Network Dashboard

**UID**: `omada-network`
**Purpose**: Network device status, bandwidth, client count
**Iframe Height**: 2200px

### Updating Grafana

Grafana is auto-updated by Watchtower (see [Section 7](#7-deployment-workflows)). To manually update:

```bash
# SSH to docker-vm-core-utilities01
ssh hermes-admin@192.168.40.13

# Navigate to monitoring directory
cd /opt/monitoring

# Pull latest image and recreate
docker compose pull grafana
docker compose up -d grafana

# Verify version
docker exec grafana grafana-cli version
```

### Backup Grafana

```bash
# Backup dashboards and settings
tar -czvf grafana-backup-$(date +%Y%m%d).tar.gz \
  /opt/monitoring/grafana/data \
  /opt/monitoring/grafana/provisioning \
  /opt/monitoring/grafana/dashboards
```

---

## 4.2 Prometheus Configuration

### What is Prometheus?

**Prometheus** is a time-series database designed for monitoring. It:
- Scrapes metrics from targets at configured intervals
- Stores data efficiently with compression
- Provides PromQL query language
- Integrates with alerting via Alertmanager

### Current Deployment

| Property | Value |
|----------|-------|
| **Host** | docker-vm-core-utilities01 (192.168.40.13) |
| **Port** | 9090 |
| **Retention** | 30 days |
| **URL** | https://prometheus.hrmsmrflrii.xyz |

### Complete prometheus.yml Configuration

```yaml
# /opt/monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s         # How often to scrape targets
  evaluation_interval: 15s     # How often to evaluate rules
  external_labels:
    cluster: 'homelab'
    env: 'production'

scrape_configs:
  # ============================================
  # SELF-MONITORING
  # ============================================
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'prometheus'

  # ============================================
  # PROXMOX CLUSTER (via PVE Exporter)
  # ============================================
  - job_name: 'proxmox'
    static_configs:
      - targets:
        - 192.168.20.20:8006  # node01
        - 192.168.20.21:8006  # node02
    metrics_path: /pve
    params:
      module: [default]
      cluster: ['1']
      node: ['1']
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: pve-exporter:9221

  # ============================================
  # DOCKER CONTAINERS (via docker-stats-exporter)
  # ============================================
  - job_name: 'docker-stats-utilities'
    static_configs:
      - targets: ['192.168.40.13:9417']
        labels:
          host: 'docker-vm-core-utilities01'

  - job_name: 'docker-stats-media'
    static_configs:
      - targets: ['192.168.40.11:9417']
        labels:
          host: 'docker-lxc-media'

  # ============================================
  # TRAEFIK METRICS
  # ============================================
  - job_name: 'traefik'
    static_configs:
      - targets: ['192.168.40.20:8082']
        labels:
          instance: 'traefik-primary'
    metrics_path: /metrics

  # ============================================
  # SYNOLOGY NAS (via SNMP Exporter)
  # ============================================
  - job_name: 'synology'
    static_configs:
      - targets:
        - 192.168.20.31
    metrics_path: /snmp
    params:
      module: [synology]
      auth: [homelab_v2]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: snmp-exporter:9116

  # ============================================
  # OPNSENSE FIREWALL
  # ============================================
  - job_name: 'opnsense'
    static_configs:
      - targets: ['192.168.91.30:9198']
        labels:
          instance: 'opnsense'
    metrics_path: /metrics

  # ============================================
  # OPENTELEMETRY COLLECTOR
  # ============================================
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['192.168.40.13:8888']
        labels:
          instance: 'otel-collector'

  - job_name: 'otel-collector-pipeline'
    static_configs:
      - targets: ['192.168.40.13:8889']
        labels:
          instance: 'otel-pipeline'

  # ============================================
  # JAEGER TRACING
  # ============================================
  - job_name: 'jaeger'
    static_configs:
      - targets: ['192.168.40.13:14269']
        labels:
          instance: 'jaeger'
```

**Configuration Sections Explained**:

| Section | Purpose |
|---------|---------|
| `global.scrape_interval` | Default scrape frequency (15 seconds) |
| `external_labels` | Labels added to all metrics (cluster identification) |
| `job_name` | Logical grouping of similar targets |
| `static_configs` | Manually defined targets |
| `relabel_configs` | Transform labels before scraping |
| `metrics_path` | URL path to scrape (default: /metrics) |
| `params` | Query parameters to include in scrape request |

**Understanding Relabel Configs (SNMP Example)**:

```yaml
relabel_configs:
  - source_labels: [__address__]        # Take the target address
    target_label: __param_target         # Set it as ?target= parameter
  - source_labels: [__param_target]
    target_label: instance               # Use it as instance label
  - target_label: __address__
    replacement: snmp-exporter:9116      # Scrape the exporter instead
```

This tells Prometheus:
1. "I want to scrape 192.168.20.31"
2. "But actually, send the request to snmp-exporter:9116"
3. "Include ?target=192.168.20.31 in the request"
4. "Label the metrics with instance=192.168.20.31"

---

## 4.3 Uptime Kuma

### What is Uptime Kuma?

**Uptime Kuma** is a self-hosted monitoring tool similar to "Uptime Robot". It monitors:
- HTTP/HTTPS endpoints
- TCP ports
- DNS records
- Docker containers
- Database connections

### Current Deployment

| Property | Value |
|----------|-------|
| **Host** | docker-vm-core-utilities01 (192.168.40.13) |
| **Port** | 3001 |
| **URL** | https://uptime.hrmsmrflrii.xyz |

### Docker Compose Configuration

```yaml
# /opt/monitoring/docker-compose.yml (uptime-kuma section)
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - ./uptime-kuma:/app/data
    environment:
      - TZ=Asia/Manila
```

### Configured Monitors

| Service | Type | Check Interval | URL/Host |
|---------|------|----------------|----------|
| Glance | HTTP | 60s | https://glance.hrmsmrflrii.xyz |
| Grafana | HTTP | 60s | https://grafana.hrmsmrflrii.xyz |
| Traefik | HTTP | 60s | https://traefik.hrmsmrflrii.xyz |
| Jellyfin | HTTP | 60s | https://jellyfin.hrmsmrflrii.xyz |
| Proxmox node01 | HTTPS | 60s | https://192.168.20.20:8006 |
| Proxmox node02 | HTTPS | 60s | https://192.168.20.21:8006 |
| Pi-hole | HTTP | 60s | http://192.168.90.53/admin |
| Synology NAS | HTTPS | 60s | https://192.168.20.31:5001 |

---

# 5. Docker Services - Media Stack

## 5.1 The Arr Stack Architecture

### What is the Arr Stack?

The "Arr Stack" is a collection of applications that automate media library management:

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Media Automation Flow                         │
│                                                                  │
│  1. REQUEST                                                      │
│     ┌──────────────┐                                            │
│     │ Jellyseerr   │ ◄─── User requests a movie/show            │
│     │ (Requests)   │                                            │
│     └──────┬───────┘                                            │
│            │                                                     │
│  2. SEARCH & QUEUE                                              │
│            ▼                                                     │
│     ┌──────────────┐      ┌──────────────┐                     │
│     │   Radarr     │      │   Sonarr     │                     │
│     │  (Movies)    │      │ (TV Shows)   │                     │
│     └──────┬───────┘      └──────┬───────┘                     │
│            │                      │                             │
│            └──────────┬───────────┘                             │
│                       │                                          │
│  3. INDEXER SEARCH                                              │
│                       ▼                                          │
│              ┌──────────────┐                                   │
│              │  Prowlarr    │ ◄─── Manages indexers             │
│              │  (Indexers)  │      (Usenet/Torrent)             │
│              └──────┬───────┘                                   │
│                     │                                            │
│  4. DOWNLOAD                                                     │
│                     ▼                                            │
│     ┌──────────────┐      ┌──────────────┐                     │
│     │   SABnzbd    │      │   Deluge     │                     │
│     │  (Usenet)    │      │ (Torrents)   │                     │
│     └──────┬───────┘      └──────┬───────┘                     │
│            │                      │                             │
│            └──────────┬───────────┘                             │
│                       │                                          │
│  5. POST-PROCESSING                                             │
│                       ▼                                          │
│     ┌──────────────┐      ┌──────────────┐                     │
│     │   Radarr/    │      │   Bazarr     │                     │
│     │   Sonarr     │      │ (Subtitles)  │                     │
│     │ (Import)     │      │              │                     │
│     └──────┬───────┘      └──────────────┘                     │
│            │                                                     │
│  6. STREAMING                                                    │
│            ▼                                                     │
│     ┌──────────────┐                                            │
│     │  Jellyfin    │ ◄─── User watches content                  │
│     │ (Media Server│                                            │
│     └──────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

### Service Descriptions

| Service | Port | Purpose | Category |
|---------|:----:|---------|----------|
| **Jellyfin** | 8096 | Media streaming server | Media Server |
| **Radarr** | 7878 | Movie collection manager | PVR |
| **Sonarr** | 8989 | TV show collection manager | PVR |
| **Lidarr** | 8686 | Music collection manager | PVR |
| **Prowlarr** | 9696 | Indexer manager | Indexer |
| **Bazarr** | 6767 | Subtitle manager | Subtitles |
| **Jellyseerr** | 5056 | Media request platform | Requests |
| **Overseerr** | 5055 | Media request (Plex) | Requests |
| **Tdarr** | 8265 | Transcoding automation | Processing |
| **Deluge** | 8112 | Torrent client | Downloader |
| **SABnzbd** | 8081 | Usenet client | Downloader |

---

## 5.2 Migration from VM to LXC

### Why We Migrated

The media stack was originally on a full Ubuntu VM. We migrated to an LXC container for:

| Factor | VM | LXC |
|--------|-----|-----|
| **Boot Time** | ~45 seconds | ~2 seconds |
| **RAM Overhead** | ~1.5 GB (OS) | ~200 MB |
| **Disk Usage** | 20 GB base | 5 GB base |
| **Backup Size** | Large | Small |
| **Performance** | Good | Near-native |

### Migration Process

#### Step 1: Create LXC Container

```bash
# On Proxmox host (node01)
pct create 201 local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst \
  --hostname docker-lxc-media \
  --cores 4 \
  --memory 8192 \
  --rootfs local-lvm:50 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.40.11/24,gw=192.168.40.1,tag=40 \
  --features nesting=1,fuse=1 \
  --unprivileged 0 \
  --onboot 1
```

**Command Breakdown**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `201` | Container ID | Unique identifier |
| `local:vztmpl/...` | Template | Ubuntu 24.04 container template |
| `--hostname` | docker-lxc-media | Container hostname |
| `--cores 4` | CPU | 4 CPU cores |
| `--memory 8192` | RAM | 8 GB RAM |
| `--rootfs local-lvm:50` | Storage | 50 GB on local LVM |
| `--net0 ... ip=.../24` | Network | Static IP with VLAN tag |
| `--features nesting=1,fuse=1` | Docker support | Required for Docker inside LXC |
| `--unprivileged 0` | Privileged | Needed for Docker |
| `--onboot 1` | Auto-start | Start on Proxmox boot |

#### Step 2: Configure LXC for Docker

Edit `/etc/pve/lxc/201.conf`:

```conf
# Add these lines for Docker compatibility
features: nesting=1,fuse=1
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.mount.auto: proc:rw sys:rw
```

**Why These Settings**:

| Setting | Purpose |
|---------|---------|
| `nesting=1` | Allows containers inside container |
| `fuse=1` | Enables FUSE filesystem (overlay) |
| `apparmor.profile: unconfined` | Disables AppArmor restrictions |
| `cap.drop:` | Don't drop any capabilities |
| `mount.auto` | Allow proc/sys mounts |

#### Step 3: Install Docker

```bash
# Enter the LXC
pct enter 201

# Install Docker
apt update && apt upgrade -y
apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### Step 4: Mount NFS Media Storage

```bash
# Install NFS client
apt install -y nfs-common

# Create mount point
mkdir -p /mnt/media

# Add to fstab
echo "192.168.20.31:/volume2/Proxmox-Media /mnt/media nfs defaults,_netdev 0 0" >> /etc/fstab

# Mount
mount -a

# Verify
ls /mnt/media
# Should show: Movies  Series  Music  Downloads
```

#### Step 5: Copy Configuration from Old VM

```bash
# From the old VM, backup configs
tar -czvf arr-stack-backup.tar.gz /opt/arr-stack

# Copy to new LXC
scp arr-stack-backup.tar.gz root@192.168.40.11:/opt/

# On new LXC, extract
cd /opt
tar -xzvf arr-stack-backup.tar.gz
```

#### Step 6: Update Docker Compose for LXC

```yaml
# /opt/arr-stack/docker-compose.yml
# Added --security-opt apparmor=unconfined to all services

services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    security_opt:
      - apparmor=unconfined    # Required in LXC
    ports:
      - "8096:8096"
    volumes:
      - ./jellyfin/config:/config
      - ./jellyfin/cache:/cache
      - /mnt/media:/media:ro
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Manila
```

#### Step 7: Start Services

```bash
cd /opt/arr-stack
docker compose up -d

# Verify all containers running
docker ps
```

---

## 5.3 Service-by-Service Configuration

### Jellyfin

**What it is**: Open-source media server (like Plex but free)

**Current Version**: Latest (auto-updated)

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - Jellyfin section
jellyfin:
  image: jellyfin/jellyfin:latest
  container_name: jellyfin
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  ports:
    - "8096:8096"           # Web UI
    - "8920:8920"           # HTTPS (optional)
    - "7359:7359/udp"       # Local discovery
    - "1900:1900/udp"       # DLNA
  volumes:
    - ./jellyfin/config:/config          # Settings, database
    - ./jellyfin/cache:/cache            # Transcoding cache
    - /mnt/media/Movies:/media/movies:ro # Movies (read-only)
    - /mnt/media/Series:/media/tv:ro     # TV shows (read-only)
    - /mnt/media/Music:/media/music:ro   # Music (read-only)
  environment:
    - PUID=1000
    - PGID=1000
    - TZ=Asia/Manila
    - JELLYFIN_PublishedServerUrl=https://jellyfin.hrmsmrflrii.xyz
  devices:
    - /dev/dri:/dev/dri     # Hardware transcoding (Intel QuickSync)
```

**Dependencies**:
- NFS media mount
- Traefik for SSL termination
- Authentik for SSO (optional)

**Update Procedure**:
```bash
cd /opt/arr-stack
docker compose pull jellyfin
docker compose up -d jellyfin
```

### Radarr

**What it is**: Movie collection manager (automatic download/organization)

**How it works**:
1. You add a movie to Radarr
2. Radarr searches indexers (via Prowlarr) for releases
3. Sends download to SABnzbd/Deluge
4. Monitors for completion
5. Imports, renames, and organizes the file

**Configuration**:

```yaml
radarr:
  image: linuxserver/radarr:latest
  container_name: radarr
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  ports:
    - "7878:7878"
  volumes:
    - ./radarr:/config                     # Database, settings
    - /mnt/media/Movies:/movies            # Media library
    - /opt/arr-stack/downloads:/downloads  # Download directory
  environment:
    - PUID=1000
    - PGID=1000
    - TZ=Asia/Manila
```

**Key Settings** (in Radarr UI):
- Media Management → Root Folder: `/movies`
- Download Clients → Add SABnzbd (host: `sabnzbd`, port: `8080`)
- Download Clients → Add Deluge (host: `deluge`, port: `8112`)

**Dependencies**:
- Prowlarr (indexer management)
- SABnzbd or Deluge (download clients)
- NFS media mount

### Prowlarr

**What it is**: Indexer manager for all *arr apps

**How it works**:
1. You add indexers (Usenet/Torrent sites) to Prowlarr
2. Prowlarr syncs indexers to Radarr, Sonarr, Lidarr
3. When Radarr searches, it queries Prowlarr
4. Prowlarr queries all configured indexers
5. Returns aggregated results

**Configuration**:

```yaml
prowlarr:
  image: linuxserver/prowlarr:latest
  container_name: prowlarr
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  ports:
    - "9696:9696"
  volumes:
    - ./prowlarr:/config
  environment:
    - PUID=1000
    - PGID=1000
    - TZ=Asia/Manila
```

**Key Settings**:
- Settings → Apps → Add Radarr (URL: `http://radarr:7878`, API Key from Radarr)
- Settings → Apps → Add Sonarr (URL: `http://sonarr:8989`, API Key from Sonarr)
- Indexers → Add your preferred indexers

**Dependencies**:
- Network access to indexer sites
- API keys from Radarr/Sonarr

### Sonarr

**What it is**: TV series collection manager (automatic download/organization)

**How it works**:
1. You add a TV show to Sonarr
2. Sonarr monitors for new episodes via RSS or calendar
3. Searches indexers (via Prowlarr) when episodes air
4. Sends download to SABnzbd/Deluge
5. Imports, renames, and organizes episodes by season/episode

**Current Version**: Latest (linuxserver.io image)

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - Sonarr section
sonarr:
  image: lscr.io/linuxserver/sonarr:latest
  container_name: sonarr
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined    # Required in LXC environment
  environment:
    - PUID=1001              # User ID for file permissions
    - PGID=1001              # Group ID for file permissions
    - TZ=America/New_York    # Timezone for scheduling
  volumes:
    - /opt/arr-stack/sonarr:/config     # Database, settings, logs
    - /mnt/media/Series:/tv              # TV show library
    - /opt/arr-stack/downloads:/downloads # Download staging area
  ports:
    - "8989:8989"            # Web UI
  networks:
    - arr-network
```

**Line-by-Line Explanation**:

| Line | Purpose |
|------|---------|
| `image: lscr.io/linuxserver/sonarr:latest` | Uses LinuxServer.io image (well-maintained, regular updates) |
| `security_opt: apparmor=unconfined` | Disables AppArmor restrictions needed for Docker-in-LXC |
| `PUID=1001` | Run as user ID 1001 (hermes-admin) for NFS permission compatibility |
| `/config` volume | Stores Sonarr database (SQLite), settings, indexer configs |
| `/tv` volume | Maps to NFS-mounted TV series directory |
| `/downloads` volume | Where completed downloads land before import |
| Port `8989` | Default Sonarr web interface |

**Key Settings** (in Sonarr UI):

| Setting | Location | Value |
|---------|----------|-------|
| Root Folder | Media Management | `/tv` |
| Download Client | Download Clients | SABnzbd: `sabnzbd:8080` |
| Download Client | Download Clients | Deluge: `deluge:8112` |
| Episode Naming | Media Management | `{Series Title} - S{season:00}E{episode:00} - {Episode Title}` |

**Update Procedure**:
```bash
cd /opt/arr-stack
docker compose pull sonarr
docker compose up -d sonarr
# Check logs for any issues
docker logs sonarr --tail 50
```

**Dependencies**:
- Prowlarr (indexer management)
- SABnzbd or Deluge (download clients)
- NFS media mount

---

### Lidarr

**What it is**: Music collection manager (automatic download/organization)

**How it works**:
1. Add artists to Lidarr's library
2. Lidarr searches indexers for albums
3. Downloads via SABnzbd/Deluge
4. Imports, tags, and organizes music files

**Current Version**: Latest (linuxserver.io image)

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - Lidarr section
lidarr:
  image: lscr.io/linuxserver/lidarr:latest
  container_name: lidarr
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  environment:
    - PUID=1001
    - PGID=1001
    - TZ=America/New_York
  volumes:
    - /opt/arr-stack/lidarr:/config
    - /mnt/media/Music:/music
    - /opt/arr-stack/downloads:/downloads
  ports:
    - "8686:8686"
  networks:
    - arr-network
```

**Key Settings** (in Lidarr UI):

| Setting | Value | Purpose |
|---------|-------|---------|
| Root Folder | `/music` | Base directory for music library |
| Track Naming | `{Artist Name}/{Album Title}/{track:00} - {Track Title}` | Organize by artist/album |
| Metadata Profile | Standard | What metadata to require |

**Update Procedure**:
```bash
cd /opt/arr-stack
docker compose pull lidarr
docker compose up -d lidarr
```

**Dependencies**:
- Prowlarr (indexer management)
- SABnzbd or Deluge (download clients)
- NFS media mount for Music directory

---

### Bazarr

**What it is**: Subtitle manager for movies and TV shows

**How it works**:
1. Connects to Radarr/Sonarr to get library information
2. Searches subtitle providers (OpenSubtitles, Subscene, etc.)
3. Downloads matching subtitles automatically
4. Supports multiple languages and hearing-impaired versions

**Current Version**: Latest (linuxserver.io image)

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - Bazarr section
bazarr:
  image: lscr.io/linuxserver/bazarr:latest
  container_name: bazarr
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  environment:
    - PUID=1001
    - PGID=1001
    - TZ=America/New_York
  volumes:
    - /opt/arr-stack/bazarr:/config
    # Needs direct access to media to match subtitles to files
    - /mnt/media/Movies:/movies
    - /mnt/media/Series:/tv
  ports:
    - "6767:6767"
  networks:
    - arr-network
```

**Line-by-Line Explanation**:

| Volume | Purpose |
|--------|---------|
| `/config` | Bazarr database, settings, subtitle provider credentials |
| `/movies` | Direct access to movies for subtitle matching |
| `/tv` | Direct access to TV shows for subtitle matching |

**Key Settings** (in Bazarr UI):

| Setting | Location | Value |
|---------|----------|-------|
| Radarr Connection | Settings → Radarr | URL: `http://radarr:7878`, API key from Radarr |
| Sonarr Connection | Settings → Sonarr | URL: `http://sonarr:8989`, API key from Sonarr |
| Languages | Settings → Languages | English, Filipino (or your preferences) |
| Providers | Settings → Providers | OpenSubtitles, Subscene, BSPlayer |

**Update Procedure**:
```bash
cd /opt/arr-stack
docker compose pull bazarr
docker compose up -d bazarr
```

**Dependencies**:
- Radarr (to know what movies exist)
- Sonarr (to know what TV shows exist)
- NFS media mount (to read/write subtitle files)

---

### Jellyseerr

**What it is**: Media request platform for Jellyfin users

**How it works**:
1. Users browse available content or search for new titles
2. Submit requests for movies or TV shows
3. Jellyseerr sends request to Radarr/Sonarr
4. Radarr/Sonarr handle the download automatically
5. Jellyseerr tracks status and notifies users

**Current Version**: Latest (fallenbagel image)

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - Jellyseerr section
jellyseerr:
  image: fallenbagel/jellyseerr:latest
  container_name: jellyseerr
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  environment:
    - PUID=1001
    - PGID=1001
    - TZ=America/New_York
  volumes:
    - /opt/arr-stack/jellyseerr:/app/config
  ports:
    - "5056:5055"        # Map to 5056 to avoid conflict with Overseerr
  networks:
    - arr-network
```

**Key Settings** (in Jellyseerr UI):

| Setting | Value | Purpose |
|---------|-------|---------|
| Jellyfin URL | `http://jellyfin:8096` | Connect to Jellyfin for library sync |
| Radarr Server | `http://radarr:7878` | Send movie requests |
| Sonarr Server | `http://sonarr:8989` | Send TV requests |
| Request Limits | 10 movies/week, 5 series/week | Prevent abuse |

**User Management**:
- Integrates with Jellyfin users
- Supports custom request quotas per user
- Can import Jellyfin user list automatically

**Update Procedure**:
```bash
cd /opt/arr-stack
docker compose pull jellyseerr
docker compose up -d jellyseerr
```

**Dependencies**:
- Jellyfin (for user authentication and library)
- Radarr (for movie requests)
- Sonarr (for TV requests)

---

### Overseerr

**What it is**: Media request platform for Plex users (alternative to Jellyseerr)

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - Overseerr section
overseerr:
  image: lscr.io/linuxserver/overseerr:latest
  container_name: overseerr
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  environment:
    - PUID=1001
    - PGID=1001
    - TZ=America/New_York
  volumes:
    - /opt/arr-stack/overseerr:/config
  ports:
    - "5055:5055"
  networks:
    - arr-network
```

> **Note**: We run both Jellyseerr (for Jellyfin) and Overseerr (for Plex) since we have both media servers.

---

### Tdarr

**What it is**: Distributed transcoding automation system

**How it works**:
1. Scans media libraries for files
2. Analyzes codecs, containers, and quality
3. Applies transcoding rules (e.g., convert to H.265)
4. Can run multiple worker nodes for parallel processing
5. Reduces storage usage while maintaining quality

**Current Version**: Latest (ghcr.io/haveagitgat/tdarr)

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - Tdarr section
tdarr:
  image: ghcr.io/haveagitgat/tdarr:latest
  container_name: tdarr
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  environment:
    - PUID=1001
    - PGID=1001
    - TZ=America/New_York
    - UMASK_SET=002
    - serverIP=0.0.0.0          # Listen on all interfaces
    - serverPort=8266           # Server communication port
    - webUIPort=8265            # Web interface port
    - internalNode=true         # Run a worker node in this container
    - inContainer=true          # Indicates running in Docker
    - ffmpegVersion=6           # FFmpeg version to use
    - nodeName=InternalNode     # Name for the built-in worker
  volumes:
    - /opt/arr-stack/tdarr/server:/app/server     # Server data
    - /opt/arr-stack/tdarr/configs:/app/configs   # Configuration files
    - /opt/arr-stack/tdarr/logs:/app/logs         # Log files
    - /opt/arr-stack/tdarr/transcode_cache:/temp  # Temporary transcoding space
    - /mnt/media/Movies:/media/movies             # Movie library
    - /mnt/media/Series:/media/tvshows            # TV library
  ports:
    - "8265:8265"    # Web UI
    - "8266:8266"    # Server port (for external workers)
  networks:
    - arr-network
```

**Line-by-Line Explanation**:

| Setting | Purpose |
|---------|---------|
| `serverIP=0.0.0.0` | Allow connections from external worker nodes |
| `internalNode=true` | Run a transcoding worker within the server container |
| `ffmpegVersion=6` | Use FFmpeg 6 for latest codec support (AV1, etc.) |
| `/temp` volume | Fast storage for transcoding temp files (SSD recommended) |

**Key Settings** (in Tdarr UI):

| Setting | Recommendation | Purpose |
|---------|---------------|---------|
| Library | Add `/media/movies` and `/media/tvshows` | Define what to scan |
| Transcode Plugin | Tdarr_Plugin_MC93_Migz2ConvertToH265 | Convert to H.265 |
| Output Container | MKV | Preferred container format |
| Quality | CRF 20-22 | Balance quality vs size |

**Transcoding Flow**:
```text
┌─────────────────────────────────────────────────────┐
│              Tdarr Transcoding Pipeline              │
├─────────────────────────────────────────────────────┤
│  1. SCAN                                             │
│     └── Scan library directories for media files    │
│                                                      │
│  2. ANALYZE                                          │
│     └── Check codec, resolution, bitrate            │
│                                                      │
│  3. FILTER                                           │
│     └── Apply rules (e.g., "if H.264, transcode")   │
│                                                      │
│  4. QUEUE                                            │
│     └── Add to transcode queue                      │
│                                                      │
│  5. TRANSCODE                                        │
│     └── Worker processes file with FFmpeg           │
│                                                      │
│  6. REPLACE                                          │
│     └── Replace original with transcoded version    │
└─────────────────────────────────────────────────────┘
```

**Update Procedure**:
```bash
cd /opt/arr-stack
docker compose pull tdarr
docker compose up -d tdarr
```

**Dependencies**:
- NFS media mount
- Sufficient temp storage for transcoding
- CPU power for transcoding (or GPU for hardware acceleration)

---

### Autobrr

**What it is**: IRC announce channel monitor and torrent automation

**How it works**:
1. Connects to private tracker IRC announce channels
2. Monitors for new releases in real-time
3. Applies filters (resolution, codec, release group)
4. Instantly grabs releases before they appear on indexers
5. Sends to Deluge/qBittorrent

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - Autobrr section
autobrr:
  image: ghcr.io/autobrr/autobrr:latest
  container_name: autobrr
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  environment:
    - PUID=1001
    - PGID=1001
    - TZ=America/New_York
  volumes:
    - /opt/arr-stack/autobrr:/config
  ports:
    - "7474:7474"
  networks:
    - arr-network
```

**Use Case**: For users with private tracker access who want instant releases before they appear on general indexers.

---

### Deluge

**What it is**: BitTorrent client for downloading torrents

**How it works**:
1. Receives torrents from Radarr/Sonarr/Lidarr
2. Downloads files to staging directory
3. Notifies *arr apps when complete
4. *arr apps import and organize files

**Current Version**: Latest (linuxserver.io image)

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - Deluge section
deluge:
  image: lscr.io/linuxserver/deluge:latest
  container_name: deluge
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  environment:
    - PUID=1001
    - PGID=1001
    - TZ=America/New_York
    - DELUGE_LOGLEVEL=error    # Reduce log verbosity
  volumes:
    - /opt/arr-stack/deluge:/config
    - /opt/arr-stack/downloads:/downloads
  ports:
    - "8112:8112"              # Web UI
    - "6881:6881"              # Incoming peer connections
    - "6881:6881/udp"          # UDP connections (DHT)
  networks:
    - arr-network
```

**Line-by-Line Explanation**:

| Port | Purpose |
|------|---------|
| `8112` | Web UI for managing downloads |
| `6881` | BitTorrent peer connections (TCP) |
| `6881/udp` | DHT (Distributed Hash Table) for peer discovery |

**Key Settings** (in Deluge UI):

| Setting | Value | Purpose |
|---------|-------|---------|
| Default Password | `deluge` | **CHANGE IMMEDIATELY!** |
| Download Location | `/downloads/torrents` | Where files download |
| Move Completed | `/downloads/complete` | Post-download location |

**Update Procedure**:
```bash
cd /opt/arr-stack
docker compose pull deluge
docker compose up -d deluge
```

**Dependencies**:
- Local downloads directory
- Incoming port access (6881 for external peers)

---

### SABnzbd

**What it is**: Usenet download client for NZB files

**How it works**:
1. Receives NZB files from Radarr/Sonarr/Lidarr
2. Downloads from Usenet servers
3. Verifies and repairs with PAR2
4. Extracts archives (RAR)
5. Notifies *arr apps when complete

**Current Version**: Latest (linuxserver.io image)

**Configuration**:

```yaml
# /opt/arr-stack/docker-compose.yml - SABnzbd section
sabnzbd:
  image: lscr.io/linuxserver/sabnzbd:latest
  container_name: sabnzbd
  restart: unless-stopped
  security_opt:
    - apparmor=unconfined
  environment:
    - PUID=1001
    - PGID=1001
    - TZ=America/New_York
  volumes:
    - /opt/arr-stack/sabnzbd:/config
    - /opt/arr-stack/downloads:/downloads
  ports:
    - "8081:8080"    # Map to 8081 to avoid port conflict
  networks:
    - arr-network
```

**Key Settings** (in SABnzbd Setup Wizard):

| Setting | Value | Purpose |
|---------|-------|---------|
| Usenet Server | Your provider (Newshosting, etc.) | Where to download from |
| Connections | 10-20 | Parallel download connections |
| SSL | Enabled (port 563) | Encrypted downloads |
| Temporary Folder | `/downloads/incomplete` | Download staging |
| Completed Folder | `/downloads/complete` | Finished downloads |

**Usenet vs Torrents**:

| Feature | Usenet | Torrents |
|---------|--------|----------|
| Speed | Very fast (max connection) | Varies by seeders |
| Reliability | High (redundant servers) | Depends on availability |
| Privacy | Requires SSL, provider logs | DHT exposure |
| Cost | $10-15/month subscription | Free |

**Update Procedure**:
```bash
cd /opt/arr-stack
docker compose pull sabnzbd
docker compose up -d sabnzbd
```

**Dependencies**:
- Usenet server subscription
- Local downloads directory

---

## 5.4 Complete Docker Compose File

For reference, here's the complete `docker-compose.yml` used in the media stack:

```yaml
# /opt/arr-stack/docker-compose.yml
# Complete Arr Media Stack
# Generated by Ansible deployment playbook

version: "3.9"

services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
    volumes:
      - ./jellyfin/config:/config
      - ./jellyfin/cache:/cache
      - /mnt/media/Movies:/data/movies:ro
      - /mnt/media/Series:/data/tvshows:ro
    ports:
      - 8096:8096
      - 8920:8920
      - 7359:7359/udp
      - 1900:1900/udp
    networks:
      - arr-network

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
    volumes:
      - ./radarr:/config
      - /mnt/media/Movies:/movies
      - ./downloads:/downloads
    ports:
      - 7878:7878
    networks:
      - arr-network

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
    volumes:
      - ./sonarr:/config
      - /mnt/media/Series:/tv
      - ./downloads:/downloads
    ports:
      - 8989:8989
    networks:
      - arr-network

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
    volumes:
      - ./prowlarr:/config
    ports:
      - 9696:9696
    networks:
      - arr-network

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
    volumes:
      - ./bazarr:/config
      - /mnt/media/Movies:/movies
      - /mnt/media/Series:/tv
    ports:
      - 6767:6767
    networks:
      - arr-network

  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
    volumes:
      - ./jellyseerr:/app/config
    ports:
      - 5056:5055
    networks:
      - arr-network

  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: lidarr
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
    volumes:
      - ./lidarr:/config
      - /mnt/media/Music:/music
      - ./downloads:/downloads
    ports:
      - 8686:8686
    networks:
      - arr-network

  tdarr:
    image: ghcr.io/haveagitgat/tdarr:latest
    container_name: tdarr
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
      - UMASK_SET=002
      - serverIP=0.0.0.0
      - serverPort=8266
      - webUIPort=8265
      - internalNode=true
      - inContainer=true
      - ffmpegVersion=6
      - nodeName=InternalNode
    volumes:
      - ./tdarr/server:/app/server
      - ./tdarr/configs:/app/configs
      - ./tdarr/logs:/app/logs
      - ./tdarr/transcode_cache:/temp
      - /mnt/media/Movies:/media/movies
      - /mnt/media/Series:/media/tvshows
    ports:
      - 8265:8265
      - 8266:8266
    networks:
      - arr-network

  deluge:
    image: lscr.io/linuxserver/deluge:latest
    container_name: deluge
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
      - DELUGE_LOGLEVEL=error
    volumes:
      - ./deluge:/config
      - ./downloads:/downloads
    ports:
      - 8112:8112
      - 6881:6881
      - 6881:6881/udp
    networks:
      - arr-network

  sabnzbd:
    image: lscr.io/linuxserver/sabnzbd:latest
    container_name: sabnzbd
    restart: unless-stopped
    environment:
      - PUID=1001
      - PGID=1001
      - TZ=America/New_York
    volumes:
      - ./sabnzbd:/config
      - ./downloads:/downloads
    ports:
      - 8081:8080
    networks:
      - arr-network

networks:
  arr-network:
    driver: bridge
```

---

## 5.5 Glance Dashboard

### What is Glance?

**Glance** is a self-hosted dashboard that provides a unified view of:
- Service health monitoring
- API integrations (stocks, weather, sports)
- Custom widgets with templates
- Embedded Grafana dashboards
- RSS feeds and more

**Current Version**: Latest (glanceapp/glance)

**Location**: docker-lxc-glance (192.168.40.12)

### Configuration

**Docker Compose**:

```yaml
# /opt/glance/docker-compose.yml
services:
  glance:
    image: glanceapp/glance:latest
    container_name: glance
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./config:/app/config      # Configuration directory
      - ./assets:/app/assets:ro   # Custom CSS and assets
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    env_file:
      - .env                      # API keys and secrets
    environment:
      - TZ=America/New_York
```

**Configuration File Structure**:

```yaml
# /opt/glance/config/glance.yml
server:
  port: 8080
  assets-path: /app/assets

theme:
  background-color: 240 21 15    # HSL values
  contrast-multiplier: 1.2
  primary-color: 267 84 81
  positive-color: 115 54 76
  negative-color: 343 81 75
  custom-css-file: /app/assets/custom-themes.css

  presets:
    midnight-blue:
      background-color: 213 58 10
      primary-color: 227 95 67
    nord:
      background-color: 220 16 22
      primary-color: 193 43 67
    # ... more themes

pages:
  - name: Home
    columns:
      - size: small
        widgets:
          - type: clock
          - type: weather
          - type: bookmarks
      - size: full
        widgets:
          - type: monitor
          - type: custom-api
      - size: small
        widgets:
          - type: markets
          - type: rss
```

### Widget Types

| Widget | Purpose | Example Use |
|--------|---------|-------------|
| `clock` | Display time with timezone | Manila time |
| `weather` | Weather forecast | Manila weather |
| `bookmarks` | Grouped links | Infrastructure links |
| `monitor` | Service health checks | Proxmox, services |
| `custom-api` | Custom API with templates | Life Progress, Arr Queue |
| `markets` | Stock/crypto prices | BTC, MSFT |
| `rss` | RSS feed reader | r/homelab, tech news |
| `iframe` | Embed external content | Grafana dashboards |

### Custom API Widget Example

The Life Progress widget demonstrates custom-api usage:

```yaml
- type: custom-api
  title: Life Progress
  cache: 1h
  url: http://192.168.40.10:5051/progress
  template: |
    <div style="padding: 10px;">
      <div style="text-align: center; margin-bottom: 15px;">
        <span style="color: #f87171; font-weight: 600;">
          {{ .JSON.Int "remaining_days" | formatNumber }}
        </span>
        <span style="color: #888;"> days remaining</span>
      </div>
      <div style="display: flex; align-items: center; margin-bottom: 12px;">
        <span style="width: 60px; font-weight: bold;">Year</span>
        <div style="flex: 1; height: 24px; background: #333; border-radius: 4px;">
          <div style="width: {{ .JSON.Float "year" }}%; height: 100%; background: #ef4444;"></div>
        </div>
        <span style="width: 50px; text-align: right;">{{ .JSON.Float "year" | printf "%.0f" }}%</span>
      </div>
    </div>
```

**Template Syntax**:

| Syntax | Purpose |
|--------|---------|
| `{{ .JSON.String "key" }}` | Get string from JSON response |
| `{{ .JSON.Int "key" }}` | Get integer from JSON |
| `{{ .JSON.Float "key" }}` | Get float from JSON |
| `{{ .JSON.Array "key" }}` | Iterate over array |
| `{{ range .items }}...{{ end }}` | Loop over items |
| `| formatNumber` | Format with commas |
| `| printf "%.0f"` | Format float precision |

### Monitor Widget Example

```yaml
- type: monitor
  title: Service Health
  cache: 1m
  sites:
    - title: Proxmox Node 01
      url: https://192.168.20.20:8006
      icon: si:proxmox
      allow-insecure: true
    - title: Traefik
      url: http://192.168.40.20:8082/ping
      icon: si:traefikproxy
    - title: Jellyfin
      url: http://192.168.40.11:8096/health
      icon: si:jellyfin
```

### Embedded Grafana Dashboard

```yaml
- type: iframe
  title: Synology NAS Dashboard
  source: https://grafana.hrmsmrflrii.xyz/d/synology-nas/synology-nas?orgId=1&kiosk&refresh=30s
  height: 800
```

**URL Parameters**:
- `&kiosk` - Hide Grafana navigation
- `&refresh=30s` - Auto-refresh interval
- `&orgId=1` - Grafana organization

### Environment Variables

```bash
# /opt/glance/.env
RADARR_API_KEY=your_radarr_api_key_here
SONARR_API_KEY=your_sonarr_api_key_here
OPNSENSE_API_CREDENTIALS=your_base64_encoded_credentials
```

Use in config:
```yaml
headers:
  X-Api-Key: "${RADARR_API_KEY}"
```

### Update Procedure

```bash
cd /opt/glance
docker compose pull
docker compose up -d
# Config changes don't require restart - watched automatically
```

---

# 6. Ansible Automation

## 6.1 Installing Ansible

### On the Ansible Controller

```bash
# Install Ansible on Ubuntu
apt update
apt install -y software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt install -y ansible

# Verify installation
ansible --version
# ansible [core 2.16.x]
```

### Install Required Collections

```bash
# Install community collections
ansible-galaxy collection install community.docker
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix

# For Windows management (Azure AD)
ansible-galaxy collection install ansible.windows
pip install pywinrm
```

---

## 6.2 Inventory Structure

### Main Inventory File

```ini
# /home/hermes-admin/ansible/inventory.ini

[all:vars]
ansible_user=hermes-admin
ansible_ssh_private_key_file=~/.ssh/homelab_ed25519
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'

# ============================================
# KUBERNETES CLUSTER
# ============================================
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

[k8s_cluster:children]
k8s_controllers
k8s_workers

[k8s_cluster:vars]
k8s_version=1.28.0-1.1
containerd_version=1.7.13-1

# ============================================
# DOCKER HOSTS
# ============================================
[docker_utilities]
docker-vm-core-utilities01 ansible_host=192.168.40.13

[docker_media]
docker-lxc-media ansible_host=192.168.40.11

[docker_glance]
docker-lxc-glance ansible_host=192.168.40.12

[docker_hosts:children]
docker_utilities
docker_media
docker_glance

# ============================================
# SERVICE VMS
# ============================================
[reverse_proxy]
traefik-vm01 ansible_host=192.168.40.20

[identity]
authentik-vm01 ansible_host=192.168.40.21

[code_hosting]
gitlab-vm01 ansible_host=192.168.40.23

[photos]
immich-vm01 ansible_host=192.168.40.22

# ============================================
# PROXMOX NODES (use root)
# ============================================
[proxmox_nodes]
node01 ansible_host=192.168.20.20 ansible_user=root
node02 ansible_host=192.168.20.21 ansible_user=root
```

### Inventory Variables Explained

| Variable | Purpose |
|----------|---------|
| `ansible_user` | SSH username for connections |
| `ansible_host` | IP address of target |
| `ansible_ssh_private_key_file` | Path to SSH private key |
| `ansible_ssh_common_args` | Extra SSH arguments |
| `[group:children]` | Nested groups |
| `[group:vars]` | Variables for all hosts in group |

---

## 6.3 How Ansible Connects

### Connection Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Ansible Connection Flow                       │
│                                                                  │
│  ┌──────────────┐                                               │
│  │   Ansible    │                                               │
│  │  Controller  │                                               │
│  │192.168.20.30 │                                               │
│  └──────┬───────┘                                               │
│         │                                                        │
│         │ 1. Read inventory.ini                                  │
│         │ 2. For each target host:                               │
│         │    a. Establish SSH connection                         │
│         │    b. Copy Python modules to target                    │
│         │    c. Execute modules                                  │
│         │    d. Return results                                   │
│         │    e. Clean up temporary files                         │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Target Host  │  │ Target Host  │  │ Target Host  │          │
│  │192.168.40.11 │  │192.168.40.13 │  │192.168.40.20 │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

### SSH Key Setup

```bash
# On Ansible controller, generate key (if not exists)
ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519 -N ""

# Copy public key to all targets
for host in 192.168.40.{11,12,13,20,21,22,23}; do
  ssh-copy-id -i ~/.ssh/homelab_ed25519.pub hermes-admin@$host
done

# Test connectivity
ansible all -m ping
```

### Testing Connectivity

```bash
# Ping all hosts
ansible all -m ping

# Expected output:
# docker-vm-core-utilities01 | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }

# Check specific group
ansible docker_hosts -m ping

# Run command on all hosts
ansible all -a "uptime"
```

---

# 7. Deployment Workflows

## 7.1 Complete Deployment Flow

### New Service Deployment Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│                  Complete Service Deployment                     │
│                                                                  │
│  ┌─────────────┐                                                │
│  │ 1. Terraform│ Create VM/LXC infrastructure                   │
│  │    apply    │ → Creates new VM with cloud-init               │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ 2. Ansible  │ Install Docker, configure host                 │
│  │  playbook   │ → install-docker.yml                           │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ 3. Ansible  │ Deploy application                             │
│  │  playbook   │ → deploy-<service>.yml                         │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ 4. DNS      │ Add record to Pi-hole                          │
│  │  update     │ → *.hrmsmrflrii.xyz → 192.168.40.20            │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ 5. Traefik  │ Add route to dynamic config                    │
│  │  config     │ → services.yml                                 │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ 6. Authentik│ Create provider & application                  │
│  │  config     │ → Forward Auth protection                      │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ 7. Update   │ Add monitor, dashboard bookmark                │
│  │  monitoring │ → Uptime Kuma, Glance                          │
│  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7.2 Authentik Integration

### What is Authentik?

**Authentik** is a self-hosted identity provider (IdP) that provides:
- Single Sign-On (SSO)
- OAuth2/OIDC provider
- SAML provider
- Forward Authentication (for Traefik)

### Forward Auth Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│                  Forward Authentication Flow                     │
│                                                                  │
│  1. User requests https://grafana.hrmsmrflrii.xyz               │
│                      │                                           │
│                      ▼                                           │
│  2. Traefik receives request                                     │
│     - Checks middlewares                                         │
│     - Finds "authentik-auth" middleware                          │
│                      │                                           │
│                      ▼                                           │
│  3. Traefik forwards auth check to Authentik                     │
│     GET https://auth.hrmsmrflrii.xyz/outpost.goauthentik.io/...  │
│                      │                                           │
│              ┌───────┴────────┐                                  │
│              │                │                                  │
│              ▼                ▼                                  │
│  4a. User has valid     4b. User NOT                            │
│      session cookie         authenticated                        │
│              │                │                                  │
│              │                ▼                                  │
│              │         5. Redirect to                            │
│              │            Authentik login                        │
│              │                │                                  │
│              │                ▼                                  │
│              │         6. User logs in                           │
│              │            (password/SSO)                         │
│              │                │                                  │
│              │                ▼                                  │
│              │         7. Redirect back                          │
│              │            with session                           │
│              │                │                                  │
│              └────────┬───────┘                                  │
│                       │                                          │
│                       ▼                                          │
│  8. Traefik forwards request to Grafana                          │
│     (includes user headers from Authentik)                       │
│                       │                                          │
│                       ▼                                          │
│  9. Grafana responds, user sees dashboard                        │
└─────────────────────────────────────────────────────────────────┘
```

### Traefik Configuration for Forward Auth

```yaml
# /opt/traefik/config/dynamic/middlewares.yml
http:
  middlewares:
    # Authentik Forward Authentication Middleware
    authentik-auth:
      forwardAuth:
        address: http://192.168.40.21:9000/outpost.goauthentik.io/auth/traefik
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
```

**Configuration Breakdown**:

| Setting | Purpose |
|---------|---------|
| `address` | Authentik outpost endpoint for auth checks |
| `trustForwardHeader` | Trust X-Forwarded-* headers |
| `authResponseHeaders` | Headers to pass to backend service |

### Adding Forward Auth to a Service

**Step 1**: Create Application in Authentik

1. Navigate to Authentik → Applications → Create
2. **Name**: Grafana
3. **Slug**: grafana
4. **Provider**: Create new Proxy Provider
   - Type: Forward auth (single application)
   - External host: https://grafana.hrmsmrflrii.xyz

**Step 2**: Add Middleware to Traefik Route

```yaml
# /opt/traefik/config/dynamic/services.yml
http:
  routers:
    grafana:
      rule: "Host(`grafana.hrmsmrflrii.xyz`)"
      service: grafana
      entryPoints:
        - websecure
      middlewares:
        - authentik-auth      # <-- Add this line
      tls:
        certResolver: letsencrypt

  services:
    grafana:
      loadBalancer:
        servers:
          - url: "http://192.168.40.13:3030"
```

**Step 3**: Reload Traefik

```bash
# Traefik watches file changes automatically
# Or restart container
ssh traefik "cd /opt/traefik && docker compose restart traefik"
```

---

## 7.3 Service Dependencies

### Dependency Matrix

| Service | Depends On | Must Start First |
|---------|-----------|------------------|
| **Traefik** | DNS (Pi-hole), SSL certs | - |
| **Authentik** | Traefik, PostgreSQL, Redis | PostgreSQL, Redis |
| **Grafana** | Prometheus, Traefik | Prometheus |
| **Prometheus** | Exporters (PVE, SNMP) | - |
| **Jellyfin** | NFS mount, Traefik | NFS |
| **Radarr** | Prowlarr, SABnzbd/Deluge | Prowlarr |
| **Sonarr** | Prowlarr, SABnzbd/Deluge | Prowlarr |
| **Jellyseerr** | Jellyfin, Radarr, Sonarr | Jellyfin |
| **Glance** | All APIs, Grafana | APIs |

### Startup Order

For a complete system restart, services should start in this order:

1. **Infrastructure Layer**
   - DNS (Pi-hole)
   - NFS (Synology NAS)
   - Proxmox nodes

2. **Network Layer**
   - Traefik (reverse proxy)

3. **Identity Layer**
   - Authentik (PostgreSQL, Redis first)

4. **Monitoring Layer**
   - Prometheus
   - Grafana
   - Uptime Kuma

5. **Application Layer**
   - Media stack (Prowlarr → Radarr/Sonarr → Jellyfin → Jellyseerr)
   - Other services

6. **Dashboard Layer**
   - Glance (depends on all above)

---

# 8. Storage Architecture

This section covers the production-grade NFS storage architecture used throughout the homelab.

## 8.1 Storage Design Philosophy

The storage architecture follows a key design principle:

> **One NFS export = One Proxmox storage pool**

This prevents "inactive storage" warnings in Proxmox and ensures clean separation between VM disks, ISOs, container configs, and media files.

### Why This Matters

| Issue | Cause | Solution |
|-------|-------|----------|
| Inactive storage warnings | Mixed content types | Dedicated exports |
| `?` icons in Proxmox UI | Non-standard content | Homogeneous storage pools |
| Template clone failures | Missing storage access | All storages on all nodes |
| LXC rootfs errors | Wrong storage type | App configs via bind mounts |
| Slow UI | Proxmox scanning large media | Media as manual mounts |

---

## 8.2 Synology NAS Configuration

The Synology DS920+ NAS (192.168.20.31) provides centralized storage for the cluster.

### NFS Exports

| Storage Pool | Export Path | Type | Content | Management |
|--------------|-------------|------|---------|------------|
| **VMDisks** | `/volume2/ProxmoxCluster-VMDisks` | NFS | VM disk images | Proxmox-managed |
| **ISOs** | `/volume2/ProxmoxCluster-ISOs` | NFS | ISO images | Proxmox-managed |
| **LXC Configs** | `/volume2/Proxmox-LXCs` | NFS | App configs | Manual mount |
| **Media** | `/volume2/Proxmox-Media` | NFS | Movies, Series, Music | Manual mount |
| **ProxmoxData** | `/volume2/ProxmoxData` | NFS | Immich photos (7TB) | Manual mount |

### Proxmox Storage Pools

**VMDisks Pool** - VM virtual disks with full Proxmox integration:
```
ID: VMDisks
Server: 192.168.20.31
Export: /volume2/ProxmoxCluster-VMDisks
Content: Disk image
Nodes: All nodes
```

**ISOs Pool** - Installation media:
```
ID: ISOs
Server: 192.168.20.31
Export: /volume2/ProxmoxCluster-ISOs
Content: ISO image
Nodes: All nodes
```

These pools enable live migration, snapshots, and high availability across the cluster.

---

## 8.3 Manual NFS Mounts

For container configs and media, manual mounts are used to avoid Proxmox scanning large directories.

### Proxmox Node Configuration

Add to `/etc/fstab` on **both** Proxmox nodes:

```bash
# LXC configuration storage
192.168.20.31:/volume2/Proxmox-LXCs   /mnt/nfs/lxcs   nfs  defaults,_netdev  0  0

# Media storage
192.168.20.31:/volume2/Proxmox-Media  /mnt/nfs/media  nfs  defaults,_netdev  0  0
```

**Setup Commands:**
```bash
# Create mount points
mkdir -p /mnt/nfs/lxcs /mnt/nfs/media

# Mount all fstab entries
mount -a

# Verify mounts
df -h | grep /mnt/nfs
```

### Docker Host Mounts

**Media Host (docker-lxc-media / 192.168.40.11):**
```bash
# /etc/fstab
192.168.20.31:/volume2/Proxmox-Media /mnt/media nfs defaults,_netdev 0 0
```

Media directory structure:
- `/mnt/media/Movies` - Movie library
- `/mnt/media/Series` - TV series library
- `/mnt/media/Music` - Music library
- `/mnt/media/Downloads` - Download staging

**Immich Host (immich-vm01 / 192.168.40.22):**
```bash
# /etc/fstab
192.168.20.31:/volume2/ProxmoxData /mnt/appdata nfs defaults,_netdev 0 0
```

Immich directory structure (7TB capacity):
- `/mnt/appdata/immich/upload/` - Original uploads
- `/mnt/appdata/immich/library/` - Processed library
- `/mnt/appdata/immich/profile/` - User profiles

---

## 8.4 LXC Bind Mount Strategy

LXC containers use bind mounts to access NFS-stored configuration directories, providing persistent storage that survives container recreation.

### How It Works

```text
┌─────────────────────────────────────────────────────────────┐
│                    Data Flow                                 │
│                                                              │
│  Synology NAS                   Proxmox Host    LXC Container│
│  ┌──────────────┐              ┌──────────┐    ┌───────────┐│
│  │/volume2/     │──NFS mount──►│/mnt/nfs/ │    │           ││
│  │Proxmox-LXCs/ │              │lxcs/     │    │           ││
│  │  └─traefik/  │              │ └─traefik│──►│/app/config││
│  └──────────────┘              └──────────┘    └───────────┘│
│                                     │                        │
│                              bind mount                      │
│                          (via pct.conf)                      │
└─────────────────────────────────────────────────────────────┘
```

### Configuration Example

In the container config file (e.g., `/etc/pve/lxc/100.conf`):

```conf
# Bind mount for Traefik config
mp0: /mnt/nfs/lxcs/traefik,mp=/app/config
```

**Flow breakdown:**
1. Host has `/mnt/nfs/lxcs` mounted via NFS from Synology
2. Subdirectory `/mnt/nfs/lxcs/traefik/` bind-mounted into container
3. Container sees `/app/config` as a normal directory
4. Data persists on NAS at `/volume2/Proxmox-LXCs/traefik/`

### Benefits of This Approach

| Benefit | Explanation |
|---------|-------------|
| **Persistence** | Configs survive container destroy/recreate |
| **Backups** | NAS handles backup scheduling |
| **Migration** | Configs accessible from any node |
| **Simplicity** | No Proxmox storage complexity for app data |

---

# 9. Kubernetes Cluster

This section covers the 9-node Kubernetes cluster deployed across the homelab for container orchestration.

## 9.1 Cluster Overview

| Metric | Value |
|--------|-------|
| **Version** | v1.28.15 (stable) |
| **Control Plane** | 3 nodes (HA) |
| **Worker Nodes** | 6 nodes |
| **Total Nodes** | 9 |
| **Container Runtime** | containerd v1.7.28 |
| **CNI Plugin** | Calico v3.27.0 |
| **Pod Network** | 10.244.0.0/16 |
| **Service CIDR** | 10.96.0.0/12 (default) |
| **Host Node** | node01 (Proxmox) |

### Why Kubernetes in a Homelab?

| Use Case | Benefit |
|----------|---------|
| **Learning** | Gain experience with production K8s patterns |
| **High Availability** | Services survive node failures |
| **Scalability** | Easy horizontal scaling |
| **Declarative** | GitOps-style infrastructure |
| **Portfolio** | Demonstrable enterprise skills |

---

## 9.2 Node Architecture

### Control Plane Nodes

| Hostname | IP Address | Role |
|----------|------------|------|
| k8s-controller01 | 192.168.20.32 | Primary (etcd leader) |
| k8s-controller02 | 192.168.20.33 | HA replica |
| k8s-controller03 | 192.168.20.34 | HA replica |

### Worker Nodes

| Hostname | IP Address |
|----------|------------|
| k8s-worker01 | 192.168.20.40 |
| k8s-worker02 | 192.168.20.41 |
| k8s-worker03 | 192.168.20.42 |
| k8s-worker04 | 192.168.20.43 |
| k8s-worker05 | 192.168.20.44 |
| k8s-worker06 | 192.168.20.45 |

### Node Specifications

All K8s nodes share identical specs (deployed from cloud-init template):

| Setting | Value |
|---------|-------|
| Cores | 2 |
| RAM | 4GB |
| Disk | 20GB |
| Network | VLAN 20 |
| Template | tpl-ubuntu-shared-v1 |

---

## 9.3 Installing Kubernetes (kubeadm)

This section provides a complete guide to deploying a production-grade Kubernetes cluster using kubeadm.

### Prerequisites

Before starting:
- All nodes deployed from cloud-init template
- SSH access configured to all nodes
- All nodes on same VLAN (VLAN 20)
- Static IPs assigned

### Step 1: Prepare All Nodes

Run on **all 9 nodes** (controllers and workers):

```bash
# Disable swap (required for kubelet)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set required sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

### Step 2: Install containerd

Run on **all nodes**:

```bash
# Install containerd
sudo apt-get update
sudo apt-get install -y containerd

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Enable systemd cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### Step 3: Install kubeadm, kubelet, kubectl

Run on **all nodes**:

```bash
# Add Kubernetes repository
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install packages
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Step 4: Initialize First Control Plane

Run on **k8s-controller01 only**:

```bash
# Initialize cluster with HA endpoint
sudo kubeadm init \
  --control-plane-endpoint="192.168.20.32:6443" \
  --pod-network-cidr=10.244.0.0/16 \
  --upload-certs

# Note: Save the output! It contains:
# - kubeadm join command for other control plane nodes
# - kubeadm join command for worker nodes
# - Certificate key (valid 2 hours)
```

After initialization:

```bash
# Configure kubectl for current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify
kubectl get nodes
```

### Step 5: Install Calico CNI

Run on **k8s-controller01**:

```bash
# Install Calico operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

# Install Calico custom resources
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

# Wait for Calico pods
kubectl get pods -n calico-system -w
```

### Step 6: Join Additional Control Plane Nodes

Run on **k8s-controller02** and **k8s-controller03**:

```bash
# Use the join command from kubeadm init output
sudo kubeadm join 192.168.20.32:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <cert-key>
```

### Step 7: Join Worker Nodes

Run on **all 6 worker nodes**:

```bash
# Use the worker join command from kubeadm init output
sudo kubeadm join 192.168.20.32:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

### Step 8: Verify Cluster

Run on **any control plane node**:

```bash
# Check all nodes are Ready
kubectl get nodes -o wide

# Expected output:
# NAME               STATUS   ROLES           AGE   VERSION
# k8s-controller01   Ready    control-plane   10m   v1.28.15
# k8s-controller02   Ready    control-plane   8m    v1.28.15
# k8s-controller03   Ready    control-plane   8m    v1.28.15
# k8s-worker01       Ready    <none>          5m    v1.28.15
# ... (all 6 workers)

# Check system pods
kubectl get pods -n kube-system

# Check Calico pods
kubectl get pods -n calico-system
```

---

## 9.4 Cluster Management

### Useful Commands

```bash
# Cluster info
kubectl cluster-info

# Node status with resources
kubectl top nodes

# All pods across namespaces
kubectl get pods -A

# System pods
kubectl get pods -n kube-system

# Calico status
kubectl get pods -n calico-system

# Describe a node
kubectl describe node k8s-worker01
```

### Accessing the Cluster Remotely

From the Ansible controller (192.168.20.30):

```bash
# Copy kubeconfig from controller
scp k8s-controller01:~/.kube/config ~/.kube/config

# Verify access
kubectl get nodes
```

---

## 9.5 High Availability

### Control Plane HA

The cluster uses **stacked etcd** topology:

```text
┌────────────────────────────────────────────────────────────┐
│                 Control Plane Architecture                  │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ controller01 │  │ controller02 │  │ controller03 │     │
│  │              │  │              │  │              │     │
│  │ API Server   │  │ API Server   │  │ API Server   │     │
│  │ Scheduler    │  │ Scheduler    │  │ Scheduler    │     │
│  │ Controller   │  │ Controller   │  │ Controller   │     │
│  │ etcd         │  │ etcd         │  │ etcd         │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                 │              │
│         └────────────────┬┴─────────────────┘              │
│                          │                                  │
│                   etcd replication                          │
└────────────────────────────────────────────────────────────┘
```

### Failure Scenarios

| Failure | Impact | Recovery |
|---------|--------|----------|
| 1 controller down | Cluster operational | Auto-failover |
| 2 controllers down | **Cluster degraded** | Manual intervention |
| Worker down | Pods rescheduled | Auto-recovery |

---

# 10. Observability Stack

This section covers the OpenTelemetry-based distributed tracing infrastructure.

## 10.1 Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                     Observability Architecture                       │
│                                                                      │
│  User Request                                                        │
│       │                                                              │
│       ▼                                                              │
│  ┌─────────────────┐     ┌─────────────────┐                        │
│  │    Traefik      │────►│   OTEL Traces   │                        │
│  │  192.168.40.20  │     │   (OTLP HTTP)   │                        │
│  │                 │     └────────┬────────┘                        │
│  │  • Routes       │              │                                  │
│  │  • SSL          │              ▼                                  │
│  │  • OTEL Traces  │     ┌─────────────────┐     ┌─────────────────┐│
│  │  • Metrics      │     │ OTEL Collector  │────►│     Jaeger      ││
│  └─────────────────┘     │  192.168.40.13  │     │  192.168.40.13  ││
│                          │                 │     │                 ││
│                          │  • Receivers    │     │  • Trace Store  ││
│                          │  • Processors   │     │  • Query API    ││
│                          │  • Exporters    │     │  • Jaeger UI    ││
│                          └─────────────────┘     └────────┬────────┘│
│                                                           │          │
│                          ┌────────────────────────────────┘          │
│                          ▼                                           │
│                 ┌─────────────────────────────────────────┐         │
│                 │                 Grafana                  │         │
│                 │             192.168.40.13:3030           │         │
│                 │  Prometheus + Jaeger Datasources         │         │
│                 └─────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────┘
```

## 10.2 Components

| Component | Purpose | Host | Port |
|-----------|---------|------|------|
| **OTEL Collector** | Central trace/metrics receiver | docker-vm-core-utilities01 | 4317 (gRPC), 4318 (HTTP) |
| **Jaeger** | Distributed tracing visualization | docker-vm-core-utilities01 | 16686 (UI) |
| **Traefik** | Trace source (instrumented) | traefik-vm01 | 8082 (metrics) |

## 10.3 Service URLs

### External (via Traefik with Authentik SSO)

| Service | URL |
|---------|-----|
| Jaeger | https://jaeger.hrmsmrflrii.xyz |
| Demo App | https://demo.hrmsmrflrii.xyz |
| Prometheus | https://prometheus.hrmsmrflrii.xyz |
| Grafana | https://grafana.hrmsmrflrii.xyz |

### Internal (Direct Access)

| Service | URL | Port |
|---------|-----|------|
| Jaeger UI | http://192.168.40.13:16686 | 16686 |
| OTEL Collector (gRPC) | http://192.168.40.13:4317 | 4317 |
| OTEL Collector (HTTP) | http://192.168.40.13:4318 | 4318 |
| OTEL Collector Metrics | http://192.168.40.13:8888 | 8888 |
| OTEL Pipeline Metrics | http://192.168.40.13:8889 | 8889 |
| Jaeger Metrics | http://192.168.40.13:14269 | 14269 |

## 10.4 Traefik OTEL Configuration

Traefik is configured to send traces to the OTEL Collector:

```yaml
# traefik.yml (static configuration)
tracing:
  otlp:
    http:
      endpoint: "http://192.168.40.13:4318/v1/traces"
  serviceName: "traefik"
  sampleRate: 1.0  # 100% sampling

metrics:
  prometheus:
    buckets: [0.1, 0.3, 1.2, 5.0]
    addEntryPointsLabels: true
    addRoutersLabels: true
    addServicesLabels: true
    entryPoint: metrics

entryPoints:
  metrics:
    address: ":8082"
```

## 10.5 Using Jaeger

1. Navigate to https://jaeger.hrmsmrflrii.xyz
2. Authenticate via Authentik (Google SSO)
3. Select service from dropdown (e.g., `traefik`)
4. Click "Find Traces"
5. Click on a trace to see span details

### Sample Trace

```
Trace ID: abc123...
├── traefik (root span)
│   ├── Duration: 150ms
│   ├── HTTP Method: GET
│   ├── HTTP URL: /api/resource
│   └── Status Code: 200
```

---

# 11. Watchtower Interactive Updates

This section covers the automated container update system with Discord-based approval workflow.

## 11.1 Overview

Watchtower monitors all Docker containers for updates and sends interactive Discord notifications. Updates only proceed after user approval via emoji reactions.

| Setting | Value |
|---------|-------|
| **Check Schedule** | Daily at 3:00 AM |
| **Mode** | Monitor-only (requires approval) |
| **Notifications** | Discord with reaction-based approval |
| **Auto-cleanup** | Old images removed after update |

## 11.2 Architecture

```text
Docker Hosts (Watchtower)          Sentinel Bot (192.168.40.13)
┌─────────────────────┐            ┌─────────────────────────────────┐
│ .40.13 (utilities)  │            │  Discord.py + Quart Webhooks    │
│ .40.11 (media)      │───────────►│                                 │
│ .40.20 (traefik)    │  Shoutrrr  │  Receives webhooks              │
│ .40.21 (authentik)  │  Webhook   │  Sends Discord notifications    │
│ .40.22 (immich)     │            │  Executes updates via SSH       │
│ .40.23 (gitlab)     │            └─────────────────────────────────┘
└─────────────────────┘                          │
                                                 ▼
                                    ┌─────────────────────────────────┐
                                    │      Discord Channel            │
                                    │                                 │
                                    │  "New update for sonarr..."     │
                                    │                                 │
                                    │  👍 → Update    👎 → Skip       │
                                    └─────────────────────────────────┘
```

## 11.3 Watchtower Configuration

Each Docker host runs Watchtower in monitor-only mode:

```yaml
# /opt/watchtower/docker-compose.yml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    environment:
      DOCKER_API_VERSION: "1.44"
      WATCHTOWER_SCHEDULE: "0 0 3 * * *"
      WATCHTOWER_CLEANUP: "true"
      WATCHTOWER_INCLUDE_STOPPED: "false"
      WATCHTOWER_MONITOR_ONLY: "true"
      WATCHTOWER_NOTIFICATIONS: "shoutrrr"
      WATCHTOWER_NOTIFICATION_URL: "generic+http://192.168.40.13:5050/webhook/watchtower"
      TZ: "America/New_York"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

**Key Settings:**
- `WATCHTOWER_MONITOR_ONLY: "true"` - Does NOT auto-update
- `generic+http://` - Required URL format for Shoutrrr

## 11.4 Update Approval Flow

1. Watchtower detects update → sends webhook to Sentinel
2. Sentinel posts embed to `#container-updates` Discord channel
3. User reacts with 👍 to approve ALL updates
4. Number emojis (1️⃣, 2️⃣, etc.) for individual updates
5. Bot executes approved updates via SSH
6. Completion notification with status

---

# 12. Sentinel Discord Bot

Sentinel is the unified Discord bot for homelab management, consolidating 4 previous bots (Argus, Chronos, Mnemosyne, Athena).

## 12.1 Overview

| Property | Value |
|----------|-------|
| **Location** | `/opt/sentinel-bot/` on docker-vm-core-utilities01 |
| **Container** | `sentinel-bot` |
| **Webhook Port** | 5050 |
| **Framework** | discord.py 2.3+ with Quart webhooks |
| **Status** | Deployed January 2026 |

## 12.2 Architecture

```
Discord Server
     │
     ▼
Sentinel Bot (discord.py 2.3+)
├── Core
│   ├── bot.py           → Main SentinelBot class
│   ├── database.py      → Async SQLite (aiosqlite)
│   ├── channel_router.py → Notification routing
│   └── ssh_manager.py   → Async SSH (asyncssh)
│
├── Cogs (7 modules)
│   ├── homelab.py       → Proxmox cluster management
│   ├── updates.py       → Container updates + reaction approvals
│   ├── media.py         → Download monitoring + Jellyseerr
│   ├── gitlab.py        → GitLab issue management
│   ├── tasks.py         → Claude task queue
│   ├── onboarding.py    → Service verification
│   └── scheduler.py     → Daily reports
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

## 12.3 Channel Routing

| Cog | Channel | Purpose |
|-----|---------|---------|
| **Homelab** | `#homelab-infrastructure` | Proxmox status, VM/LXC management |
| **Updates** | `#container-updates` | Container updates with reaction approvals |
| **Media** | `#media-downloads` | Download progress, library stats |
| **GitLab** | `#project-management` | Issue creation and tracking |
| **Tasks** | `#claude-tasks` | Claude task queue management |
| **Onboarding** | `#new-service-onboarding-workflow` | Service verification |

## 12.4 Commands

### Homelab Commands (`#homelab-infrastructure`)

| Command | Description |
|---------|-------------|
| `/help` | Show all Sentinel commands |
| `/insight` | Health check: memory, errors, storage, downloads |
| `/homelab status` | Cluster overview with resource bars |
| `/homelab uptime` | Uptime for all nodes/VMs/LXCs |
| `/node <name> status` | Detailed node status |
| `/vm <id> start/stop/restart` | VM control |
| `/lxc <id> start/stop/restart` | LXC control |

### Update Commands (`#container-updates`)

| Command | Description |
|---------|-------------|
| `/check` | Scan all containers for updates |
| `/update <container>` | Update specific container |
| `/updateall` | Update all with pending updates |
| `/containers` | List monitored containers |

### Media Commands (`#media-downloads`)

| Command | Description |
|---------|-------------|
| `/downloads` | Current download queue with progress |
| `/download <title>` | Search & add via Jellyseerr |
| `/library movies` | Movie library statistics |
| `/library shows` | TV library statistics |
| `/recent` | Recently added media |

### GitLab Commands (`#project-management`)

| Command | Description |
|---------|-------------|
| `/todo <description>` | Create GitLab issue |
| `/issues` | List open issues |
| `/close <id>` | Close an issue |
| `/quick <tasks>` | Bulk create (semicolon-separated) |

## 12.5 Management

```bash
# View bot logs
ssh hermes-admin@192.168.40.13 "docker logs sentinel-bot --tail 50"

# Restart bot
ssh hermes-admin@192.168.40.13 "cd /opt/sentinel-bot && sudo docker compose restart"

# Rebuild after code changes
ssh hermes-admin@192.168.40.13 "cd /opt/sentinel-bot && sudo docker compose build --no-cache && sudo docker compose up -d"

# Check webhook health
curl http://192.168.40.13:5050/health
```

---

# Appendix

## A. Complete IP Address Map

### VLAN 20 - Infrastructure (192.168.20.0/24)

| IP | Hostname | Purpose | MAC Address |
|----|----------|---------|-------------|
| .1 | - | Gateway | - |
| .20 | node01 | Proxmox Primary | 38:05:25:32:82:76 |
| .21 | node02 | Proxmox Secondary | 84:47:09:4D:7A:CA |
| .30 | ansible-controller01 | Ansible Controller | - |
| .31 | synology-nas | Synology DS920+ | - |
| .32 | k8s-controller01 | K8s Control Plane | - |
| .33 | k8s-controller02 | K8s Control Plane | - |
| .34 | k8s-controller03 | K8s Control Plane | - |
| .40-45 | k8s-worker01-06 | K8s Workers | - |
| .50 | pbs | Proxmox Backup Server | - |
| .51 | qdevice | Cluster Qdevice | - |

### VLAN 40 - Services (192.168.40.0/24)

| IP | Hostname | Purpose |
|----|----------|---------|
| .1 | - | Gateway |
| .11 | docker-lxc-media | Arr Stack, Jellyfin |
| .12 | docker-lxc-glance | Glance Dashboard |
| .13 | docker-vm-core-utilities01 | Grafana, Prometheus |
| .20 | traefik-vm01 | Reverse Proxy |
| .21 | authentik-vm01 | Identity Provider |
| .22 | immich-vm01 | Photo Management |
| .23 | gitlab-vm01 | DevOps Platform |
| .25 | homeassistant-lxc | Home Automation |

## B. Service URLs Reference

| Service | Internal URL | External URL |
|---------|--------------|--------------|
| Proxmox | https://192.168.20.21:8006 | https://proxmox.hrmsmrflrii.xyz |
| Traefik | http://192.168.40.20:8080 | https://traefik.hrmsmrflrii.xyz |
| Authentik | http://192.168.40.21:9000 | https://auth.hrmsmrflrii.xyz |
| Grafana | http://192.168.40.13:3030 | https://grafana.hrmsmrflrii.xyz |
| Prometheus | http://192.168.40.13:9090 | https://prometheus.hrmsmrflrii.xyz |
| Glance | http://192.168.40.12:8080 | https://glance.hrmsmrflrii.xyz |
| Jellyfin | http://192.168.40.11:8096 | https://jellyfin.hrmsmrflrii.xyz |
| Radarr | http://192.168.40.11:7878 | https://radarr.hrmsmrflrii.xyz |
| Sonarr | http://192.168.40.11:8989 | https://sonarr.hrmsmrflrii.xyz |

## C. Command Cheatsheet

### Proxmox

```bash
# Cluster status
pvecm status

# List VMs
qm list

# List containers
pct list

# Start/stop VM
qm start 100
qm stop 100

# Clone from template
qm clone 9000 100 --name new-vm --full

# Backup VM
vzdump 100 --storage pbs --mode snapshot

# Enter container
pct enter 200
```

### Docker

```bash
# List running containers
docker ps

# Follow logs
docker logs -f <container>

# Compose operations
docker compose up -d
docker compose down
docker compose pull
docker compose restart

# Cleanup
docker system prune -af
```

### Ansible

```bash
# Test connectivity
ansible all -m ping

# Run playbook
ansible-playbook playbook.yml

# Run with verbose output
ansible-playbook playbook.yml -vvv

# Limit to specific hosts
ansible-playbook playbook.yml -l docker_hosts

# Check mode (dry run)
ansible-playbook playbook.yml --check
```

## D. SSH Configuration

### SSH Key Setup

| Field | Value |
|-------|-------|
| Key File | `~/.ssh/homelab_ed25519` |
| Key Type | ed25519 |
| Passphrase | None (for automation) |
| Comment | `hermes@homelab-nopass` |

### SSH Config File

Create `~/.ssh/config` for convenient host access:

```ssh-config
# Proxmox Nodes
Host node01
    HostName 192.168.20.20
    User root
    IdentityFile ~/.ssh/homelab_ed25519

Host node02
    HostName 192.168.20.21
    User root
    IdentityFile ~/.ssh/homelab_ed25519

Host node03
    HostName 192.168.20.22
    User root
    IdentityFile ~/.ssh/homelab_ed25519

# Ansible Controller
Host ansible-controller01
    HostName 192.168.20.30
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

# Kubernetes Controllers
Host k8s-controller01
    HostName 192.168.20.32
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-controller02
    HostName 192.168.20.33
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-controller03
    HostName 192.168.20.34
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

# Kubernetes Workers
Host k8s-worker01
    HostName 192.168.20.40
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker02
    HostName 192.168.20.41
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker03
    HostName 192.168.20.42
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker04
    HostName 192.168.20.43
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker05
    HostName 192.168.20.44
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker06
    HostName 192.168.20.45
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

# Service VMs - VLAN 40
Host docker-vm-core-utilities01
    HostName 192.168.40.13
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host docker-vm-media01
    HostName 192.168.40.11
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host traefik-vm01
    HostName 192.168.40.20
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host authentik-vm01
    HostName 192.168.40.21
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host immich-vm01
    HostName 192.168.40.22
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host gitlab-vm01
    HostName 192.168.40.23
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519
```

### Usage

```bash
# Connect using alias
ssh node01              # Proxmox node 1
ssh ansible-controller01  # Ansible controller
ssh k8s-controller01    # K8s control plane
ssh traefik-vm01        # Traefik host

# Run remote commands
ssh docker-vm-media01 "docker ps"
ssh k8s-controller01 "kubectl get nodes"
```

### Security Notes

- **No Passphrase**: Enables automated Ansible playbook execution
- **File Permissions**: Key file is `chmod 600` (owner read/write only)
- **Network Isolation**: Keys only work within internal VLANs (20, 40)
- **Key Rotation**: Scheduled every 6 months

---

**Document Information**

| Property | Value |
|----------|-------|
| Author | Hermes Miraflor II |
| Version | 2.1 |
| Created | January 7, 2026 |
| Last Updated | January 8, 2026 |
| Total Sections | 12 chapters + Appendix |
| Repository | https://github.com/herms14/Proxmox-TerraformDeployments |

---

*This manual is a living document and will be updated as the infrastructure evolves.*
