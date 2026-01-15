# =============================================================================
# Packer Variables for Windows 11 - Proxmox VE
# =============================================================================

# Proxmox Connection
proxmox_api_url          = "https://192.168.20.22:8006/api2/json"
proxmox_api_token_id     = "terraform-deployment-user@pve!tf"
proxmox_api_token_secret = "d46fa6bb-5430-4c2c-9ab6-de4c5aba6d9a"

# Build Location
proxmox_node        = "node03"
proxmox_storage     = "VMDisks"
proxmox_iso_storage = "local"

# ISO Files
win11_iso_file  = "win11.iso"
virtio_iso_file = "virtio-win.iso"

# Template Configuration
vm_id   = 9011
vm_name = "Win11-Template"

# VM Resources
vm_cores    = 2
vm_memory   = 4096
vm_disk_size = "60G"

# Network Configuration (native VLAN 20 - no tag needed)
bridge = "vmbr0"

# WinRM Build Configuration
winrm_host = "192.168.20.97"

# User Credentials (custom packeruser account)
admin_username = "packeruser"
admin_password = "c@llimachus14"

# Optional Settings
timezone             = "Singapore Standard Time"
skip_windows_updates = true
