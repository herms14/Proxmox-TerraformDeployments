# =============================================================================
# Packer Template: Windows Server 2022 for Proxmox VE
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

variable "ws2022_iso_file" {
  type    = string
  default = "ws2022.iso"
}

variable "virtio_iso_file" {
  type    = string
  default = "virtio-win.iso"
}

variable "vm_id" {
  type    = number
  default = 9022
}

variable "vm_name" {
  type    = string
  default = "WS2022-Template"
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
  default = "192.168.20.98"
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

source "proxmox-iso" "ws2022" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  # VM Settings
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_description = "Windows Server 2022 Standard - Built ${local.timestamp} - Hybrid Lab"

  # Hardware - BIOS mode
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
  iso_file = "${var.proxmox_iso_storage}:iso/${var.ws2022_iso_file}"

  # VirtIO drivers ISO
  additional_iso_files {
    device           = "sata0"
    iso_file         = "${var.proxmox_iso_storage}:iso/${var.virtio_iso_file}"
    unmount          = true
    iso_storage_pool = var.proxmox_iso_storage
  }

  # Autounattend ISO
  additional_iso_files {
    device   = "ide3"
    cd_files = [
      "${path.root}/autounattend.xml"
    ]
    cd_label         = "OEMDRV"
    iso_storage_pool = var.proxmox_iso_storage
    unmount          = true
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
  name    = "windows-server-2022"
  sources = ["source.proxmox-iso.ws2022"]

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
      "Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose",
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
