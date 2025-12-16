# Proxmox Terraform Infrastructure Documentation

## Overview

This repository contains Terraform infrastructure-as-code for deploying VMs and LXC containers on a Proxmox VE 9.1.2 cluster. The infrastructure is designed for a homelab environment with Kubernetes, Docker services, and supporting infrastructure.

## Infrastructure Architecture

### Proxmox Cluster Nodes

| Node | IP Address | Purpose | Workload Type |
|------|------------|---------|---------------|
| **node01** | 192.168.20.20 | VM Host | All virtual machines |
| **node02** | 192.168.20.21 | LXC Host | All LXC containers |
| **node03** | 192.168.20.22 | General Purpose | Mixed workloads |

### Network Architecture

#### VLANs

| VLAN | Network | Gateway | Purpose | Services |
|------|---------|---------|---------|----------|
| **VLAN 20** | 192.168.20.0/24 | 192.168.20.1 | Kubernetes Infrastructure | K8s control plane, worker nodes, Traefik |
| **VLAN 40** | 192.168.40.0/24 | 192.168.40.1 | Services & Management | Docker hosts, logging, automation |

#### Network Bridge
- **Bridge**: vmbr0 (all VMs and containers use this bridge)
- **VLAN Support**: Bridge must be VLAN-aware on all nodes
- **Required Configuration**: See Node Network Requirements below

### Storage Configuration

The cluster uses a production-grade NFS storage architecture with dedicated exports for each content type. This design prevents storage state ambiguity, content type conflicts, and ensures consistent behavior across all nodes.

#### Synology NAS Configuration

**NAS Address**: 192.168.20.31

| Storage Pool | Export Path | Type | Content Type | Management |
|--------------|-------------|------|--------------|------------|
| **VMDisks** | `/volume2/ProxmoxCluster-VMDisks` | NFS | Disk image | Proxmox-managed |
| **ISOs** | `/volume2/ProxmoxCluster-ISOs` | NFS | ISO image | Proxmox-managed |
| **LXC Configs** | `/volume2/Proxmox-LXCs` | NFS | N/A | Manual mount |
| **Media** | `/volume2/Proxmox-Media` | NFS | N/A | Manual mount |
| **local-lvm** | N/A | Local LVM | Container | Local storage |

#### Storage Architecture Principles

**Design Rule**: One NFS export = One Proxmox storage pool

1. **VMDisks** - Proxmox-managed storage for VM disk images
   - Used for: VM virtual disks, cloud-init drives
   - Enables: Live migration, snapshots, HA
   - Mount: Automatically managed by Proxmox on all nodes

2. **ISOs** - Proxmox-managed storage for installation media
   - Used for: ISO images, installation media
   - Separated from VM disks to prevent accidental operations
   - Mount: Automatically managed by Proxmox on all nodes

3. **LXC Configs** - Manual NFS mount for application data
   - Mount point: `/mnt/nfs/lxcs` (on all nodes)
   - Used for: LXC application configurations via bind mounts
   - Why NOT a Proxmox storage: Proxmox expects LXC rootfs images, not app directories
   - Configured in: `/etc/fstab` on all nodes

4. **Media** - Manual NFS mount for media files
   - Mount point: `/mnt/nfs/media` (on all nodes)
   - Used for: Radarr, Sonarr, Plex media files
   - Directory structure: `/Movies/`, `/Series/`
   - Why NOT a Proxmox storage: Prevents Proxmox from scanning thousands of media files
   - Configured in: `/etc/fstab` on all nodes

#### Proxmox Storage Configuration

**VMDisks Storage** (Datacenter → Storage → VMDisks):
```
ID: VMDisks
Server: 192.168.20.31
Export: /volume2/ProxmoxCluster-VMDisks
Content: Disk image
Nodes: All nodes
```

**ISOs Storage** (Datacenter → Storage → ISOs):
```
ID: ISOs
Server: 192.168.20.31
Export: /volume2/ProxmoxCluster-ISOs
Content: ISO image
Nodes: All nodes
```

#### Manual NFS Mounts

**Configuration** (`/etc/fstab` on all nodes):
```bash
192.168.20.31:/volume2/Proxmox-LXCs   /mnt/nfs/lxcs   nfs  defaults,_netdev  0  0
192.168.20.31:/volume2/Proxmox-Media  /mnt/nfs/media  nfs  defaults,_netdev  0  0
```

**Setup commands** (run on all nodes):
```bash
# Create mount points
mkdir -p /mnt/nfs/lxcs
mkdir -p /mnt/nfs/media

# Mount all
mount -a

# Verify
df -h | grep /mnt/nfs
```

#### LXC Bind Mount Strategy

**Example**: Traefik container with persistent config
```
Container config (/etc/pve/lxc/100.conf):
mp0: /mnt/nfs/lxcs/traefik,mp=/app/config
```

**Flow**:
1. Host has `/mnt/nfs/lxcs` mounted via NFS
2. Subdirectory `/mnt/nfs/lxcs/traefik/` bind-mounted into container
3. Container sees `/app/config` as normal directory
4. Data persists on NAS at `/volume2/Proxmox-LXCs/traefik/`

#### Why This Architecture Works

**Problem Prevention**:
- ✅ No inactive storage warnings (each storage has dedicated export)
- ✅ No `?` icons in UI (homogeneous content types)
- ✅ No template clone failures (all storages on all nodes)
- ✅ No LXC rootfs errors (app configs are manual mounts)
- ✅ No performance degradation (media not scanned by Proxmox)
- ✅ Migration works consistently (identical paths across nodes)

**Key Insight**: Proxmox storages are for Proxmox-managed content (VM disks, ISOs, LXC rootfs). Application data and media require manual mounts with bind mounts into containers.

### Node Network Requirements

#### Critical Network Configuration

All Proxmox nodes **MUST** have VLAN-aware bridge configuration. Missing this configuration will cause VM deployment failures with error: `QEMU exited with code 1`.

**Required `/etc/network/interfaces` configuration**:
```bash
auto lo
iface lo inet loopback

# IMPORTANT: Physical interface must be set to auto
auto nic0
iface nic0 inet manual

auto vmbr0
iface vmbr0 inet static
	address 192.168.20.XX/24   # XX = node-specific IP
	gateway 192.168.20.1
	bridge-ports nic0
	bridge-stp off
	bridge-fd 0
	bridge-vlan-aware yes      # CRITICAL: Required for VLAN support
	bridge-vids 2-4094         # CRITICAL: Allowed VLAN range

source /etc/network/interfaces.d/*
```

**Key Requirements**:
1. **`auto nic0`** - Ensures physical interface starts before bridge
2. **`bridge-vlan-aware yes`** - Enables VLAN filtering on the bridge
3. **`bridge-vids 2-4094`** - Allows all standard VLAN tags

**Verification after configuration**:
```bash
# Reload network configuration
ifreload -a
# OR reboot for clean reload
reboot

# Verify VLAN filtering is active (should show "vlan_filtering 1")
ip -d link show vmbr0 | grep vlan_filtering
```

**Common Issue**: Node03 initially lacked VLAN-aware configuration, causing all VM deployments to fail with "no physical interface on bridge 'vmbr0'" error. See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for detailed resolution steps.

## Deployed Infrastructure

### Current Deployment Status

This is the initial deployment focusing on Ansible control nodes. Additional infrastructure will be added incrementally.

#### Virtual Machines - VLAN 20

**Automation & Management:**
| Hostname | Node | IP Address | Cores | RAM | Disk | Purpose | Deployment Method |
|----------|------|------------|-------|-----|------|---------|-------------------|
| ansible-control01 | node03 | 192.168.20.50 | 4 | 8GB | 20GB | Ansible control node | ISO + Ansible |
| ansible-control02 | node03 | 192.168.20.51 | 4 | 8GB | 20GB | Ansible control node | ISO + Ansible |

**Deployment Method**: ISO-based installation (Ubuntu 24.04.3 Server)
**Storage**: VMDisks (NFS on Synology)
**Network**: vmbr0 (VLAN 20, untagged)
**DNS**: 192.168.20.1
**Access**: SSH key authentication (user: hermes-admin)
**Configuration**: Post-installation via Ansible from local machine

### LXC Containers

LXC container deployments are currently disabled. Will be enabled after VM infrastructure is stable.

## IP Address Allocation

### VLAN 20 (192.168.20.0/24)
- **20-22**: Proxmox cluster nodes (node01, node02, node03)
- **50-59**: Ansible automation infrastructure (ansible-control01, ansible-control02)
- **100-199**: Reserved for LXC containers
- **200-254**: Reserved for future VM deployments

### VLAN 40 (192.168.40.0/24)
- **10-19**: Reserved for Docker Media Services
- **20-29**: Reserved for Docker Utility Services
- **30-39**: Reserved for Logging & Monitoring
- **40-49**: Reserved for additional Automation & Management

## Authentication & Access

### SSH Access
- **User**: hermes-admin
- **SSH Key**: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAby7br+5MzyDus2fi2UFjUBZvGucN40Gxa29bgUTbfz hermes@homelab`
- **Access Method**: SSH key authentication only

### Proxmox API
- **API URL**: https://192.168.20.21:8006/api2/json
- **Authentication**: API Token (terraform-deployment-user@pve!tf)
- **TLS**: Self-signed certificate (insecure mode enabled)

## Terraform Configuration

### Provider
- **Provider**: telmate/proxmox v3.0.2-rc06
- **Reason for RC version**: Compatibility with Proxmox VE 9.x

### Module Structure

```
tf-proxmox/
├── main.tf                 # VM group definitions and orchestration (cloud-init)
├── iso-vms.tf              # ISO-based VM deployments
├── lxc.tf                  # LXC container definitions
├── variables.tf            # Global variables and defaults
├── outputs.tf              # Output definitions
├── terraform.tfvars        # Variable values (gitignored)
├── modules/
│   ├── linux-vm/          # VM deployment module (cloud-init)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── lxc/               # LXC deployment module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── lxc-example.tf         # Example LXC configurations
├── LXC_GUIDE.md          # LXC deployment documentation
├── TROUBLESHOOTING.md    # Troubleshooting guide
└── CLAUDE.md             # This file
```

### Key Features
- **Auto-incrementing hostnames**: Automatic sequential naming (e.g., k8s-workernode01, k8s-workernode02)
- **Auto-incrementing IPs**: Automatic IP assignment from starting_ip
- **Dynamic resource creation**: Uses Terraform for_each for scalable deployments
- **Multiple deployment methods**: Cloud-init for automated provisioning, ISO-based for manual installation
- **Consistent configuration**: DRY principle through modules

### Deployment Methodologies

#### Cloud-init Deployment (main.tf + modules/linux-vm/)
**Best for**: Production infrastructure requiring fully automated provisioning

**Workflow**:
1. Terraform clones from cloud-init template
2. Cloud-init configures network, users, SSH keys on first boot
3. VM boots fully configured and accessible

**Requirements**:
- Cloud-init compatible template on target node
- UEFI boot mode must match template configuration
- Working network configuration at boot time
- VLAN-aware bridge properly configured

**Current Status**: ✅ Cloud-init deployments fully operational. UEFI boot configuration resolved previous boot issues (December 15, 2025). See "Resolved Issues" below for details.

#### ISO-based Deployment (iso-vms.tf)
**Best for**: VMs requiring manual installation or troubleshooting cloud-init issues

**Workflow**:
1. Terraform creates VM with empty disk and ISO mounted
2. VM boots to Ubuntu Server installer
3. Manual installation through console:
   - Configure network (IP, gateway, DNS)
   - Create initial user
   - Install OpenSSH server
4. After installation completes, configure with Ansible from local machine:
   - Install qemu-guest-agent
   - Add SSH keys
   - Configure system settings
   - Install packages

**Advantages**:
- Full control over installation process
- Bypasses cloud-init networking issues
- Easier troubleshooting
- Ansible provides consistent post-installation configuration

**Current Use**: Ansible control nodes deployed via ISO method

## VM Configuration Standards

### Default VM Specifications:
- **CPU**: 1 socket, 4 cores
- **Memory**: 8GB (8192 MB)
- **Disk**: 20GB
- **Storage**: VMDisks (NFS)
- **Cloud-init User**: hermes-admin
- **SSH Authentication**: SSH key only (password authentication disabled)
- **SSH Key**: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAby7br+5MzyDus2fi2UFjUBZvGucN40Gxa29bgUTbfz hermes@homelab`

### All VMs Include:
- **Cloud-init**: For automated provisioning with SSH key authentication
- **QEMU Guest Agent**: Enabled for better integration
- **On Boot**: Auto-start enabled
- **CPU Type**: host (maximum performance)
- **SCSI Controller**: lsi
- **Network Model**: virtio
- **Template**: ubuntu-24.04-cloudinit-template (available on all nodes)

### VLAN Configuration:
- **VLAN 20**: vlan_tag = null (default, no tag needed)
- **VLAN 40**: vlan_tag = 40 (explicit tag)

## LXC Configuration Standards

### Container Types:
- **Unprivileged** (default): More secure, suitable for most services
- **Privileged**: Only when needed (e.g., Docker with nesting)

### Features:
- **Nesting**: Enabled only for Docker hosts
- **Auto-start**: Enabled for production services
- **SSH Keys**: Pre-configured for access

## Common Operations

### Deploy All Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

### Deploy Cloud-init VMs Only
```bash
terraform apply -target=module.vms
```

### Deploy ISO-based VMs Only
```bash
terraform apply -target=proxmox_vm_qemu.iso_vm
```

### Deploy LXC Containers Only
```bash
terraform apply -target=module.lxc
```

### View Deployed Resources
```bash
# View all cloud-init VMs
terraform output vm_summary

# View all ISO-based VMs
terraform output iso_vm_summary

# View all LXC containers
terraform output lxc_summary

# View IP mappings
terraform output vm_ips
terraform output lxc_ips
```

### ISO-based VM Deployment Workflow

**Step 1: Define VMs in iso-vms.tf**
```hcl
locals {
  iso_vms = {
    my-vm = {
      count       = 2
      starting_ip = "192.168.20.50"  # Reference only
      target_node = "node03"
      cores       = 4
      sockets     = 1
      memory      = 8192
      disk_size   = "20G"
      storage     = "VMDisks"
      iso         = "ISOs:iso/ubuntu-24.04.3-live-server-amd64.iso"
      network_bridge = "vmbr0"
      vlan_tag       = null
    }
  }
}
```

**Step 2: Deploy with Terraform**
```bash
terraform apply -target=proxmox_vm_qemu.iso_vm
```

**Step 3: Manual OS Installation**
1. Access VM console via Proxmox web UI
2. Complete Ubuntu Server installation:
   - Configure network (IP, gateway, DNS)
   - Create initial user (hermes-admin)
   - Install OpenSSH server
3. Reboot after installation

**Step 4: Post-Installation with Ansible**
```bash
# Create Ansible inventory
cat > inventory.ini <<EOF
[ansible_control]
ansible-control01 ansible_host=192.168.20.50
ansible-control02 ansible_host=192.168.20.51

[ansible_control:vars]
ansible_user=hermes-admin
EOF

# Run Ansible playbook for configuration
ansible-playbook -i inventory.ini configure-vms.yml
```

Example Ansible playbook (`configure-vms.yml`):
```yaml
---
- name: Configure VMs post-installation
  hosts: all
  become: yes
  tasks:
    - name: Install qemu-guest-agent
      apt:
        name: qemu-guest-agent
        state: present
        update_cache: yes

    - name: Start qemu-guest-agent
      service:
        name: qemu-guest-agent
        state: started
        enabled: yes

    - name: Add SSH public key
      authorized_key:
        user: hermes-admin
        key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAby7br+5MzyDus2fi2UFjUBZvGucN40Gxa29bgUTbfz hermes@homelab"

    - name: Disable password authentication
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^PasswordAuthentication'
        line: 'PasswordAuthentication no'
      notify: Restart SSH

  handlers:
    - name: Restart SSH
      service:
        name: ssh
        state: restarted
```

### Add New VM Group
Edit `main.tf` and add to `vm_groups` local:
```hcl
new-service = {
  count         = 1
  starting_ip   = "192.168.20.50"
  starting_node = "node01"  # Optional: auto-increment nodes (node01, node02, node03...)
  template      = "ubuntu-24.04-cloudinit-template"
  cores         = 4      # Default: 4 cores
  sockets       = 1      # Default: 1 socket
  memory        = 8192   # Default: 8GB
  disk_size     = "20G"  # Default: 20GB
  storage       = "VMDisks"
  vlan_tag      = null   # null for VLAN 20, 40 for VLAN 40
  gateway       = "192.168.20.1"
  nameserver    = "192.168.91.30"
}
```

**VLAN Examples:**
- VLAN 20: `vlan_tag = null`, `gateway = "192.168.20.1"`, `nameserver = "192.168.91.30"`, `starting_ip = "192.168.20.x"`
- VLAN 40: `vlan_tag = 40`, `gateway = "192.168.40.1"`, `nameserver = "192.168.91.30"`, `starting_ip = "192.168.40.x"`

### Add New LXC Container
Edit `lxc.tf` and add to `lxc_groups` local:
```hcl
new-container = {
  count        = 1
  starting_ip  = "192.168.20.101"
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  unprivileged = true
  cores        = 1
  memory       = 512
  swap         = 256
  disk_size    = "8G"
  storage      = "local-lvm"  # LXC rootfs on local storage
  vlan_tag     = null
  gateway      = "192.168.20.1"
  nameserver   = "192.168.91.30"
  nesting      = false
}
```

**Note**: LXC containers use `local-lvm` for rootfs. Application data should be bind-mounted from `/mnt/nfs/lxcs`:
```
Container config (/etc/pve/lxc/101.conf):
mp0: /mnt/nfs/lxcs/new-container,mp=/app/config
```

## LXC Template Management

### Download LXC Templates (on Proxmox nodes)
```bash
# Update template list
pveam update

# List available templates
pveam available

# Download Ubuntu 22.04 LXC template
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Download Debian 12 LXC template
pveam download local debian-12-standard_12.2-1_amd64.tar.zst
```

Templates are stored in: `/var/lib/vz/template/cache/`

## Resource Sizing Guidelines

### Kubernetes Nodes
- **Control Plane**: 2 cores, 4GB RAM minimum
- **Worker Nodes**: 4 cores, 8GB RAM (adjust based on workload)

### Docker Hosts
- **Media Services**: 4 cores, 8GB RAM (for transcoding)
- **General Services**: 2-4 cores, 4-8GB RAM

### LXC Containers
- **Reverse Proxy (Traefik)**: 1-2 cores, 1GB RAM
- **Web Servers**: 1 core, 512MB RAM
- **Docker in LXC**: 2-4 cores, 2-4GB RAM

## Troubleshooting

### Resolved Issues

#### Cloud-init VM Boot Failure - UEFI/BIOS Mismatch (RESOLVED - December 15, 2025)

**Original Issue**: Cloud-init based VMs would create successfully but failed to boot properly, causing VMs to be unreachable via SSH/ping.

**Symptoms**:
- VM creates successfully via Terraform
- VM starts but console output stops at: `Btrfs loaded, zoned=yes, fsverity=yes`
- Boot process hangs before cloud-init initialization
- VM is unreachable via SSH (connection timeout)
- VM is unreachable via ping, even from Proxmox host node
- VM shows status "running" but is stuck during boot

**Root Cause**:
**UEFI/BIOS Boot Mode Mismatch** - The actual issue was a fundamental boot configuration incompatibility:

- **Template Configuration** (tpl-ubuntuv24.04-v1):
  - BIOS: `ovmf` (UEFI boot mode)
  - EFI Disk: Present (`efidisk0`)
  - Machine: `q35`
  - SCSI: `virtio-scsi-single`

- **Terraform VM Configuration** (before fix):
  - BIOS: `seabios` (Legacy BIOS mode) ❌
  - EFI Disk: Cloned from template but incompatible with BIOS mode
  - Machine: `q35`
  - SCSI: `lsi` (different from template)

**Why It Failed**:
The VM inherited a UEFI EFI disk from the template but was configured to boot in legacy BIOS mode. This boot mode mismatch caused the system to hang during boot initialization, before cloud-init or networking could even start. The system was stuck trying to reconcile UEFI firmware with BIOS boot mode.

**Resolution**:
Updated `modules/linux-vm/main.tf` to match the template's UEFI boot configuration:

```hcl
# UEFI Boot Configuration
bios    = "ovmf"
machine = "q35"

# EFI Disk (required for UEFI boot)
efidisk {
  storage           = var.storage
  efitype           = "4m"
  pre_enrolled_keys = true
}

# SCSI Controller (match template)
scsihw = "virtio-scsi-single"
```

**Result**:
- ✅ VMs now boot successfully with UEFI
- ✅ Cloud-init initializes and completes normally
- ✅ Network configuration applied correctly
- ✅ SSH key authentication working
- ✅ VMs fully accessible and functional

**Files Modified**:
- `modules/linux-vm/main.tf` - Added UEFI boot support (bios, efidisk, machine, scsihw)

**Current Status**: Cloud-init deployments fully operational. Template `tpl-ubuntuv24.04-v1` on node01 working correctly for production VM deployments.

**Key Lesson**: Always match VM boot mode (UEFI vs BIOS) to the template configuration. Use `qm config <vmid>` on the Proxmox host to verify template settings before deploying VMs.

**Related Documentation**: See TROUBLESHOOTING.md for detailed troubleshooting steps.

### Common Issues

#### Node Showing Question Mark / Unhealthy Status (RESOLVED - December 16, 2025)

**Symptom**: Node appears with a question mark icon in Proxmox web UI and shows "NR" (Not Ready) status in cluster membership

**Incident Details**: Node03 showed unhealthy status in cluster on December 16, 2025.

**Root Cause**: Node was in shutdown state ("System is going down" message in system logs). Shutdown cause was unexpected/unintentional.

**Diagnosis Steps**:
```bash
# 1. Verify network connectivity
ping 192.168.20.22

# 2. Check SSH access
ssh root@192.168.20.22 "uptime"

# 3. Check cluster status from affected node
ssh root@192.168.20.22 "pvecm status"

# 4. Check cluster status from another node
ssh root@192.168.20.21 "pvecm status"

# 5. Check cluster resources via API
ssh root@192.168.20.22 "pvesh get /cluster/resources --type node"
```

**What to Look For**:
- "System is going down" message indicates active shutdown
- "NR" (Not Ready) in membership information vs "A,NV,NMW" for healthy nodes
- Node status should show "online" in cluster resources
- Uptime should match expected runtime

**Resolution**:
1. **If shutdown in progress**: Try to cancel with `shutdown -c` (may fail if too far along)
2. **If shutdown completed**: Power on the node via physical access, IPMI/BMC, or Wake-on-LAN
3. **Verify cluster rejoin**:
   ```bash
   # Check node is online
   ssh root@192.168.20.22 "pvecm status"

   # Verify corosync services
   ssh root@192.168.20.22 "systemctl status corosync pve-cluster"

   # Check cluster resources
   ssh root@192.168.20.22 "pvesh get /cluster/resources --type node"
   ```
4. **If "NR" status persists**: Restart cluster services
   ```bash
   ssh root@192.168.20.22 "systemctl restart pve-cluster && systemctl restart corosync"
   ```

**Verification of Recovery**:
```bash
# All nodes should show "online" status
ssh root@192.168.20.22 "pvesh get /cluster/resources --type node"

# Cluster should show quorate with all nodes
ssh root@192.168.20.22 "pvecm status"

# Corosync logs should show successful cluster join
ssh root@192.168.20.22 "journalctl -u corosync -n 50 | grep -E 'Members|quorum'"
```

**Expected Healthy Output**:
- Node status: "online" in cluster resources
- Quorum status: "Quorate: Yes"
- Corosync logs: "Members[3]: 1 2 3"
- Message: "This node is within the primary component and will provide service"

**Prevention**:
- Investigate unexpected shutdown causes (check system logs, UPS status, scheduled tasks)
- Set up monitoring for node health and unexpected shutdowns
- Consider IPMI/BMC setup for remote power management

**Result**: Node03 successfully recovered and rejoined cluster after power-on. All services restored to normal operation.

#### Connection Refused Errors
- **Symptom**: `dial tcp 192.168.20.21:8006: connectex: No connection could be made`
- **Cause**: Proxmox API temporarily unavailable during heavy operations
- **Solution**: Wait and retry, or check Proxmox node status

#### Template Not Found (LXC)
- **Symptom**: `template 'local:vztmpl/...' does not exist`
- **Solution**: SSH to target node and download template with `pveam download`

#### Tainted Resources
- **Symptom**: Resources marked as tainted, requiring replacement
- **Solution**: Run `terraform apply` to recreate them properly

#### State Lock
- **Symptom**: Terraform state is locked
- **Solution**: Ensure no other terraform operations are running, or force unlock with caution

### Useful Commands

```bash
# Check Terraform state
terraform state list

# Show specific resource
terraform state show module.vms["k8s-controlplane01"].proxmox_vm_qemu.linux_vm

# Refresh state
terraform refresh

# Validate configuration
terraform validate

# Format configuration files
terraform fmt
```

## Security Considerations

1. **API Tokens**: Stored in `terraform.tfvars` (excluded from git)
2. **SSH Keys**: Public key only in configuration
3. **Unprivileged LXC**: Default for security
4. **Network Segmentation**: VLANs separate workloads
5. **Cloud-init**: Automated security updates possible

## Future Expansion

### Planned Services
- **Media Stack (arr suite)**: Radarr, Sonarr, Plex with dedicated media storage
- Additional LXC containers for lightweight services
- Monitoring stack (Prometheus, Grafana)
- GitLab or similar CI/CD
- Database containers (PostgreSQL, Redis)

### IP Reservation
Keep IP ranges available for future growth:
- VLAN 20: 192.168.20.101-199 (LXC containers)
- VLAN 40: 192.168.40.50-99 (Future services)

## Notes

- All VMs use Ubuntu 24.04 LTS cloud-init template
- LXC containers use Ubuntu 22.04 LTS or Debian 12
- VLAN 20 uses `vlan_tag = null` (default VLAN on vmbr0)
- VLAN 40 uses explicit `vlan_tag = 40`
- Auto-start enabled on all production infrastructure
- Proxmox node02 dedicated to containers for resource isolation
