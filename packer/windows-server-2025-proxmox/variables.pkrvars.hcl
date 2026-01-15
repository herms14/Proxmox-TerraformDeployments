# =============================================================================
# Packer Variables for Windows Server 2025 - Proxmox VE
# =============================================================================
# Copy this file to variables.pkrvars.hcl and fill in your values
# Usage: packer build -var-file="variables.pkrvars.hcl" .
# =============================================================================

# Proxmox Connection
proxmox_api_url          = "https://192.168.20.21:8006/api2/json"
proxmox_api_token_id     = "terraform-deployment-user@pve!tf"
proxmox_api_token_secret = "d46fa6bb-5430-4c2c-9ab6-de4c5aba6d9a"

# Build Location
proxmox_node        = "node03"
proxmox_storage     = "VMDisks"
proxmox_iso_storage = "local"

# ISO Files (on Proxmox local storage - copied for faster boot)
ws2025_iso_file  = "ws2025.iso"
virtio_iso_file  = "virtio-win.iso"

# Template Configuration
vm_id   = 9025
vm_name = "WS2025-Template"

# VM Resources
vm_cores    = 2
vm_memory   = 4096
vm_disk_size = "60G"

# Network Configuration (VLAN 80 - Hybrid Lab)
vlan_tag = 80
bridge   = "vmbr0"

# WinRM Build Configuration
winrm_host = "192.168.80.99"

# Administrator Credentials
admin_username = "Administrator"
admin_password = "c@llimachus14"

# Optional Settings
timezone             = "Singapore Standard Time"
skip_windows_updates = true
