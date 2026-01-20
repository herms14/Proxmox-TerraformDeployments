# Homelab Infrastructure

IaC for Proxmox VE 9.1.2 cluster with Azure cloud integration.

## Infrastructure Summary

```
PROXMOX CLUSTER (MorpheusCluster)
├─ node01: 192.168.20.20 (TS: 100.89.33.5)  - Primary
├─ node02: 192.168.20.21 (TS: 100.96.195.27) - Services
└─ node03: 192.168.20.22 (TS: 100.88.228.34) - Hybrid Lab

NETWORKS
├─ VLAN 20: 192.168.20.0/24 - Infrastructure
├─ VLAN 40: 192.168.40.0/24 - Services
├─ VLAN 80: 192.168.80.0/24 - Hybrid Lab (AD)
└─ VLAN 90: 192.168.90.0/24 - Management

KEY HOSTS
├─ ansible:       192.168.20.30 - Ansible/Packer
├─ docker-media:  192.168.40.11 - Jellyfin, *arr
├─ docker-glance: 192.168.40.12 - Glance Dashboard
├─ docker-utils:  192.168.40.13 - Grafana, Prometheus
├─ traefik:       192.168.40.20 - Reverse Proxy
├─ authentik:     192.168.40.21 - SSO
└─ pbs:           192.168.20.50 - Proxmox Backup Server

SYNOLOGY NAS: 192.168.20.31 (DSM:5001, Plex:32400)

AZURE SUBSCRIPTIONS
├─ FireGiants-Prod: 2212d587-1bad-4013-b605-b421b1f83c30 (Primary)
├─ FireGiants-Dev:  79e34814-e81a-465c-abf3-11103880db90
└─ Nokron-Prod:     9dde5c52-88be-4608-9bee-c52d1909693f

AZURE INFRASTRUCTURE
├─ ubuntu-deploy: 10.90.10.5 - Deployment VM (Terraform/Ansible)
├─ Terraform Dir: /opt/terraform/ on ubuntu-deploy-vm
├─ Sentinel SIEM: law-homelab-sentinel
└─ VPN: Site-to-Site (OPNsense <-> Azure VPN Gateway)

HYBRID LAB (hrmsmrflrii.xyz domain)
├─ DC01-DC02:     192.168.80.2-3  (VMIDs 300-301)
├─ FS01-FS02:     192.168.80.4-5  (VMIDs 302-303)
├─ SQL01:         192.168.80.6    (VMID 304)
├─ AADCON/PP:     192.168.80.7-9  (VMIDs 305-307)
├─ CLIENT01-02:   192.168.80.12-13 (VMIDs 308-309)
└─ IIS01-02:      192.168.80.10-11 (VMIDs 310-311)
```

## SSH Access

| Target | User | Key |
|--------|------|-----|
| Proxmox nodes | root | `~/.ssh/homelab_ed25519` |
| All VMs | hermes-admin | `~/.ssh/homelab_ed25519` |
| Azure | hermes-admin | `~/.ssh/ubuntu-deploy-vm.pem` |

```bash
ssh node01 / ssh ansible / ssh docker-vm-core-utilities01  # aliases
ssh ubuntu-deploy  # Azure
```

## Context Files

| File | Purpose | When |
|------|---------|------|
| `.claude/active-tasks.md` | In-progress work | **Read first** |
| `.claude/session-log.md` | Recent history | Before starting |
| `.claude/context.md` | Detailed infrastructure | As needed |
| `.claude/conventions.md` | Standards/patterns | Adding services |
| `.claude/protected-layouts.md` | Dashboard structures | Modifying dashboards |

## Multi-Session Protocol

**Before work**: Check `active-tasks.md` for conflicts
**During work**: Update `active-tasks.md` + `session-log.md`
**After work**: Move to "Recently Completed", commit

## Key URLs

| Service | URL |
|---------|-----|
| Proxmox | https://proxmox.hrmsmrflrii.xyz |
| Glance | https://glance.hrmsmrflrii.xyz |
| Grafana | https://grafana.hrmsmrflrii.xyz |
| PBS | https://pbs.hrmsmrflrii.xyz |

## Protected Configurations

**DO NOT modify without permission:**
- Glance tab layouts (Home, Compute, Storage, Network, Media)
- Grafana dashboards: `container-status`, `synology-nas-modern`, `omada-network`

See `.claude/protected-layouts.md` for structure details.

## Glance Dashboard Rules

**CRITICAL: NEVER overwrite the Glance config (`/opt/glance/config/glance.yml`)**

When modifying the Glance dashboard:
1. **Always fetch the current config first** from the host or GitHub backup: `https://github.com/herms14/glance-dashboard`
2. **Add/modify widgets incrementally** - never replace the entire file
3. **Preserve all existing pages**: Home, Compute, Storage, Backup, Network, Media, Web, Reddit, Sports
4. **Test changes** before deploying to ensure YAML validity
5. **Backup before changes** - the GitHub repo is the source of truth

If something breaks, restore from: `https://raw.githubusercontent.com/herms14/glance-dashboard/main/config/glance.yml`

## Azure Deployment Workflow

**All Azure resources are deployed via `ubuntu-deploy-vm` using Managed Identity.**

```bash
# 1. Create Terraform files locally in terraform/azure/[project]/
# 2. Copy to Azure VM
scp -r terraform/azure/[project]/ ubuntu-deploy:/opt/terraform/

# 3. SSH and deploy
ssh ubuntu-deploy
cd /opt/terraform/[project]
az login --identity
terraform init && terraform plan -out=tfplan && terraform apply tfplan
```

**Terraform Provider Template:**
```hcl
provider "azurerm" {
  features {}
  use_msi                    = true
  subscription_id            = "2212d587-1bad-4013-b605-b421b1f83c30"
  skip_provider_registration = true
}
```

See `AZURE-CLAUDE.md` in Obsidian for full Azure deployment context.

## Documentation Requirements (MANDATORY)

**All implementations MUST be documented in THREE locations:**

| Location | Style | Purpose |
|----------|-------|---------|
| **Obsidian Note** | Modular | `[XX] - Topic.md` - Technical details, diagrams, configs |
| **Technical Manual** | Tutorial | Step-by-step procedures, tables, code blocks |
| **Book** | Narrative | Full paragraphs, context, rationale, lessons learned |

### Obsidian Vault Path
```
C:\Users\herms14\OneDrive\Obsidian Vault\Hermes's Life Knowledge Base\07 HomeLab Things\Claude Managed Homelab\
```

### Key Documentation Files
| File | Style | Content |
|------|-------|---------|
| `Hermes Homelab Technical Manual.md` | Tutorial | How-to steps, reference tables, commands |
| `Book - The Complete Homelab Guide.md` | Narrative | Full explanations, architecture, lessons |
| `[XX] - Topic.md` files | Modular | Specific feature documentation |
| `AZURE-CLAUDE.md` | Reference | Azure deployment context for agents |

### Documentation Checklist (After Every Implementation)
- [ ] Create/update Obsidian note with technical details
- [ ] Add tutorial section to Technical Manual
- [ ] Add narrative chapter/section to Book
- [ ] Update `.claude/session-log.md`
- [ ] Commit changes to git

## Adding New Services

1. Terraform VM → 2. Ansible playbook → 3. Traefik route → 4. DNS → 5. Authentik (optional) → 6. Update docs

## SSH Public Key

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINVYlOowJQE4tC4GEo17MptDGdaQfWwMDMRxLdKd/yui hermes@homelab-nopass
```

Deploy this key to all new infrastructure.
