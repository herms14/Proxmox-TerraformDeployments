# Proxmox Terraform Infrastructure

Terraform infrastructure-as-code for deploying VMs and LXC containers on a Proxmox VE 9.1.2 cluster. Designed for a homelab environment with Kubernetes, Docker services, and supporting infrastructure.

## Quick Reference

| Resource | Documentation |
|----------|---------------|
| **Network** | [docs/NETWORKING.md](./docs/NETWORKING.md) - VLANs, IPs, DNS, SSL |
| **Compute** | [docs/PROXMOX.md](./docs/PROXMOX.md) - Cluster nodes, VM/LXC standards |
| **Storage** | [docs/STORAGE.md](./docs/STORAGE.md) - NFS, Synology, storage pools |
| **Terraform** | [docs/TERRAFORM.md](./docs/TERRAFORM.md) - Modules, deployment |
| **Services** | [docs/SERVICES.md](./docs/SERVICES.md) - Docker services |
| **Ansible** | [docs/ANSIBLE.md](./docs/ANSIBLE.md) - Automation, playbooks |
| **Inventory** | [docs/INVENTORY.md](./docs/INVENTORY.md) - Deployed infrastructure |
| **Troubleshooting** | [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) - Common issues |

## Infrastructure Overview

### Proxmox Cluster

| Node | IP | Purpose |
|------|----|---------|
| node01 | 192.168.20.20 | VM Host |
| node02 | 192.168.20.21 | LXC/Service Host |
| node03 | 192.168.20.22 | Kubernetes |

### Networks

| VLAN | Network | Purpose |
|------|---------|---------|
| VLAN 20 | 192.168.20.0/24 | Infrastructure (K8s, Ansible) |
| VLAN 40 | 192.168.40.0/24 | Services (Docker, Apps) |

### Deployed Infrastructure

**17 VMs Total**: 1 Ansible + 9 Kubernetes + 7 Services

| Category | Hosts | Details |
|----------|-------|---------|
| Kubernetes | 9 VMs | 3 controllers + 6 workers (v1.28.15) |
| Services | 7 VMs | Traefik, Authentik, Immich, GitLab, Arr Stack, n8n |
| Ansible | 1 VM | Configuration management controller |

See [docs/INVENTORY.md](./docs/INVENTORY.md) for full details.

## Quick Start

### Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### Access Ansible Controller

```bash
ssh hermes-admin@192.168.20.30
cd ~/ansible
```

### Common Operations

```bash
# Deploy VMs only
terraform apply -target=module.vms

# Check Ansible connectivity
ansible all -m ping

# Deploy Kubernetes
ansible-playbook k8s/k8s-deploy-all.yml
```

See [docs/TERRAFORM.md](./docs/TERRAFORM.md) for more operations.

## Authentication

| Access | Details |
|--------|---------|
| SSH User | hermes-admin |
| SSH Key | ed25519 (key-based auth only) |
| Proxmox API | terraform-deployment-user@pve!tf |

## Service URLs

| Service | URL |
|---------|-----|
| Proxmox | https://proxmox.hrmsmrflrii.xyz |
| Traefik | https://traefik.hrmsmrflrii.xyz |
| Authentik | https://auth.hrmsmrflrii.xyz |
| Immich | https://photos.hrmsmrflrii.xyz |
| GitLab | https://gitlab.hrmsmrflrii.xyz |
| Jellyfin | https://jellyfin.hrmsmrflrii.xyz |
| n8n | https://n8n.hrmsmrflrii.xyz |

See [docs/NETWORKING.md](./docs/NETWORKING.md) for complete URL list.

## Repository Structure

```
tf-proxmox/
├── main.tf                 # VM definitions
├── lxc.tf                  # LXC container definitions
├── variables.tf            # Global variables
├── outputs.tf              # Output definitions
├── modules/
│   ├── linux-vm/           # VM module
│   └── lxc/                # LXC module
├── ansible-playbooks/      # Ansible playbooks
├── docs/                   # Modular documentation
│   ├── NETWORKING.md       # Network configuration
│   ├── PROXMOX.md          # Cluster & VM standards
│   ├── STORAGE.md          # Storage configuration
│   ├── TERRAFORM.md        # IaC deployment
│   ├── SERVICES.md         # Docker services
│   ├── ANSIBLE.md          # Automation
│   ├── INVENTORY.md        # Deployed resources
│   ├── TROUBLESHOOTING.md  # Issue resolution
│   └── legacy/             # Extended documentation
└── CLAUDE.md               # This file
```

## Key Configuration

### Adding New VMs

Edit `main.tf`, add to `vm_groups`:

```hcl
new-service = {
  count       = 1
  starting_ip = "192.168.40.50"
  template    = "tpl-ubuntu-shared-v1"
  cores       = 4
  memory      = 8192
  disk_size   = "20G"
  storage     = "VMDisks"
  vlan_tag    = 40              # null for VLAN 20
  gateway     = "192.168.40.1"
  nameserver  = "192.168.91.30"
}
```

See [docs/TERRAFORM.md](./docs/TERRAFORM.md) for complete guide.

### Adding New Services

1. Deploy VM via Terraform
2. Create Ansible playbook in `ansible-playbooks/`
3. Add to Traefik dynamic config
4. Update DNS in OPNsense

See [docs/SERVICES.md](./docs/SERVICES.md) and [docs/ANSIBLE.md](./docs/ANSIBLE.md).

## Security

- **API Tokens**: Stored in `terraform.tfvars` (gitignored)
- **SSH**: Public key only, password auth disabled
- **LXC**: Unprivileged by default
- **Network**: VLAN segmentation

## Notes

- All VMs use Ubuntu 24.04 LTS cloud-init template
- VMs use UEFI boot mode (ovmf)
- LXC containers use Ubuntu 22.04 or Debian 12
- Auto-start enabled on production infrastructure
- Proxmox node02 dedicated to service VMs
