# =============================================================================
# Packer Template: Windows 11 for Proxmox VE
# =============================================================================
#
# This template creates a Windows 11 Pro base image on Proxmox with:
# - BIOS mode with MBR partitions (bypasses TPM/Secure Boot requirements)
# - VirtIO drivers installed via FirstLogonCommands
# - WinRM enabled for Ansible connectivity
# - QEMU Guest Agent installed
# - Sysprep ready for cloning
#
# Prerequisites:
#   1. Windows 11 ISO uploaded to Proxmox local storage (win11.iso)
#   2. VirtIO drivers ISO uploaded (virtio-win.iso)
#   3. Proxmox API token with appropriate permissions
#
# Usage:
#   cd packer/windows-11-proxmox
#   packer init .
#   packer build -var-file="variables.pkrvars.hcl" .
# =============================================================================

packer {
  required_version = ">= 1.9.0"

  required_plugins {
    proxmox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/proxmox"
    }
    windows-update = {
      version = ">= 0.14.0"
      source  = "github.com/rgl/windows-update"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  type    = string
  default = "node03"
}

variable "proxmox_storage" {
  type    = string
  default = "VMDisks"
}

variable "proxmox_iso_storage" {
  type    = string
  default = "local"
}

variable "win11_iso_file" {
  type    = string
  default = "win11.iso"
}

variable "virtio_iso_file" {
  type    = string
  default = "virtio-win.iso"
}

variable "vm_id" {
  type    = number
  default = 9011
}

variable "vm_name" {
  type    = string
  default = "Win11-Template"
}

variable "admin_username" {
  type    = string
  default = "Administrator"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "vm_cores" {
  type    = number
  default = 2
}

variable "vm_memory" {
  type    = number
  default = 4096
}

variable "vm_disk_size" {
  type    = string
  default = "60G"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "timezone" {
  type    = string
  default = "Singapore Standard Time"
}

variable "skip_windows_updates" {
  type    = bool
  default = true
}

variable "winrm_host" {
  type    = string
  default = "192.168.20.97"
}

# =============================================================================
# Locals
# =============================================================================

locals {
  timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())
}

# =============================================================================
# Source: Proxmox ISO Builder
# =============================================================================

source "proxmox-iso" "win11" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  # VM Settings
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_description = "Windows 11 Pro - Built ${local.timestamp} - Hybrid Lab"

  # Hardware - BIOS mode (bypasses TPM/Secure Boot requirements)
  cores      = var.vm_cores
  memory     = var.vm_memory
  cpu_type   = "host"
  os         = "win11"
  bios       = "seabios"
  machine    = "q35"
  qemu_agent = true

  boot = "order=ide2;ide0;net0"

  # Disk - IDE for native Windows support
  disks {
    type         = "ide"
    disk_size    = var.vm_disk_size
    storage_pool = var.proxmox_storage
    format       = "raw"
  }

  # Network - Native VLAN 20 (no tag)
  network_adapters {
    model    = "virtio"
    bridge   = var.bridge
    firewall = false
  }

  # ISO Configuration
  iso_file = "${var.proxmox_iso_storage}:iso/${var.win11_iso_file}"

  # VirtIO drivers ISO
  additional_iso_files {
    device           = "sata0"
    iso_file         = "${var.proxmox_iso_storage}:iso/${var.virtio_iso_file}"
    unmount          = true
    iso_storage_pool = var.proxmox_iso_storage
  }

  # Autounattend ISO (pre-built and uploaded to Proxmox)
  additional_iso_files {
    device           = "ide3"
    iso_file         = "${var.proxmox_iso_storage}:iso/win11-autounattend.iso"
    unmount          = true
    iso_storage_pool = var.proxmox_iso_storage
  }

  # Boot Configuration
  boot_wait    = "3s"
  boot_command = [
    "<spacebar><spacebar><spacebar><spacebar><spacebar>",
    "<wait3>",
    "<spacebar><spacebar><spacebar><spacebar><spacebar>"
  ]

  # WinRM Communicator
  communicator   = "winrm"
  winrm_username = var.admin_username
  winrm_password = var.admin_password
  winrm_timeout  = "4h"
  winrm_use_ssl  = false
  winrm_insecure = true
  winrm_port     = 5985
  winrm_host     = var.winrm_host

  task_timeout = "30m"
  onboot       = false
}

# =============================================================================
# Build
# =============================================================================

build {
  name    = "windows-11"
  sources = ["source.proxmox-iso.win11"]

  provisioner "powershell" {
    inline = [
      "Write-Host 'WinRM is available!'",
      "Write-Host \"Hostname: $env:COMPUTERNAME\"",
      "Write-Host \"OS: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)\""
    ]
  }

  # Install QEMU Guest Agent
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing QEMU Guest Agent...'",
      "$drives = @('E:', 'D:', 'F:', 'G:')",
      "$installer = $null",
      "foreach ($drive in $drives) {",
      "    $path = Join-Path $drive 'guest-agent\\qemu-ga-x86_64.msi'",
      "    if (Test-Path $path) {",
      "        $installer = $path",
      "        break",
      "    }",
      "}",
      "if ($installer) {",
      "    Start-Process msiexec.exe -ArgumentList '/i', $installer, '/quiet', '/norestart' -Wait",
      "    Write-Host 'QEMU Guest Agent installed successfully'",
      "} else {",
      "    Write-Host 'QEMU Guest Agent installer not found'",
      "}"
    ]
  }

  # Final configuration
  provisioner "powershell" {
    inline = [
      "Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0",
      "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'",
      "powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c",
      "powercfg /hibernate off",
      "New-NetFirewallRule -DisplayName 'ICMPv4' -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow -ErrorAction SilentlyContinue",
      "Remove-Item -Path $env:TEMP\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path C:\\Windows\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue"
    ]
  }

  # Sysprep for cloning
  provisioner "powershell" {
    inline = [
      "Write-Host 'Running Sysprep...'",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /generalize /oobe /shutdown /quiet"
    ]
  }
}
