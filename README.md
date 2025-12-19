# Proxmox Homelab Infrastructure

[![Proxmox](https://img.shields.io/badge/Proxmox-VE%209.1.2-orange)](https://www.proxmox.com/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-2.15+-red)](https://www.ansible.com/)

Production-grade homelab infrastructure managed with Terraform and Ansible on a 3-node Proxmox VE cluster.

## 📖 Documentation

**Full documentation available in the [Wiki](../../wiki)**

The Wiki contains comprehensive, beginner-friendly guides for every aspect of this infrastructure.

## 🏗️ Infrastructure at a Glance

| Component | Details |
|-----------|---------|
| **Proxmox Cluster** | 3 nodes (node01, node02, node03) |
| **Virtual Machines** | 17 VMs across 2 VLANs |
| **Services** | 22 containerized applications |
| **Kubernetes** | 9-node HA cluster (3 control + 6 workers) |
| **SSL/HTTPS** | Let's Encrypt wildcard via Cloudflare |
| **Domain** | *.hrmsmrflrii.xyz |

### Services Running

| Category | Services |
|----------|----------|
| **Reverse Proxy** | Traefik v3.2 with automatic SSL |
| **Identity** | Authentik (SSO/OAuth/SAML) |
| **Media** | Jellyfin, Radarr, Sonarr, Lidarr, Prowlarr, Bazarr, Overseerr, Jellyseerr, Tdarr, Autobrr |
| **Photos** | Immich (self-hosted Google Photos alternative) |
| **Documents** | Paperless-ngx (document management) |
| **DevOps** | GitLab CE |
| **Automation** | n8n (workflow automation) |
| **Dashboard** | Glance |

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/herms14/Proxmox-TerraformDeployments.git
cd Proxmox-TerraformDeployments

# Configure your variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox API credentials

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

**See the [Wiki](../../wiki) for detailed setup instructions.**

## 📁 Repository Structure

```
├── main.tf                 # VM definitions
├── lxc.tf                  # LXC container definitions
├── variables.tf            # Terraform variables
├── modules/                # Terraform modules
│   ├── linux-vm/          # Linux VM module (cloud-init)
│   ├── lxc/               # LXC container module
│   └── windows-vm/        # Windows VM module
├── ansible/               # Ansible playbooks
│   ├── docker/           # Docker & Arr stack
│   ├── k8s/              # Kubernetes deployment
│   ├── traefik/          # Reverse proxy
│   ├── authentik/        # Identity provider
│   ├── immich/           # Photo management
│   ├── gitlab/           # DevOps platform
│   ├── paperless/        # Document management
│   ├── n8n/              # Workflow automation
│   ├── glance/           # Dashboard
│   ├── opnsense/         # DNS automation
│   └── synology/         # NAS automation
├── docs/                  # Legacy documentation
└── wiki/                  # Wiki source files
```

## 🔧 Key Technologies

- **Proxmox VE 9.1.2** - Virtualization platform
- **Terraform** - Infrastructure as Code
- **Ansible** - Configuration management
- **Docker** - Containerization
- **Kubernetes** - Container orchestration
- **Traefik** - Reverse proxy & SSL
- **Cloudflare** - DNS & SSL certificates
- **Synology NAS** - NFS storage backend

## 📚 Learn More

| Topic | Link |
|-------|------|
| Getting Started | [Wiki: Introduction](../../wiki/Introduction) |
| Architecture Overview | [Wiki: Architecture](../../wiki/Architecture-Overview) |
| Network Setup | [Wiki: Network Architecture](../../wiki/Network-Architecture) |
| Adding Services | [Wiki: Services Overview](../../wiki/Services-Overview) |
| Troubleshooting | [Wiki: Troubleshooting](../../wiki/Troubleshooting-Guide) |

## 📄 Files Reference

| File | Purpose |
|------|---------|
| `CLAUDE.md` | AI assistant context & infrastructure details |
| `CHANGELOG.md` | Version history and changes |
| `CREDENTIALS.md` | Sensitive data reference (gitignored) |
| `docs/legacy/` | Archived documentation |

## 🤝 Contributing

This is a personal homelab project, but feel free to:
- Open issues for questions
- Submit PRs for improvements
- Fork and adapt for your own homelab

## 📝 License

This project is open source. Use it as a reference for your own homelab!

---

*Last updated: December 2025*
