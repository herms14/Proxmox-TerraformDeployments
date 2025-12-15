# ISO-Based VM Deployments
# These VMs boot from Ubuntu Server ISO for manual installation
# After installation, use Ansible for configuration

locals {
  iso_vms = {
    # Ansible Control Nodes - Manual ISO Install
    ansible-control = {
      count       = 2
      starting_ip = "192.168.20.50"  # Reference only - set during manual install
      target_node = "node03"
      cores       = 4
      sockets     = 1
      memory      = 8192
      disk_size   = "20G"
      storage     = "VMDisks"
      iso         = "ISOs:iso/ubuntu-24.04.3-live-server-amd64.iso"
      # Network settings - no VLAN tag for simplicity
      network_bridge = "vmbr0"
      vlan_tag       = null
    }
  }

  # Generate flat map of ISO-based VMs
  iso_vm_list = flatten([
    for vm_prefix, config in local.iso_vms : [
      for i in range(1, config.count + 1) : {
        key            = "${vm_prefix}${format("%02d", i)}"
        vm_name        = "${vm_prefix}${format("%02d", i)}"
        target_node    = config.target_node
        cores          = config.cores
        sockets        = config.sockets
        memory         = config.memory
        disk_size      = config.disk_size
        storage        = config.storage
        iso            = config.iso
        network_bridge = config.network_bridge
        vlan_tag       = config.vlan_tag
      }
    ]
  ])

  iso_vms_map = { for vm in local.iso_vm_list : vm.key => vm }
}

# Create ISO-based VMs
resource "proxmox_vm_qemu" "iso_vm" {
  for_each = local.iso_vms_map

  # VM Identification
  name        = each.value.vm_name
  target_node = each.value.target_node
  desc        = "Manual ISO install - configure with Ansible after installation"

  # VM will boot from ISO for installation
  # No clone, no cloud-init

  # BIOS and boot
  bios = "seabios"
  boot = "order=scsi0;ide2"  # Try disk first, then cdrom

  # CPU and Memory
  cpu {
    cores   = each.value.cores
    sockets = each.value.sockets
    type    = "host"
  }
  memory = each.value.memory

  # VM behavior
  onboot = true
  agent  = 1
  scsihw = "lsi"

  # Network - Simple virtio NIC, no cloud-init
  network {
    id        = 0
    model     = "virtio"
    bridge    = each.value.network_bridge
    tag       = each.value.vlan_tag
    firewall  = false
  }

  # Disk - Empty disk for Ubuntu installation
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = each.value.storage
    size    = each.value.disk_size
  }

  # ISO mounted as CDROM
  disk {
    slot    = "ide2"
    type    = "cdrom"
    storage = "ISOs"
    iso     = each.value.iso
  }

  # Lifecycle
  lifecycle {
    ignore_changes = [
      boot,      # Don't change boot order after install
      disk,      # Don't recreate if disk changes
      network,   # Don't recreate if network tweaked
    ]
  }
}

# Outputs for ISO VMs
output "iso_vm_summary" {
  description = "Summary of ISO-based VMs (configure IPs during manual installation)"
  value = {
    for key, vm in proxmox_vm_qemu.iso_vm : key => {
      name        = vm.name
      id          = vm.id
      target_node = vm.target_node
      status      = "Ready for installation - access console to install Ubuntu"
    }
  }
}
