---
banner: "[[999 Attachments/pixel-banner-images/cybersecurity.jpg]]"
---
# Azure Environment Technical Manual

> **Internal Documentation** - Contains Azure subscription details and architecture information.

## Overview

The Azure environment extends the on-premises homelab to the cloud, providing:

- **Centralized SIEM**: Azure Sentinel for log aggregation and security analytics
- **Infrastructure as Code**: Terraform deployments via dedicated Ubuntu VM
- **Hybrid Connectivity**: Site-to-site VPN between homelab and Azure

## Quick Reference

| Property | Value |
|----------|-------|
| **Subscription** | FireGiants-Prod |
| **Subscription ID** | `2212d587-1bad-4013-b605-b421b1f83c30` |
| **Tenant ID** | `b6458a9a-9661-468c-bda3-5f496727d0b0` |
| **Region** | Southeast Asia |
| **VNet CIDR** | 10.90.10.0/29 |

---

## Architecture Diagram

```
                              AZURE CLOUD
                         Subscription: FireGiants-Prod
                         Region: Southeast Asia

  +---------------------------------------------------------------------+
  |                        deployment-rg                                 |
  |  +---------------------------------------------------------------+  |
  |  |              ans-tf-vm01-vnet (10.90.10.0/29)                  |  |
  |  |                                                               |  |
  |  |    +-------------------+      +---------------------------+   |  |
  |  |    | ans-tf-vm01       |      | ubuntu-deploy-vm          |   |  |
  |  |    | Windows 11        |      | Ubuntu 22.04 LTS          |   |  |
  |  |    | 10.90.10.4        |      | 10.90.10.5                |   |  |
  |  |    |                   |      | Standard_D2s_v3           |   |  |
  |  |    | - WinRM enabled   |      | - Terraform               |   |  |
  |  |    | - Terraform       |      | - Ansible                 |   |  |
  |  |    | - Azure CLI       |      | - Azure CLI               |   |  |
  |  |    | - Managed ID      |      | - Managed ID (Contributor)|   |  |
  |  |    +-------------------+      +---------------------------+   |  |
  |  |              |                          |                      |  |
  |  |              +------------+-------------+                      |  |
  |  |                           |                                    |  |
  |  |              +------------v------------+                       |  |
  |  |              |    NAT Gateway          |                       |  |
  |  |              | (Outbound Internet)     |                       |  |
  |  |              +------------+------------+                       |  |
  |  +---------------------------|---------------------------------+  |
  +------------------------------|------------------------------------+

  +------------------------------|------------------------------------+
  |                    rg-homelab-sentinel                            |
  |                              |                                    |
  |    +-------------------------+--------------------------------+   |
  |    |                                                          |   |
  |    |  +-----------------+  +-----------------+  +------------+|   |
  |    |  | Log Analytics   |  | Microsoft       |  | Data       ||   |
  |    |  | Workspace       |<-| Sentinel        |  | Collection ||   |
  |    |  | law-homelab-    |  | (SIEM)          |  | Endpoint   ||   |
  |    |  | sentinel        |  |                 |  | dce-homelab||   |
  |    |  |                 |  | - Analytics     |  | -syslog    ||   |
  |    |  | Retention: 90d  |  | - Workbooks     |  |            ||   |
  |    |  | SKU: PerGB2018  |  | - Incidents     |  |            ||   |
  |    |  +-----------------+  +-----------------+  +------+-----+|   |
  |    |                                                   |      |   |
  |    |                           +-----------------------+      |   |
  |    |                           |                              |   |
  |    |                  +--------v--------+                     |   |
  |    |                  | Data Collection |                     |   |
  |    |                  | Rule            |                     |   |
  |    |                  | dcr-homelab-    |                     |   |
  |    |                  | syslog          |                     |   |
  |    |                  +-----------------+                     |   |
  |    +----------------------------------------------------------+   |
  +-------------------------------------------------------------------+
                                   |
                    +--------------+--------------+
                    |     Site-to-Site VPN        |
                    |   Azure <-> OPNsense        |
                    +--------------+--------------+
                                   |
                           HOMELAB (On-Premises)
                                   |
  +--------------------------------|----------------------------------+
  |                    VLAN 40 - Services (192.168.40.0/24)           |
  |                                |                                  |
  |    +---------------------------+------------------------------+   |
  |    |                                                          |   |
  |    |  +---------------------+                                 |   |
  |    |  | linux-syslog-       |                                 |   |
  |    |  | server01            |<------ Omada Controller         |   |
  |    |  | 192.168.40.5        |<------ Other Syslog Sources     |   |
  |    |  |                     |                                 |   |
  |    |  | - Azure Arc Agent   |        +--------------------+   |   |
  |    |  | - Azure Monitor     |------->| Azure Sentinel     |   |   |
  |    |  |   Agent (AMA)       |        | (via DCR/DCE)      |   |   |
  |    |  | - rsyslog           |        +--------------------+   |   |
  |    |  +---------------------+                                 |   |
  |    |                                                          |   |
  |    +----------------------------------------------------------+   |
  +-------------------------------------------------------------------+
```

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

### ans-tf-vm01 (Windows Management VM)

| Property | Value |
|----------|-------|
| **Name** | ans-tf-vm01 |
| **OS** | Windows 11 |
| **Private IP** | 10.90.10.4 |
| **Purpose** | Legacy management, WinRM access |
| **Managed Identity** | System-assigned |

> **Note**: Use `ubuntu-deploy-vm` for all new deployments.

---

## Network Configuration

### IP Address Allocation (10.90.10.0/29)

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

### VPN Configuration

| Property | Value |
|----------|-------|
| VPN Type | Site-to-Site (IPsec) |
| Local Gateway | OPNsense Firewall |
| Azure VNet | ans-tf-vm01-vnet |
| Azure Address Space | 10.90.10.0/29 |
| Homelab Networks | 192.168.20.0/24, 192.168.40.0/24 |

---

## Azure Sentinel (SIEM)

### Components

| Resource | Name | Purpose |
|----------|------|---------|
| Log Analytics Workspace | law-homelab-sentinel | Log storage and querying |
| Sentinel | (attached to LAW) | SIEM analytics and detection |
| Data Collection Endpoint | dce-homelab-syslog | Ingestion endpoint for AMA |
| Data Collection Rule | dcr-homelab-syslog | Defines what logs to collect |

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

---

## Managed Identities

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

---

## Deployment Workflow

All Azure deployments should follow this workflow:

```
+-------------------+     +-------------------+     +-------------------+
| 1. SSH to         |     | 2. Write          |     | 3. Deploy         |
| ubuntu-deploy     |---->| Terraform         |---->| Resources         |
|                   |     | Configuration     |     |                   |
+-------------------+     +-------------------+     +-------------------+
        |                         |                         |
        v                         v                         v
   ssh ubuntu-deploy      Create .tf files         terraform apply
```

### Step-by-Step

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

### Terraform Provider Template

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

## SSH Key Locations

| Location | Path |
|----------|------|
| Local PC (Windows) | `C:\Users\herms\.ssh\ubuntu-deploy-vm.pem` |
| Windows VM | `C:\terraform\ubuntu-deploy-vm\ubuntu-deploy-vm.pem` |

---

## Cost Considerations

| Resource | Estimated Monthly Cost |
|----------|------------------------|
| ubuntu-deploy-vm (D2s_v3) | ~$70 USD |
| ans-tf-vm01 (stopped when not in use) | ~$0 (stopped) |
| Log Analytics (90-day retention) | ~$2.30/GB ingested |
| NAT Gateway | ~$32 USD + data processing |
| Sentinel | Free tier (first 10GB/day) |

---

## Troubleshooting

### Cannot Connect to Azure VM via SSH

```bash
# Test connectivity
ping 10.90.10.5
nc -zv 10.90.10.5 22
```
- Verify VPN connection is active
- Check NSG rules allow SSH (port 22)
- Verify VM is running in Azure Portal

### Terraform Cannot Authenticate

```bash
az login --identity
az account show
```
- Ensure managed identity is enabled
- Verify role assignments

### No Outbound Internet

```bash
curl -I https://www.microsoft.com
nc -zv management.azure.com 443
```
- Verify NAT Gateway is associated with subnet
- Check NSG outbound rules allow HTTPS (443)

### Syslog Not Appearing in Sentinel

```bash
# On linux-syslog-server01
sudo systemctl status azuremonitoragent
tail -f /var/log/remote/omada/omada.log
```
- Verify AMA is installed and running on Arc server
- Check DCR association

---

## Related Documents

- [[01 - Network Architecture]] - On-premises network design
- [[18 - Observability Stack]] - Monitoring and tracing
- [[10 - IP Address Map]] - Complete IP allocation
- [[12 - Troubleshooting]] - Common issues and resolutions

---

*Last updated: January 7, 2026*
