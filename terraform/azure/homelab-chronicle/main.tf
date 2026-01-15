# Homelab Chronicle LXC Container
# Timeline visualization app for homelab documentation
#
# Deploy:
#   cd terraform/homelab-chronicle
#   terraform init
#   terraform plan
#   terraform apply

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.20.21:8006/api2/json"
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Proxmox node to deploy to"
  type        = string
  default     = "node02"
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = split("=", var.proxmox_api_token)[0]
  pm_api_token_secret = split("=", var.proxmox_api_token)[1]
  pm_tls_insecure     = true
}

resource "proxmox_lxc" "chronicle" {
  vmid         = 207
  hostname     = "chronicle-lxc"
  target_node  = var.target_node
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

  cores        = 2
  memory       = 2048
  swap         = 512

  unprivileged = true
  start        = true
  onboot       = true

  # Root filesystem
  rootfs {
    storage = "local-lvm"
    size    = "20G"
  }

  # Network configuration - VLAN 40 (Services)
  network {
    name   = "eth0"
    bridge = "vmbr0"
    tag    = 40
    ip     = "192.168.40.15/24"
    gw     = "192.168.40.1"
  }

  # DNS
  nameserver = "192.168.90.53"
  searchdomain = "hrmsmrflrii.xyz"

  # SSH public key for access
  ssh_public_keys = <<-EOT
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINVYlOowJQE4tC4GEo17MptDGdaQfWwMDMRxLdKd/yui hermes@homelab-nopass
  EOT

  # Features needed for Docker
  features {
    nesting = true
    keyctl  = true
  }

  # Tags for organization
  tags = "chronicle,services,docker"

  lifecycle {
    ignore_changes = [
      ssh_public_keys,
    ]
  }
}

output "container_id" {
  value       = proxmox_lxc.chronicle.vmid
  description = "The VMID of the Chronicle LXC container"
}

output "container_ip" {
  value       = "192.168.40.15"
  description = "The IP address of the Chronicle container"
}

output "container_hostname" {
  value       = proxmox_lxc.chronicle.hostname
  description = "The hostname of the Chronicle container"
}

output "next_steps" {
  value = <<-EOT
    Next steps after LXC creation:
    1. SSH into the container: ssh root@192.168.40.15
    2. Install Docker: apt update && apt install -y docker.io docker-compose
    3. Run Ansible playbook: ansible-playbook services/deploy-homelab-chronicle.yml
  EOT
  description = "Post-deployment instructions"
}
