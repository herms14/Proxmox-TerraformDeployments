# =============================================================================
# Variables for Hybrid Lab VM Deployment
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Connection
# -----------------------------------------------------------------------------

variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.20.22:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  default     = "terraform-deployment-user@pve!tf"
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Template Names
# -----------------------------------------------------------------------------

variable "ws2025_template" {
  description = "Windows Server 2025 template name"
  type        = string
  default     = "WS2025-Template"
}

variable "ws2022_template" {
  description = "Windows Server 2022 template name"
  type        = string
  default     = "WS2022-Template"
}

variable "win11_template" {
  description = "Windows 11 template name"
  type        = string
  default     = "Win11-Template"
}

# -----------------------------------------------------------------------------
# Storage Configuration
# -----------------------------------------------------------------------------

variable "storage_pool" {
  description = "Proxmox storage pool for VM disks"
  type        = string
  default     = "VMDisks"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vlan_tag" {
  description = "VLAN tag for Hybrid Lab network"
  type        = number
  default     = 80
}

variable "gateway" {
  description = "Default gateway for VLAN 80"
  type        = string
  default     = "192.168.80.1"
}

# -----------------------------------------------------------------------------
# Domain Configuration
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
  default     = "hrmsmrflrii.xyz"
}

variable "netbios_name" {
  description = "NetBIOS domain name"
  type        = string
  default     = "HRMSMRFLRII"
}
