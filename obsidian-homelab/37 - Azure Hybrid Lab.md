---
banner: "[[999 Attachments/pixel-banner-images/cybersecurity.jpg]]"
---
# Azure Hybrid Lab - Active Directory Environment

> **Internal Documentation** - Contains credentials and sensitive configuration details.

## Overview

The Azure Hybrid Lab is a complete enterprise Active Directory simulation deployed in Azure, integrated with the on-premises homelab via site-to-site VPN.

## Quick Reference

| Property | Value |
|----------|-------|
| **Domain** | hrmsmrflrii.xyz |
| **NetBIOS** | HRMSMRFLRII |
| **Forest Level** | Windows Server 2016 |
| **Location** | Azure Southeast Asia |
| **VNet** | 10.10.4.0/24 (Identity Subnet) |

---

## Domain Controllers

| Server | IP Address | Role | Status |
|--------|------------|------|--------|
| **AZDC01** | 10.10.4.4 | Primary DC (Forest Root) | Running |
| **AZDC02** | 10.10.4.5 | Secondary DC | Running |
| **AZRODC01** | 10.10.4.6 | Read-Only DC | Running |
| **AZRODC02** | 10.10.4.7 | Read-Only DC | Running |

### VM Specifications

| Property | Value |
|----------|-------|
| **OS** | Windows Server 2022 Datacenter |
| **Size** | Standard_B2s (2 vCPU, 4 GB RAM) |
| **OS Disk** | 128 GB Standard SSD |
| **Data Disk** | 32 GB (AD Database) |

---

## Credentials

### Domain Administrator

| Property | Value |
|----------|-------|
| **Username** | HRMSMRFLRII\azureadmin |
| **Password** | Homelab@Azure2026! |
| **UPN** | azureadmin@hrmsmrflrii.xyz |

### DSRM (Directory Services Restore Mode)

| Property | Value |
|----------|-------|
| **Password** | Homelab@Azure2026! |

### Standard Users

| Username | Password | Notes |
|----------|----------|-------|
| All standard users | Welcome123! | Change at first logon |

### Tier 0 Admin Accounts

| Username | UPN | Role |
|----------|-----|------|
| t0.admin | t0.admin@hrmsmrflrii.xyz | Domain Admin |
| t0.entadmin | t0.entadmin@hrmsmrflrii.xyz | Enterprise Admin |
| t0.schema | t0.schema@hrmsmrflrii.xyz | Schema Admin |
| t0.pki | t0.pki@hrmsmrflrii.xyz | PKI Admin |

### Tier 1 Admin Accounts

| Username | UPN | Role |
|----------|-----|------|
| t1.srvadmin | t1.srvadmin@hrmsmrflrii.xyz | Server Admin |
| t1.sqladmin | t1.sqladmin@hrmsmrflrii.xyz | SQL Admin |
| t1.webadmin | t1.webadmin@hrmsmrflrii.xyz | Web Admin |
| t1.backup | t1.backup@hrmsmrflrii.xyz | Backup Operator |

### Tier 2 Admin Accounts

| Username | UPN | Role |
|----------|-----|------|
| t2.deskadmin | t2.deskadmin@hrmsmrflrii.xyz | Desktop Admin |
| t2.helpdesk1 | t2.helpdesk1@hrmsmrflrii.xyz | Helpdesk L1 |
| t2.helpdesk2 | t2.helpdesk2@hrmsmrflrii.xyz | Helpdesk L2 |

---

## Access Methods

### RDP Access

```bash
# From homelab (via VPN)
mstsc /v:10.10.4.4

# Credentials
Username: HRMSMRFLRII\azureadmin
Password: Homelab@Azure2026!
```

### PowerShell Remoting

```powershell
$cred = Get-Credential -UserName "HRMSMRFLRII\azureadmin"
Enter-PSSession -ComputerName 10.10.4.4 -Credential $cred
```

### WinRM (Ansible)

```bash
# From ansible controller
ansible -i ~/ansible/azure-ad/inventory.yml AZDC01 -m win_ping
```

---

## Enterprise Tiering Model

### OU Structure

```
DC=hrmsmrflrii,DC=xyz
├── OU=Tier 0
│   ├── OU=Admin Accounts
│   ├── OU=Admin Groups
│   ├── OU=Admin Workstations
│   ├── OU=Service Accounts
│   └── OU=Servers
├── OU=Tier 1
│   ├── OU=Admin Accounts
│   ├── OU=Admin Groups
│   ├── OU=Service Accounts
│   └── OU=Servers
│       ├── OU=Application Servers
│       ├── OU=Database Servers
│       ├── OU=Web Servers
│       └── OU=File Servers
├── OU=Tier 2
│   ├── OU=Admin Accounts
│   ├── OU=Admin Groups
│   ├── OU=Service Accounts
│   └── OU=Workstations
│       ├── OU=Windows 11
│       ├── OU=Windows 10
│       └── OU=Kiosks
├── OU=Corporate
│   ├── OU=Users
│   ├── OU=Groups
│   │   ├── OU=Security Groups
│   │   └── OU=Distribution Lists
│   └── OU=Departments
│       ├── OU=IT
│       ├── OU=Finance
│       ├── OU=HR
│       ├── OU=Sales
│       ├── OU=Engineering
│       ├── OU=Operations
│       ├── OU=Legal
│       └── OU=Executive
├── OU=Quarantine
│   ├── OU=Disabled Users
│   └── OU=Disabled Computers
└── OU=Staging
    ├── OU=New Users
    └── OU=New Computers
```

### Security Groups Summary

| Tier | Groups |
|------|--------|
| **Tier 0** | T0-Domain-Admins, T0-Enterprise-Admins, T0-Schema-Admins, T0-DC-Admins, T0-PKI-Admins, T0-PAW-Users |
| **Tier 1** | T1-Server-Admins, T1-SQL-Admins, T1-Web-Admins, T1-App-Admins, T1-File-Admins, T1-Backup-Operators |
| **Tier 2** | T2-Workstation-Admins, T2-Helpdesk-L1, T2-Helpdesk-L2, T2-Desktop-Support |
| **Corporate** | All-Employees, Dept-IT, Dept-Finance, Dept-HR, VPN-Users, FS-Finance-Read, APP-ERP-Users |

---

## Deployment Details

### Terraform Location

```
ubuntu-deploy-vm:/opt/terraform/azure-hybrid-lab/
├── main.tf
├── providers.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── modules/
    ├── connectivity/
    ├── platform-lz/
    └── app-lz/
```

### Ansible Location

```
ansible-controller:~/ansible/azure-ad/
├── inventory.yml
└── deploy-active-directory.yml
```

### Deployment Commands

```bash
# Terraform (from ubuntu-deploy-vm)
ssh ubuntu-deploy
cd /opt/terraform/azure-hybrid-lab
az login --identity
terraform apply

# Ansible (from ansible controller)
ssh ansible
cd ~/ansible/azure-ad
ansible-playbook -i inventory.yml deploy-active-directory.yml
```

---

## Network Configuration

### VPN Requirements

OPNsense must have route to Azure:

| Destination | Gateway |
|-------------|---------|
| 10.10.0.0/21 | VPN Tunnel |

### DNS Configuration

| Property | Value |
|----------|-------|
| **Internal DNS** | 10.10.4.4, 10.10.4.5 |
| **Forwarders** | 8.8.8.8, 8.8.4.4 |

---

## Costs

| Resource | Monthly Cost |
|----------|--------------|
| 4x Standard_B2s VMs | ~$120 USD |
| Data Disks | ~$5 USD |
| Other (ACR, peering) | ~$5 USD |
| **Total** | **~$130 USD/month** |

> **Tip**: Deallocate VMs when not in use to save costs.

---

## Common Tasks

### Check AD Replication

```powershell
repadmin /replsummary
repadmin /showrepl
```

### Check DC Health

```powershell
dcdiag /v
```

### List All Users

```powershell
Get-ADUser -Filter * | Select-Object SamAccountName, Name, Department
```

### List All Groups

```powershell
Get-ADGroup -Filter * | Where-Object {$_.Name -like "T*"} | Select-Object Name, GroupScope
```

---

## Troubleshooting

### Cannot Connect via RDP

1. Verify VPN is connected
2. Check OPNsense has route for 10.10.0.0/21
3. Verify VM is running in Azure Portal

### AD Replication Failed

```powershell
# Check replication status
repadmin /replsummary

# Force replication
repadmin /syncall /APed
```

### DNS Not Resolving

```powershell
# Test DNS
Resolve-DnsName hrmsmrflrii.xyz -Server 10.10.4.4

# Check forwarders
Get-DnsServerForwarder
```

---

## Related Documents

- [[36 - Azure Environment]] - Base Azure setup
- [[01 - Network Architecture]] - VPN configuration
- [[06 - Ansible Automation]] - Ansible details

---

*Last updated: January 7, 2026*
