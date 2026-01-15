# Azure Hybrid Lab - Proxmox VM Deployment

Deploy Windows Server 2022 VMs to Proxmox VE by cloning from a Packer-built template.

## Overview

This Terraform configuration deploys 12 Windows Server 2022 VMs for the Azure Hybrid Lab environment:

- **Template-Based Deployment**: Clone VMs from pre-built Packer template (ID 9022)
- **Fully Automated**: VMs boot directly to desktop with WinRM enabled
- **VLAN 80 Network**: All VMs on 192.168.80.0/24 subnet
- **Ready for Ansible**: WinRM and PowerShell remoting pre-configured

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         PROXMOX CLUSTER (MorpheusCluster)                     │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  Template 9022                    Cloned VMs (12 total)                       │
│  ┌─────────────┐                  ┌──────────────────────────────────────┐   │
│  │ WS2022-TPL  │  ────clone────►  │  DC01 (300)    DC02 (301)           │   │
│  │ Sysprep'd   │                  │  FS01 (302)    FS02 (303)           │   │
│  │ WinRM Ready │                  │  SQL01 (304)   AADCON01 (305)       │   │
│  └─────────────┘                  │  AADPP01 (306) AADPP02 (307)        │   │
│                                   │  CLIENT01 (308) CLIENT02 (309)      │   │
│  Storage: local-lvm               │  IIS01 (310)   IIS02 (311)          │   │
│                                   └──────────────────────────────────────┘   │
│                                              │                                │
│                                              ▼                                │
│                                   ┌──────────────────────────────────────┐   │
│                                   │         VLAN 80 Network               │   │
│                                   │     192.168.80.0/24 (vmbr0)          │   │
│                                   └──────────────────────────────────────┘   │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

## VM Inventory

| VM | VMID | Role | Planned IP | Cores | RAM |
|----|------|------|------------|-------|-----|
| DC01 | 300 | Primary Domain Controller | 192.168.80.2 | 2 | 4 GB |
| DC02 | 301 | Secondary Domain Controller | 192.168.80.3 | 2 | 4 GB |
| FS01 | 302 | File Server | 192.168.80.4 | 2 | 2 GB |
| FS02 | 303 | File Server | 192.168.80.5 | 2 | 2 GB |
| SQL01 | 304 | SQL Server | 192.168.80.6 | 4 | 8 GB |
| AADCON01 | 305 | Entra ID Connect | 192.168.80.7 | 2 | 4 GB |
| AADPP01 | 306 | Password Protection Proxy | 192.168.80.8 | 2 | 2 GB |
| AADPP02 | 307 | Password Protection Proxy | 192.168.80.9 | 2 | 2 GB |
| CLIENT01 | 308 | Domain Workstation | 192.168.80.12 | 2 | 2 GB |
| CLIENT02 | 309 | Domain Workstation | 192.168.80.13 | 2 | 2 GB |
| IIS01 | 310 | Web Server | 192.168.80.10 | 2 | 2 GB |
| IIS02 | 311 | Web Server | 192.168.80.11 | 2 | 2 GB |

**Total Resources**: 24 cores, 38 GB RAM, 720 GB storage (12 × 60 GB)

---

## Files Structure

```
terraform/proxmox/
├── main.tf                    # VM definitions (ISO-based, when use_template=false)
├── main-from-template.tf      # VM definitions (template-based, when use_template=true)
├── variables.tf               # Variable declarations
├── terraform.tfvars           # Your configuration (gitignored)
├── terraform.tfvars.example   # Variable template
└── README.md                  # This documentation
```

---

## Detailed File Explanations

### 1. main.tf (ISO-Based Deployment)

Used when `use_template = false`. Creates VMs with blank disks and attaches Windows ISO for manual installation.

```hcl
# Only created when NOT using template
resource "proxmox_virtual_environment_vm" "windows_vm" {
  for_each = var.use_template ? {} : local.all_vms

  name        = each.key           # e.g., "DC01"
  description = each.value.role    # e.g., "Primary Domain Controller"
  tags        = ["windows", "azure-hybrid-lab", each.value.role]

  node_name = each.value.node      # All on node03
  vm_id     = each.value.vmid      # e.g., 300

  # UEFI Configuration
  machine = "q35"                  # Modern chipset
  bios    = "ovmf"                 # UEFI boot

  # Hardware
  cpu {
    cores   = 2
    sockets = 1
    type    = "host"               # Pass-through CPU features
  }

  memory {
    dedicated = 2048               # 2 GB RAM
    floating  = 0                  # No memory ballooning
  }

  # EFI disk (required for UEFI)
  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  # OS disk - VirtIO SCSI
  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    size         = 60              # 60 GB
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  # CD-ROM with Windows ISO
  cdrom {
    file_id   = "ISOs:iso/${var.windows_iso}"
    interface = "ide2"
  }

  # Network - VirtIO on VLAN 80
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 80
  }

  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
    type    = "virtio"
  }
}
```

### 2. main-from-template.tf (Template-Based Deployment)

Used when `use_template = true`. Clones VMs from Packer template 9022.

```hcl
resource "proxmox_virtual_environment_vm" "windows_vm_from_template" {
  for_each = var.use_template ? local.all_vms : {}

  name        = each.key
  description = each.value.role
  tags        = ["windows", "azure-hybrid-lab", each.value.role]

  node_name = each.value.node
  vm_id     = each.value.vmid

  # Clone from template
  clone {
    vm_id = var.vm_template_id     # 9022
    full  = true                   # Full clone (not linked)
  }

  # Must match template settings
  machine = "q35"
  bios    = "ovmf"
  on_boot = false                  # Don't auto-start

  # CPU (can be customized per VM)
  cpu {
    cores   = lookup(local.vm_hardware, each.key, { cores = 2 }).cores
    sockets = 1
    type    = "host"
  }

  # Memory (can be customized per VM)
  memory {
    dedicated = lookup(local.vm_hardware, each.key, { memory = 2048 }).memory
    floating  = 0
  }

  # Network - VirtIO on VLAN 80
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 80
  }

  agent {
    enabled = true
    type    = "virtio"
  }
}
```

#### Hardware Customization Per Role

```hcl
locals {
  vm_hardware = {
    DC01     = { cores = 2, memory = 4096 }   # Domain Controller needs more RAM
    DC02     = { cores = 2, memory = 4096 }
    SQL01    = { cores = 4, memory = 8192 }   # SQL Server needs more resources
    AADCON01 = { cores = 2, memory = 4096 }   # Entra Connect is resource hungry
    # All others default to 2 cores, 2048 MB
  }
}
```

### 3. variables.tf

```hcl
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.20.20:8006"
}

variable "proxmox_api_token" {
  description = "Proxmox API token (format: user@realm!tokenid=token-secret)"
  type        = string
  sensitive   = true
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for Proxmox nodes"
  type        = string
  default     = "~/.ssh/homelab_ed25519"
}

variable "use_template" {
  description = "Clone VMs from template instead of installing from ISO"
  type        = bool
  default     = false
}

variable "vm_template_id" {
  description = "VM ID of the Windows Server 2022 template (created by Packer)"
  type        = number
  default     = 9022
}

variable "admin_password" {
  description = "Administrator password for Windows VMs"
  type        = string
  sensitive   = true
  default     = "c@llimachus14"
}
```

### 4. terraform.tfvars

```hcl
# Proxmox API configuration
proxmox_api_url   = "https://192.168.20.22:8006"
proxmox_api_token = "terraform-deployment-user@pve!tf=your-token-secret"

# SSH key for Proxmox nodes (used by bpg/proxmox provider)
ssh_private_key_path = "~/.ssh/homelab_ed25519"

# Template-based deployment
use_template   = true
vm_template_id = 9022

# Administrator password
admin_password = "c@llimachus14"
```

---

## Deployment Process

### Prerequisites

1. **Packer Template Built**: Template 9022 must exist on Proxmox
   ```bash
   # Verify template exists
   ssh root@192.168.20.22 "qm list | grep 9022"
   ```

2. **API Token Created**: On Proxmox UI
   - Datacenter → Permissions → API Tokens
   - User: `terraform-deployment-user@pve`
   - Token ID: `tf`

3. **Terraform Installed**:
   ```bash
   terraform version  # Must be >= 1.0
   ```

### Deployment Steps

```bash
# Navigate to Terraform directory
cd ~/azure-hybrid-lab/terraform/proxmox

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars
# Edit with your API token

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Deploy VMs (takes ~30 minutes for 12 VMs)
terraform apply -auto-approve
```

### What Happens During Deployment

1. **Terraform Connects** to Proxmox API
2. **Clone Operations** start for all 12 VMs in parallel
3. **Disk Copy** takes ~2-3 minutes per VM (60 GB each)
4. **VM Configuration** applied (CPU, memory, network)
5. **VMs Start** and boot from cloned disk
6. **Sysprep Unattend** runs, skipping OOBE
7. **Auto-Logon** occurs as Administrator
8. **WinRM Enabled** via FirstLogonCommands

**Total Time**: ~30 minutes (clone operations run in parallel)

---

## Post-Deployment

### Verify VMs are Running

```bash
# Check all VMs via Proxmox
ssh root@192.168.20.22 "qm list | grep -E '30[0-9]|31[01]'"

# Check QEMU guest agent status
ssh root@192.168.20.22 "qm guest exec 300 -- ipconfig"
```

### Verify WinRM Connectivity

```bash
# From Ansible controller
ansible windows_vms -m win_ping -i inventory/hosts.yml
```

### Configure Static IPs

The VMs boot with DHCP. Use Ansible to configure static IPs:

```bash
cd ~/azure-hybrid-lab/ansible
ansible-playbook playbooks/configure-network.yml
```

---

## Terraform State

### View Deployed VMs

```bash
terraform state list
```

Output:
```
proxmox_virtual_environment_vm.windows_vm_from_template["AADCON01"]
proxmox_virtual_environment_vm.windows_vm_from_template["AADPP01"]
proxmox_virtual_environment_vm.windows_vm_from_template["AADPP02"]
proxmox_virtual_environment_vm.windows_vm_from_template["CLIENT01"]
proxmox_virtual_environment_vm.windows_vm_from_template["CLIENT02"]
proxmox_virtual_environment_vm.windows_vm_from_template["DC01"]
proxmox_virtual_environment_vm.windows_vm_from_template["DC02"]
proxmox_virtual_environment_vm.windows_vm_from_template["FS01"]
proxmox_virtual_environment_vm.windows_vm_from_template["FS02"]
proxmox_virtual_environment_vm.windows_vm_from_template["IIS01"]
proxmox_virtual_environment_vm.windows_vm_from_template["IIS02"]
proxmox_virtual_environment_vm.windows_vm_from_template["SQL01"]
```

### View Outputs

```bash
terraform output cloned_vm_info
```

---

## Destroy VMs

```bash
# Destroy all VMs (keeps template)
terraform destroy
```

Or destroy specific VMs:

```bash
terraform destroy -target='proxmox_virtual_environment_vm.windows_vm_from_template["CLIENT01"]'
```

---

## Troubleshooting

### Clone Fails with "config file already exists"

**Cause**: Previous clone attempt left partial VM

**Solution**:
```bash
# Remove partial VM from Proxmox
ssh root@192.168.20.22 "qm destroy 308 --purge"

# Retry Terraform
terraform apply
```

### API Token Invalid (401 Error)

**Cause**: Wrong token format

**Solution**: Token format must be `user@realm!tokenid=secret`
```hcl
# Correct format
proxmox_api_token = "terraform-deployment-user@pve!tf=d46fa6bb-5430-4c2c-9ab6-de4c5aba6d9a"

# Wrong format
proxmox_api_token = "d46fa6bb-5430-4c2c-9ab6-de4c5aba6d9a"  # Missing user/token ID
```

### Clone Times Out

**Cause**: Cloning 60 GB disks takes time

**Solution**: The provider has 30-minute timeout by default. Wait for completion or increase timeout:
```hcl
timeout_clone = 3600  # 1 hour
```

### VMs Don't Have Network

**Cause**: VLAN 80 not configured on switch

**Solution**: Ensure switch port for Proxmox node has VLAN 80 tagged

---

## Provider Reference

This configuration uses the **bpg/proxmox** provider:

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.50.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true  # Skip TLS verification for self-signed certs

  ssh {
    agent       = false
    username    = "root"
    private_key = file(var.ssh_private_key_path)
  }
}
```

The SSH configuration is required for certain operations like disk resize. Ensure the SSH key is accessible.
