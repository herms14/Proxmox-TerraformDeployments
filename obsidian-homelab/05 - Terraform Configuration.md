# Terraform Configuration

> **Internal Documentation** - Contains module structure and deployment patterns.

Related: [[00 - Homelab Index]] | [[02 - Proxmox Cluster]] | [[06 - Ansible Automation]]

---

## Overview

| Setting | Value |
|---------|-------|
| Provider | telmate/proxmox v3.0.2-rc06 |
| Reason | Compatibility with Proxmox VE 9.x |
| State | Local (terraform.tfstate) |

---

## Repository Structure

```
tf-proxmox/
├── main.tf                 # VM group definitions
├── lxc.tf                  # LXC container definitions
├── variables.tf            # Global variables
├── outputs.tf              # Output definitions
├── terraform.tfvars        # Variable values (gitignored)
├── modules/
│   ├── linux-vm/           # VM deployment module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── lxc/                # LXC deployment module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── ansible-playbooks/      # Ansible playbooks
```

---

## Key Features

- **Auto-incrementing hostnames**: Sequential naming (k8s-controller01, k8s-worker01)
- **Auto-incrementing IPs**: Automatic IP assignment from starting_ip
- **Dynamic resource creation**: Terraform for_each for scalable deployments
- **Cloud-init automation**: Fully automated VM provisioning
- **Ansible integration**: Centralized configuration management

---

## Adding New VM Groups

Edit `main.tf` and add to `vm_groups` local:

```hcl
new-service = {
  count         = 1
  starting_ip   = "192.168.20.50"
  starting_node = "node01"
  template      = "tpl-ubuntu-shared-v1"
  cores         = 4
  sockets       = 1
  memory        = 8192
  disk_size     = "20G"
  storage       = "VMDisks"
  vlan_tag      = null        # null for VLAN 20, 40 for VLAN 40
  gateway       = "192.168.20.1"
  nameserver    = "192.168.91.30"
}
```

### VLAN Configuration

**VLAN 20**:
```hcl
vlan_tag    = null
gateway     = "192.168.20.1"
nameserver  = "192.168.91.30"
starting_ip = "192.168.20.x"
```

**VLAN 40**:
```hcl
vlan_tag    = 40
gateway     = "192.168.40.1"
nameserver  = "192.168.91.30"
starting_ip = "192.168.40.x"
```

---

## Adding New LXC Containers

Edit `lxc.tf` and add to `lxc_groups` local:

```hcl
new-container = {
  count        = 1
  starting_ip  = "192.168.20.101"
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  unprivileged = true
  cores        = 1
  memory       = 512
  swap         = 256
  disk_size    = "8G"
  storage      = "local-lvm"
  vlan_tag     = null
  gateway      = "192.168.20.1"
  nameserver   = "192.168.91.30"
  nesting      = false
}
```

---

## Common Operations

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply all
terraform apply

# Deploy VMs only
terraform apply -target=module.vms

# Deploy LXC only
terraform apply -target=module.lxc

# View state
terraform state list

# Show resource
terraform state show <resource>
```

---

## Outputs

```bash
# View all VMs
terraform output vm_summary

# View all LXC containers
terraform output lxc_summary

# View IP mappings
terraform output vm_ips
terraform output lxc_ips
```

---

## Related Documentation

- [[02 - Proxmox Cluster]] - Node configuration
- [[03 - Storage Architecture]] - Storage references
- [[06 - Ansible Automation]] - Post-deployment automation
- [[10 - IP Address Map]] - IP allocation

