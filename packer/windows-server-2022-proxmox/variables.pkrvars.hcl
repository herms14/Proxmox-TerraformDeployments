# =============================================================================
# Packer Variables for Windows Server 2022 - Proxmox VE
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
ws2022_iso_file  = "ws2022.iso"
virtio_iso_file  = "virtio-win.iso"

# Template Configuration
vm_id   = 9022
vm_name = "WS2022-Template"

# VM Resources
vm_cores    = 2
vm_memory   = 4096
vm_disk_size = "60G"

# Network Configuration (native VLAN 20 - no tag needed)
bridge = "vmbr0"

# WinRM Build Configuration
winrm_host = "192.168.20.98"

# Administrator Credentials
admin_username = "Administrator"
admin_password = "c@llimachus14"

# Optional Settings
timezone             = "Singapore Standard Time"
skip_windows_updates = true
