# Azure Environment Technical Manual

This document provides comprehensive technical documentation for the Azure environment integrated with the homelab infrastructure.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Network Connectivity](#network-connectivity)
4. [Virtual Machines](#virtual-machines)
5. [Identity & Access Management](#identity--access-management)
6. [Azure Sentinel (SIEM)](#azure-sentinel-siem)
7. [Deployment Procedures](#deployment-procedures)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The Azure environment extends the on-premises homelab to the cloud, providing:

- **Centralized SIEM**: Azure Sentinel for log aggregation and security analytics
- **Infrastructure as Code**: Terraform deployments via dedicated Ubuntu VM
- **Hybrid Connectivity**: Site-to-site VPN between homelab and Azure

### Key Resources

| Resource | Purpose | Resource Group |
|----------|---------|----------------|
| ubuntu-deploy-vm | Terraform/Ansible deployment VM | deployment-rg |
| ans-tf-vm01 | Windows management VM (legacy) | deployment-rg |
| law-homelab-sentinel | Log Analytics Workspace | rg-homelab-sentinel |
| Microsoft Sentinel | SIEM platform | rg-homelab-sentinel |
| linux-syslog-server01 | Arc-connected syslog server | rg-homelab-sentinel |

### Subscription Details

| Property | Value |
|----------|-------|
| Subscription Name | FireGiants-Prod |
| Subscription ID | `2212d587-1bad-4013-b605-b421b1f83c30` |
| Tenant ID | `b6458a9a-9661-468c-bda3-5f496727d0b0` |
| Primary Region | Southeast Asia |

---

## Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AZURE CLOUD                                         │
│                         Subscription: FireGiants-Prod                            │
│                         Region: Southeast Asia                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                        deployment-rg                                     │    │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │    │
│  │  │              ans-tf-vm01-vnet (10.90.10.0/29)                    │    │    │
│  │  │                                                                  │    │    │
│  │  │    ┌─────────────────┐      ┌─────────────────────────────┐     │    │    │
│  │  │    │ ans-tf-vm01     │      │ ubuntu-deploy-vm            │     │    │    │
│  │  │    │ Windows 11      │      │ Ubuntu 22.04 LTS            │     │    │    │
│  │  │    │ 10.90.10.4      │      │ 10.90.10.5                  │     │    │    │
│  │  │    │                 │      │ Standard_D2s_v3             │     │    │    │
│  │  │    │ - WinRM enabled │      │ - Terraform                 │     │    │    │
│  │  │    │ - Terraform     │      │ - Ansible                   │     │    │    │
│  │  │    │ - Azure CLI     │      │ - Azure CLI                 │     │    │    │
│  │  │    │ - Managed ID    │      │ - Managed ID (Contributor)  │     │    │    │
│  │  │    └─────────────────┘      └─────────────────────────────┘     │    │    │
│  │  │              │                          │                        │    │    │
│  │  │              └──────────┬───────────────┘                        │    │    │
│  │  │                         │                                        │    │    │
│  │  │              ┌──────────▼──────────┐                             │    │    │
│  │  │              │    NAT Gateway      │                             │    │    │
│  │  │              │ (Outbound Internet) │                             │    │    │
│  │  │              └──────────┬──────────┘                             │    │    │
│  │  └─────────────────────────┼────────────────────────────────────────┘    │    │
│  └────────────────────────────┼─────────────────────────────────────────────┘    │
│                               │                                                   │
│  ┌────────────────────────────┼─────────────────────────────────────────────┐    │
│  │                    rg-homelab-sentinel                                    │    │
│  │                            │                                              │    │
│  │    ┌───────────────────────┴───────────────────────────────────────┐     │    │
│  │    │                                                                │     │    │
│  │    │  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐  │     │    │
│  │    │  │ Log Analytics   │  │ Microsoft       │  │ Data          │  │     │    │
│  │    │  │ Workspace       │◄─┤ Sentinel        │  │ Collection    │  │     │    │
│  │    │  │ law-homelab-    │  │ (SIEM)          │  │ Endpoint      │  │     │    │
│  │    │  │ sentinel        │  │                 │  │ dce-homelab-  │  │     │    │
│  │    │  │                 │  │ - Analytics     │  │ syslog        │  │     │    │
│  │    │  │ Retention: 90d  │  │ - Workbooks     │  │               │  │     │    │
│  │    │  │ SKU: PerGB2018  │  │ - Incidents     │  │               │  │     │    │
│  │    │  └─────────────────┘  └─────────────────┘  └───────┬───────┘  │     │    │
│  │    │                                                     │          │     │    │
│  │    │                           ┌─────────────────────────┘          │     │    │
│  │    │                           │                                    │     │    │
│  │    │                  ┌────────▼────────┐                           │     │    │
│  │    │                  │ Data Collection │                           │     │    │
│  │    │                  │ Rule            │                           │     │    │
│  │    │                  │ dcr-homelab-    │                           │     │    │
│  │    │                  │ syslog          │                           │     │    │
│  │    │                  │                 │                           │     │    │
│  │    │                  │ Facilities:     │                           │     │    │
│  │    │                  │ auth, authpriv  │                           │     │    │
│  │    │                  │ local0-7, etc.  │                           │     │    │
│  │    │                  └────────┬────────┘                           │     │    │
│  │    │                           │                                    │     │    │
│  │    └───────────────────────────┼────────────────────────────────────┘     │    │
│  │                                │                                          │    │
│  └────────────────────────────────┼──────────────────────────────────────────┘    │
│                                   │                                               │
└───────────────────────────────────┼───────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │     Site-to-Site VPN          │
                    │   Azure <-> OPNsense          │
                    └───────────────┬───────────────┘
                                    │
┌───────────────────────────────────┼───────────────────────────────────────────────┐
│                           HOMELAB (On-Premises)                                    │
│                                   │                                                │
│  ┌────────────────────────────────┼────────────────────────────────────────────┐  │
│  │                    VLAN 40 - Services (192.168.40.0/24)                      │  │
│  │                                │                                             │  │
│  │    ┌───────────────────────────┴───────────────────────────────────────┐    │  │
│  │    │                                                                    │    │  │
│  │    │  ┌─────────────────────┐                                          │    │  │
│  │    │  │ linux-syslog-       │                                          │    │  │
│  │    │  │ server01            │◄────── Omada Controller (192.168.0.103)  │    │  │
│  │    │  │ 192.168.40.5        │◄────── Other Syslog Sources              │    │  │
│  │    │  │                     │                                          │    │  │
│  │    │  │ - Azure Arc Agent   │        ┌─────────────────────────────┐   │    │  │
│  │    │  │ - Azure Monitor     │───────►│ Azure Sentinel              │   │    │  │
│  │    │  │   Agent (AMA)       │        │ (via DCR/DCE)               │   │    │  │
│  │    │  │ - rsyslog           │        └─────────────────────────────┘   │    │  │
│  │    │  └─────────────────────┘                                          │    │  │
│  │    │                                                                    │    │  │
│  │    └────────────────────────────────────────────────────────────────────┘    │  │
│  │                                                                              │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
```

### Resource Hierarchy

```
Tenant: b6458a9a-9661-468c-bda3-5f496727d0b0
└── Subscription: FireGiants-Prod (2212d587-1bad-4013-b605-b421b1f83c30)
    ├── deployment-rg
    │   ├── ans-tf-vm01-vnet (10.90.10.0/29)
    │   │   └── vmsubnet (10.90.10.0/29)
    │   ├── NAT Gateway (nat-gateway-homelab)
    │   │   └── Public IP (pip-nat-gateway)
    │   ├── ans-tf-vm01 (Windows 11)
    │   │   ├── NIC + NSG
    │   │   └── Managed Identity
    │   └── ubuntu-deploy-vm (Ubuntu 22.04)
    │       ├── NIC + NSG
    │       └── Managed Identity (Contributor)
    │
    └── rg-homelab-sentinel
        ├── law-homelab-sentinel (Log Analytics Workspace)
        ├── Microsoft Sentinel
        ├── dce-homelab-syslog (Data Collection Endpoint)
        ├── dcr-homelab-syslog (Data Collection Rule)
        └── linux-syslog-server01 (Arc Machine)
            └── AzureMonitorLinuxAgent (Extension)
```

---

## Network Connectivity

### VPN Configuration

The homelab connects to Azure via a site-to-site VPN:

| Property | Value |
|----------|-------|
| VPN Type | Site-to-Site (IPsec) |
| Local Gateway | OPNsense Firewall |
| Azure VNet | ans-tf-vm01-vnet |
| Azure Address Space | 10.90.10.0/29 |
| Homelab Networks | 192.168.20.0/24, 192.168.40.0/24 |

### Network Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           NETWORK FLOW DIAGRAM                                   │
└─────────────────────────────────────────────────────────────────────────────────┘

                           OUTBOUND INTERNET (Azure VMs)
                           ════════════════════════════

     ┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────┐
     │ Azure VM    │─────►│ NAT Gateway │─────►│ Public IP   │─────►│ Internet│
     │ 10.90.10.x  │      │             │      │             │      │         │
     └─────────────┘      └─────────────┘      └─────────────┘      └─────────┘


                           HOMELAB TO AZURE (VPN)
                           ══════════════════════

     ┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
     │ Homelab VM  │─────►│ OPNsense    │═════►│ Azure VPN   │─────►│ Azure VM    │
     │ 192.168.x.x │      │ Firewall    │ VPN  │ Gateway     │      │ 10.90.10.x  │
     └─────────────┘      └─────────────┘      └─────────────┘      └─────────────┘


                           SYSLOG TO SENTINEL
                           ══════════════════

     ┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
     │ Omada       │─────►│ Syslog      │─────►│ Azure       │─────►│ Sentinel    │
     │ Controller  │ UDP  │ Server      │ AMA  │ Monitor     │      │ Workspace   │
     │ 192.168.0.  │ 514  │ 192.168.    │      │ DCE/DCR     │      │             │
     │ 103         │      │ 40.5        │      │             │      │             │
     └─────────────┘      └─────────────┘      └─────────────┘      └─────────────┘


                           SSH ACCESS (Local to Azure)
                           ══════════════════════════

     ┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
     │ Local PC    │─────►│ VPN         │─────►│ Azure VNet  │─────►│ Ubuntu VM   │
     │ (Windows)   │      │ Tunnel      │      │ 10.90.10.0  │ SSH  │ 10.90.10.5  │
     │             │      │             │      │ /29         │      │             │
     └─────────────┘      └─────────────┘      └─────────────┘      └─────────────┘
```

### IP Address Allocation

#### Azure Network (10.90.10.0/29)

| IP Address | Resource | Purpose |
|------------|----------|---------|
| 10.90.10.0 | Network | Network address |
| 10.90.10.1 | Azure | Gateway (reserved) |
| 10.90.10.2 | Azure | DNS (reserved) |
| 10.90.10.3 | Azure | Reserved |
| 10.90.10.4 | ans-tf-vm01 | Windows management VM |
| 10.90.10.5 | ubuntu-deploy-vm | **Primary deployment VM** |
| 10.90.10.6 | Available | Future use |
| 10.90.10.7 | Broadcast | Broadcast address |

### NSG Rules

#### Subnet-Level NSG (Outbound)

| Priority | Name | Port | Protocol | Destination | Action |
|----------|------|------|----------|-------------|--------|
| 100 | Allow-Outbound-HTTPS | 443 | TCP | Internet | Allow |
| 65000 | AllowVnetOutBound | Any | Any | VirtualNetwork | Allow |
| 65001 | AllowInternetOutBound | Any | Any | Internet | Allow |
| 65500 | DenyAllOutBound | Any | Any | Any | Deny |

#### NIC-Level NSG (Outbound)

| Priority | Name | Port | Protocol | Destination | Action |
|----------|------|------|----------|-------------|--------|
| 110 | Allow-Outbound-Internet | 443 | TCP | Internet | Allow |
| 65000 | AllowVnetOutBound | Any | Any | VirtualNetwork | Allow |
| 65001 | AllowInternetOutBound | Any | Any | Internet | Allow |
| 65500 | DenyAllOutBound | Any | Any | Any | Deny |

---

## Virtual Machines

### ubuntu-deploy-vm (Primary Deployment VM)

This is the **primary VM for all Azure deployments** going forward.

| Property | Value |
|----------|-------|
| **Name** | ubuntu-deploy-vm |
| **OS** | Ubuntu 22.04 LTS (Jammy) |
| **Size** | Standard_D2s_v3 (2 vCPU, 8 GB RAM) |
| **Private IP** | 10.90.10.5 |
| **Public IP** | None (NAT Gateway for outbound) |
| **Disk** | 64 GB Standard SSD |
| **Resource Group** | deployment-rg |
| **Managed Identity** | System-assigned (Contributor role) |

#### Installed Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | Latest | Infrastructure as Code |
| Ansible | Latest | Configuration management |
| Azure CLI | Latest | Azure management |
| Git | Latest | Version control |
| jq | Latest | JSON processing |

#### SSH Access

```bash
# From local machine (via VPN)
ssh ubuntu-deploy

# Or explicitly
ssh -i ~/.ssh/ubuntu-deploy-vm.pem hermes-admin@10.90.10.5
```

#### SSH Key Location

| Location | Path |
|----------|------|
| Local PC | `C:\Users\herms\.ssh\ubuntu-deploy-vm.pem` |
| Windows VM | `C:\terraform\ubuntu-deploy-vm\ubuntu-deploy-vm.pem` |

### ans-tf-vm01 (Windows Management VM)

| Property | Value |
|----------|-------|
| **Name** | ans-tf-vm01 |
| **OS** | Windows 11 |
| **Private IP** | 10.90.10.4 |
| **Purpose** | Legacy management, WinRM access |
| **Managed Identity** | System-assigned |

> **Note**: Use `ubuntu-deploy-vm` for all new deployments. The Windows VM is retained for compatibility.

---

## Identity & Access Management

### Managed Identities

| VM | Principal ID | Roles |
|----|--------------|-------|
| ubuntu-deploy-vm | `6a7ce275-212d-4559-93ff-383e39471e06` | Contributor (Subscription) |
| ans-tf-vm01 | `6e50faab-2626-49a6-a093-823fa7ed32a6` | Contributor (Limited) |

### Using Managed Identity

```bash
# On ubuntu-deploy-vm
az login --identity

# Verify access
az account show
az group list -o table
```

### Role Assignments

To add additional roles:

```bash
# Assign role via Azure CLI
az role assignment create \
  --assignee <principal-id> \
  --role "Contributor" \
  --scope /subscriptions/2212d587-1bad-4013-b605-b421b1f83c30
```

---

## Azure Sentinel (SIEM)

> **Comprehensive Tutorial**: For detailed learning scenarios, KQL queries, and hands-on exercises, see [Azure Sentinel Learning Lab](./AZURE_SENTINEL_LEARNING_LAB.md).

### Components

| Resource | Name | Purpose |
|----------|------|---------|
| Log Analytics Workspace | law-homelab-sentinel | Log storage and querying |
| Sentinel | (attached to LAW) | SIEM analytics and detection |
| Data Collection Endpoint | dce-homelab-syslog | Ingestion endpoint for AMA |
| Data Collection Rule | dcr-homelab-syslog | Defines what logs to collect |

### Data Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Omada           │     │ linux-syslog-   │     │ Azure Monitor   │
│ Controller      │────►│ server01        │────►│ Agent           │
│ 192.168.0.103   │UDP  │ 192.168.40.5    │     │ (AMA)           │
│                 │514  │                 │     │                 │
└─────────────────┘     └────────┬────────┘     └────────┬────────┘
                                 │                       │
                                 │ rsyslog               │ HTTPS
                                 ▼                       ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │ /var/log/       │     │ Data Collection │
                        │ remote/omada/   │     │ Endpoint        │
                        │ omada.log       │     │ dce-homelab-    │
                        └─────────────────┘     │ syslog          │
                                                └────────┬────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │ Data Collection │
                                                │ Rule            │
                                                │ dcr-homelab-    │
                                                │ syslog          │
                                                └────────┬────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │ Log Analytics   │
                                                │ Workspace       │
                                                │ law-homelab-    │
                                                │ sentinel        │
                                                └────────┬────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │ Microsoft       │
                                                │ Sentinel        │
                                                │ (SIEM)          │
                                                └─────────────────┘
```

### Querying Logs (KQL)

```kusto
// View recent syslog entries
Syslog
| take 10

// Filter by facility
Syslog
| where Facility == "auth"
| take 100

// Omada-specific logs
Syslog
| where Computer == "linux-syslog-server01"
| where SyslogMessage contains "omada"
| take 50

// Error-level logs
Syslog
| where SeverityLevel in ("err", "crit", "alert", "emerg")
| order by TimeGenerated desc
| take 100
```

### Syslog Facilities Collected

| Facility | Description |
|----------|-------------|
| auth | Authentication messages |
| authpriv | Private authentication |
| local0-7 | Custom application logs |
| syslog | System messages |
| user | User-level messages |
| daemon | System daemons |

---

## Deployment Procedures

### Standard Deployment Workflow

All Azure deployments should follow this workflow:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ 1. SSH to       │     │ 2. Write        │     │ 3. Deploy       │
│ ubuntu-deploy   │────►│ Terraform       │────►│ Resources       │
│                 │     │ Configuration   │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
   ssh ubuntu-deploy    Create .tf files       terraform apply
```

### Step-by-Step Deployment

1. **Connect to Deployment VM**
   ```bash
   ssh ubuntu-deploy
   ```

2. **Login with Managed Identity**
   ```bash
   az login --identity
   az account show
   ```

3. **Create Terraform Configuration**
   ```bash
   mkdir -p /opt/terraform/my-project
   cd /opt/terraform/my-project

   # Create providers.tf, main.tf, variables.tf, outputs.tf
   ```

4. **Deploy**
   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

### Example: providers.tf Template

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }
}

provider "azurerm" {
  features {}
  use_msi         = true
  subscription_id = "2212d587-1bad-4013-b605-b421b1f83c30"
}
```

---

## Troubleshooting

### Common Issues

#### 1. Cannot Connect to Azure VM via SSH

**Symptoms**: SSH connection times out or refused

**Solutions**:
- Verify VPN connection is active
- Check NSG rules allow SSH (port 22)
- Verify VM is running in Azure Portal

```bash
# Test connectivity
ping 10.90.10.5
nc -zv 10.90.10.5 22
```

#### 2. Terraform Cannot Authenticate

**Symptoms**: Authentication errors when running Terraform

**Solutions**:
- Ensure managed identity is enabled
- Verify role assignments
- Re-login with identity

```bash
az login --identity
az account show
```

#### 3. No Outbound Internet

**Symptoms**: Cannot download packages or reach external URLs

**Solutions**:
- Verify NAT Gateway is associated with subnet
- Check NSG outbound rules allow HTTPS (443)
- Test connectivity

```bash
curl -I https://www.microsoft.com
nc -zv management.azure.com 443
```

#### 4. Syslog Not Appearing in Sentinel

**Symptoms**: No data in Log Analytics Syslog table

**Solutions**:
- Verify AMA is installed and running on Arc server
- Check DCR association
- Verify rsyslog is receiving logs

```bash
# On linux-syslog-server01
sudo systemctl status azuremonitoragent
tail -f /var/log/remote/omada/omada.log
```

### Useful Commands

```bash
# Check Azure CLI login status
az account show

# List all resources in subscription
az resource list -o table

# Check VM status
az vm list -d -o table

# View Arc server status
az connectedmachine show -g rg-homelab-sentinel -n linux-syslog-server01

# Check AMA extension
az connectedmachine extension list -g rg-homelab-sentinel --machine-name linux-syslog-server01
```

---

## Terraform State Files

| Project | State Location | Purpose |
|---------|----------------|---------|
| Sentinel | `C:\terraform\sentinel\terraform.tfstate` (on Windows VM) | Sentinel infrastructure |
| Ubuntu VM | `C:\terraform\ubuntu-deploy-vm\terraform.tfstate` (on Windows VM) | Deployment VM |

> **Note**: Consider migrating state to Azure Storage Account for better collaboration.

---

## Cost Considerations

| Resource | Estimated Monthly Cost |
|----------|------------------------|
| ubuntu-deploy-vm (D2s_v3) | ~$70 USD |
| ans-tf-vm01 (stopped when not in use) | ~$0 (stopped) |
| Log Analytics (90-day retention) | ~$2.30/GB ingested |
| NAT Gateway | ~$32 USD + data processing |
| Sentinel | Free tier (first 10GB/day) |

**Cost Optimization Tips**:
- Stop Windows VM when not in use
- Use Reserved Instances for long-running VMs
- Monitor Log Analytics ingestion volume

---

## References

- [Azure Sentinel Documentation](https://docs.microsoft.com/en-us/azure/sentinel/)
- [Azure Arc Documentation](https://docs.microsoft.com/en-us/azure/azure-arc/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Monitor Agent](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/agents-overview)

---

## Appendix

### A. File Locations

| File | Location | Purpose |
|------|----------|---------|
| Terraform configs | `/opt/terraform/` (on ubuntu-deploy-vm) | IaC definitions |
| SSH key (local) | `~/.ssh/ubuntu-deploy-vm.pem` | VM access |
| rsyslog config | `/etc/rsyslog.d/10-remote.conf` (on syslog server) | Remote log collection |

### B. Related Documentation

| Document | Path |
|----------|------|
| Network Setup | [docs/NETWORKING.md](./NETWORKING.md) |
| Observability | [docs/OBSERVABILITY.md](./OBSERVABILITY.md) |
| Inventory | [docs/INVENTORY.md](./INVENTORY.md) |
| Troubleshooting | [docs/TROUBLESHOOTING.md](./TROUBLESHOOTING.md) |
