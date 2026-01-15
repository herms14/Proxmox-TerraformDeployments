# =============================================================================
# Terraform Configuration: Hybrid Lab VMs on Proxmox
# =============================================================================
#
# Deploys 10 VMs for the Azure Hybrid Lab (hrmsmrflrii.xyz domain):
#   - 2x Domain Controllers (WS2025) on node03
#   - 2x File Servers (WS2022) on node03
#   - 1x SQL Server (WS2025) on node03
#   - 1x AD Connect Server (WS2022) on node03
#   - 2x Password Protection Proxies (WS2025) on node03
#   - 2x Windows 11 Clients on node01
#
# Usage:
#   cd terraform/hybrid-lab
#   terraform init
#   terraform plan
#   terraform apply
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 2.9.0"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
  pm_parallel         = 2
  pm_timeout          = 600
}

# =============================================================================
# Domain Controllers (Windows Server 2025)
# =============================================================================

module "dc01" {
  source = "../modules/windows-vm"

  vm_name       = "DC01"
  target_node   = "node03"
  template_name = var.ws2025_template

  cores       = 2
  sockets     = 1
  memory      = 4096
  disk_size   = "60G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.2"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}

module "dc02" {
  source = "../modules/windows-vm"

  vm_name       = "DC02"
  target_node   = "node03"
  template_name = var.ws2025_template

  cores       = 2
  sockets     = 1
  memory      = 4096
  disk_size   = "60G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.3"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}

# =============================================================================
# File Servers (Windows Server 2022)
# =============================================================================

module "fs01" {
  source = "../modules/windows-vm"

  vm_name       = "FS01"
  target_node   = "node03"
  template_name = var.ws2022_template

  cores       = 2
  sockets     = 1
  memory      = 4096
  disk_size   = "100G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.4"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}

module "fs02" {
  source = "../modules/windows-vm"

  vm_name       = "FS02"
  target_node   = "node03"
  template_name = var.ws2022_template

  cores       = 2
  sockets     = 1
  memory      = 4096
  disk_size   = "100G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.5"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}

# =============================================================================
# SQL Server (Windows Server 2025)
# =============================================================================

module "sql01" {
  source = "../modules/windows-vm"

  vm_name       = "SQL01"
  target_node   = "node03"
  template_name = var.ws2025_template

  cores       = 4
  sockets     = 1
  memory      = 8192
  disk_size   = "120G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.6"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}

# =============================================================================
# AD Connect Server (Windows Server 2022)
# =============================================================================

module "aadcon01" {
  source = "../modules/windows-vm"

  vm_name       = "AADCON01"
  target_node   = "node03"
  template_name = var.ws2022_template

  cores       = 2
  sockets     = 1
  memory      = 4096
  disk_size   = "60G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.7"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}

# =============================================================================
# Password Protection Proxy Servers (Windows Server 2025)
# =============================================================================

module "aadpp01" {
  source = "../modules/windows-vm"

  vm_name       = "AADPP01"
  target_node   = "node03"
  template_name = var.ws2025_template

  cores       = 2
  sockets     = 1
  memory      = 4096
  disk_size   = "60G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.8"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}

module "aadpp02" {
  source = "../modules/windows-vm"

  vm_name       = "AADPP02"
  target_node   = "node03"
  template_name = var.ws2025_template

  cores       = 2
  sockets     = 1
  memory      = 4096
  disk_size   = "60G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.9"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}

# =============================================================================
# Windows 11 Clients (on node01)
# =============================================================================

module "client01" {
  source = "../modules/windows-vm"

  vm_name       = "CLIENT01"
  target_node   = "node01"
  template_name = var.win11_template

  cores       = 2
  sockets     = 1
  memory      = 4096
  disk_size   = "60G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.12"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}

module "client02" {
  source = "../modules/windows-vm"

  vm_name       = "CLIENT02"
  target_node   = "node01"
  template_name = var.win11_template

  cores       = 2
  sockets     = 1
  memory      = 4096
  disk_size   = "60G"
  storage     = var.storage_pool

  network_bridge = var.network_bridge
  vlan_tag       = var.vlan_tag
  use_dhcp       = false
  ip_address     = "192.168.80.13"
  subnet_mask    = 24
  gateway        = var.gateway

  onboot             = true
  qemu_agent_enabled = true
}
