# Azure Hybrid Lab - Proxmox Windows VMs
# Deploys Windows Server 2022 VMs for Active Directory lab

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.50.0"
    }
  }
}

# Provider configuration
provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true

  ssh {
    agent    = false
    username = "root"
    private_key = file(var.ssh_private_key_path)
  }
}

# Local variables
locals {
  # All VMs deployed to node03 (where template 9022 is located)
  # Can be migrated to other nodes after deployment if needed
  node03_vms = ["DC01", "DC02", "FS01", "FS02", "SQL01", "AADCON01", "AADPP01", "AADPP02", "IIS01", "IIS02", "CLIENT01", "CLIENT02", "SQL-FABRIC"]

  # VM configurations (VLAN 80 - 192.168.80.0/24)
  vm_configs = {
    DC01       = { vmid = 300, role = "Primary Domain Controller", ip = "192.168.80.2" }
    DC02       = { vmid = 301, role = "Secondary Domain Controller", ip = "192.168.80.3" }
    FS01       = { vmid = 302, role = "File Server", ip = "192.168.80.4" }
    FS02       = { vmid = 303, role = "File Server", ip = "192.168.80.5" }
    SQL01      = { vmid = 304, role = "SQL Server", ip = "192.168.80.6" }
    AADCON01   = { vmid = 305, role = "Entra ID Connect", ip = "192.168.80.7" }
    AADPP01    = { vmid = 306, role = "Password Protection Proxy", ip = "192.168.80.8" }
    AADPP02    = { vmid = 307, role = "Password Protection Proxy", ip = "192.168.80.9" }
    IIS01      = { vmid = 310, role = "Web Server", ip = "192.168.80.10" }
    IIS02      = { vmid = 311, role = "Web Server", ip = "192.168.80.11" }
    CLIENT01   = { vmid = 308, role = "Domain Workstation", ip = "192.168.80.12" }
    CLIENT02   = { vmid = 309, role = "Domain Workstation", ip = "192.168.80.13" }
    SQL-FABRIC = { vmid = 312, role = "SQL Server for Fabric Migration", ip = "192.168.80.14" }
  }

  # All VMs on node03 for now (template is there)
  all_vms = { for name in local.node03_vms : name => merge(local.vm_configs[name], { node = "node03" }) }
}

# Windows Server 2022 VMs (from ISO - only when NOT using template)
resource "proxmox_virtual_environment_vm" "windows_vm" {
  for_each = var.use_template ? {} : local.all_vms

  name        = each.key
  description = each.value.role
  tags        = ["windows", "azure-hybrid-lab", each.value.role]

  node_name = each.value.node
  vm_id     = each.value.vmid

  # Machine type and BIOS
  machine     = "q35"
  bios        = "ovmf"  # UEFI for Windows
  on_boot     = false   # Don't auto-start

  # CPU
  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  # Memory - 2GB as requested
  memory {
    dedicated = 2048
    floating  = 0
  }

  # EFI disk (required for UEFI boot)
  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  # TPM (for Windows 11 clients, optional for Server)
  tpm_state {
    datastore_id = "local-lvm"
    version      = "v2.0"
  }

  # OS disk with VirtIO SCSI
  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    size         = 60  # 60GB for Windows
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  # CD-ROM for Windows ISO (VirtIO drivers will be attached manually after creation)
  cdrom {
    file_id   = "ISOs:iso/${var.windows_iso}"
    interface = "ide2"
  }

  # Network - VirtIO on VLAN 80 (Azure Hybrid Lab network)
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 80
  }

  # SCSI controller
  scsi_hardware = "virtio-scsi-single"

  # Guest agent
  agent {
    enabled = true
    type    = "virtio"
  }

  # VGA
  vga {
    type   = "qxl"
    memory = 32
  }

  # Operating system type
  operating_system {
    type = "win11"  # Use win11 for modern Windows
  }

  # Lifecycle
  lifecycle {
    ignore_changes = [
      cdrom,  # Ignore after initial install
    ]
  }
}

# Output VM information
output "vm_info" {
  description = "Windows VM information"
  value = {
    for name, vm in proxmox_virtual_environment_vm.windows_vm : name => {
      vmid = vm.vm_id
      node = vm.node_name
      ip   = local.all_vms[name].ip
      role = local.all_vms[name].role
    }
  }
}

output "deployment_summary" {
  description = "Deployment summary"
  value = "Azure Hybrid Lab: ${length(local.node03_vms)} VMs deployed to node03. Run Ansible playbooks to configure."
}
