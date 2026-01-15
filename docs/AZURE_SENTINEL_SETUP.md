# Azure Sentinel Setup Guide

> **Purpose**: Centralized SIEM for homelab security monitoring and learning
> **Status**: ✅ Fully Deployed via Terraform
>
> **See Also**: [Azure Sentinel Learning Lab](./AZURE_SENTINEL_LEARNING_LAB.md) - Comprehensive tutorial with learning scenarios, architecture diagrams, and KQL queries

> **Note**: This document describes the manual setup process. The current deployment uses Terraform for infrastructure-as-code. See `terraform/azure/sentinel-learning/` for the IaC implementation.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Microsoft Sentinel                                  │
│                    (Detection Rules, Hunting, Workbooks)                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│                          Log Analytics Workspace                                 │
│                         (homelab-sentinel-law)                                   │
├──────────────┬──────────────┬──────────────┬──────────────┬────────────────────┤
│    Syslog    │ SecurityEvent│ AzureActivity│  SigninLogs  │   AuditLogs        │
│   (Network)  │    (DC)      │   (Azure)    │  (Entra ID)  │   (Entra ID)       │
└──────┬───────┴──────┬───────┴──────┬───────┴──────┬───────┴────────┬───────────┘
       │              │              │              │                │
       ▲              ▲              ▲              ▲                ▲
┌──────┴──────┐ ┌─────┴─────┐ ┌─────┴─────┐ ┌─────┴─────┐  ┌───────┴────────┐
│ Syslog Srv  │ │  Domain   │ │   Azure   │ │  Entra ID │  │  Azure Arc     │
│ 192.168.40.5│ │Controller │ │Diagnostic │ │ Diagnostic│  │  (Hybrid VMs)  │
│             │ │           │ │ Settings  │ │  Settings │  │                │
│ ◄─ Omada    │ │           │ │           │ │           │  │                │
│ ◄─ OPNsense │ │           │ │           │ │           │  │                │
│ ◄─ Proxmox  │ │           │ │           │ │           │  │                │
└─────────────┘ └───────────┘ └───────────┘ └───────────┘  └────────────────┘
```

---

## Implementation Phases

| Phase | Data Source | Status | Est. Cost/Month |
|-------|-------------|--------|-----------------|
| **1** | Omada Network Logs (Syslog) | 🔄 In Progress | ~$10-15 |
| **2** | Azure Activity Logs | Planned | ~$5-10 |
| **3** | Entra ID Sign-in/Audit Logs | Planned | ~$5-10 |
| **4** | Domain Controller (SecurityEvent) | Planned | ~$15-25 |
| **5** | OPNsense Firewall Logs | Future | ~$10-20 |
| **6** | Proxmox Audit Logs | Future | ~$5-10 |

**Estimated Total**: ~$50-90/month (depending on log volume)

---

## Phase 1: Foundation Setup

### Step 1.1: Create Resource Group

```bash
# Azure CLI
az group create \
  --name rg-homelab-sentinel \
  --location eastus
```

### Step 1.2: Create Log Analytics Workspace

```bash
az monitor log-analytics workspace create \
  --resource-group rg-homelab-sentinel \
  --workspace-name homelab-sentinel-law \
  --location eastus \
  --retention-time 90
```

**Retention Options**:
| Retention | Cost Impact |
|-----------|-------------|
| 30 days | Included |
| 90 days | Recommended for learning |
| 365 days | Compliance (higher cost) |

### Step 1.3: Enable Microsoft Sentinel

```bash
az sentinel onboard create \
  --resource-group rg-homelab-sentinel \
  --workspace-name homelab-sentinel-law
```

Or via Azure Portal:
1. Search for "Microsoft Sentinel"
2. Click "Create"
3. Select your Log Analytics workspace
4. Click "Add"

---

## Phase 2: Syslog Integration (Omada Logs)

### Step 2.1: Install Azure Monitor Agent

SSH to linux-syslog-server01 (192.168.40.5):

```bash
# Download and install AMA
wget https://aka.ms/InstallAzureMonitorAgentLinux -O InstallAMA.sh
sudo bash InstallAMA.sh

# Verify installation
systemctl status azuremonitoragent
```

### Step 2.2: Create Data Collection Endpoint (DCE)

```bash
az monitor data-collection endpoint create \
  --resource-group rg-homelab-sentinel \
  --name dce-homelab-syslog \
  --location eastus \
  --public-network-access Enabled
```

### Step 2.3: Create Data Collection Rule (DCR)

```json
{
  "location": "eastus",
  "properties": {
    "dataSources": {
      "syslog": [
        {
          "name": "syslogDataSource",
          "streams": ["Microsoft-Syslog"],
          "facilityNames": [
            "auth",
            "authpriv",
            "local0",
            "local1",
            "local2",
            "local3",
            "local4",
            "local5",
            "local6",
            "local7",
            "syslog",
            "user"
          ],
          "logLevels": [
            "Debug",
            "Info",
            "Notice",
            "Warning",
            "Error",
            "Critical",
            "Alert",
            "Emergency"
          ]
        }
      ]
    },
    "destinations": {
      "logAnalytics": [
        {
          "workspaceResourceId": "/subscriptions/<SUB_ID>/resourceGroups/rg-homelab-sentinel/providers/Microsoft.OperationalInsights/workspaces/homelab-sentinel-law",
          "name": "sentinel-destination"
        }
      ]
    },
    "dataFlows": [
      {
        "streams": ["Microsoft-Syslog"],
        "destinations": ["sentinel-destination"]
      }
    ]
  }
}
```

### Step 2.4: Associate DCR with VM

```bash
# Get VM resource ID (if Azure VM) or Arc resource ID (if on-prem)
az monitor data-collection rule association create \
  --name syslog-server-dcr-association \
  --rule-id /subscriptions/<SUB_ID>/resourceGroups/rg-homelab-sentinel/providers/Microsoft.Insights/dataCollectionRules/dcr-syslog \
  --resource /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Compute/virtualMachines/linux-syslog-server01
```

**For On-Prem Servers (Azure Arc)**:
1. Install Azure Arc agent on linux-syslog-server01
2. Register with Azure Arc
3. Associate DCR with Arc-enabled server

---

## Phase 3: Azure Activity Logs

### Step 3.1: Enable Diagnostic Settings

```bash
# For each subscription
az monitor diagnostic-settings create \
  --name sentinel-activity-logs \
  --resource /subscriptions/<SUB_ID> \
  --workspace /subscriptions/<SUB_ID>/resourceGroups/rg-homelab-sentinel/providers/Microsoft.OperationalInsights/workspaces/homelab-sentinel-law \
  --logs '[{"category": "Administrative", "enabled": true}, {"category": "Security", "enabled": true}, {"category": "Policy", "enabled": true}]'
```

### Step 3.2: Enable Sentinel Connector

1. In Sentinel → Data connectors
2. Search "Azure Activity"
3. Click "Open connector page"
4. Select subscriptions to connect
5. Click "Connect"

---

## Phase 4: Entra ID (Azure AD) Logs

### Step 4.1: Enable Diagnostic Settings

Requires: Entra ID P1 or P2 license (or free trial)

1. Azure Portal → Entra ID → Monitoring → Diagnostic settings
2. Add diagnostic setting:
   - **Name**: sentinel-entra-logs
   - **Logs**:
     - ✅ AuditLogs
     - ✅ SignInLogs
     - ✅ NonInteractiveUserSignInLogs
     - ✅ ServicePrincipalSignInLogs
   - **Destination**: Send to Log Analytics workspace

### Step 4.2: Enable Sentinel Connector

1. Sentinel → Data connectors
2. Search "Azure Active Directory"
3. Enable Sign-in logs and Audit logs

---

## Phase 5: Domain Controller Logs

### Option A: Azure Monitor Agent (Recommended)

1. Install AMA on Domain Controller
2. Create DCR for SecurityEvent table
3. Collect Event IDs:

| Event ID | Description |
|----------|-------------|
| 4624 | Successful logon |
| 4625 | Failed logon |
| 4648 | Explicit credential logon |
| 4672 | Special privileges assigned |
| 4720 | User account created |
| 4726 | User account deleted |
| 4732 | Member added to security group |
| 4756 | Member added to universal group |

### Option B: Legacy Log Analytics Agent (MMA)

```powershell
# On Domain Controller (PowerShell)
$workspaceId = "<WORKSPACE_ID>"
$workspaceKey = "<PRIMARY_KEY>"

# Download and install MMA
# Configure to send Security events
```

---

## Sentinel Analytics Rules

### Recommended Detection Rules

| Rule | Data Source | Description |
|------|-------------|-------------|
| **Brute Force Attack** | SignInLogs | Multiple failed logins from same IP |
| **Impossible Travel** | SignInLogs | User logs in from distant locations |
| **New Device on Network** | Syslog (Omada) | Unknown MAC address detected |
| **Privilege Escalation** | SecurityEvent | User added to admin group |
| **Suspicious Azure Activity** | AzureActivity | Resource deletion, policy changes |
| **After-Hours Activity** | All | Activity outside business hours |

### Custom Rule: Rogue Device Detection

```kql
// Detect new MAC addresses on network
Syslog
| where Facility == "local0"  // Omada logs
| where SyslogMessage contains "new client"
| extend MAC = extract("MAC=([0-9A-Fa-f:]+)", 1, SyslogMessage)
| where MAC !in (
    "AA:BB:CC:DD:EE:FF",  // Known device 1
    "11:22:33:44:55:66"   // Known device 2
)
| project TimeGenerated, MAC, SyslogMessage
```

### Custom Rule: Cross-Source Correlation

```kql
// Failed Azure login followed by successful DC login
let AzureFailures = SigninLogs
| where ResultType != "0"
| project AzureTime=TimeGenerated, UserPrincipalName, IPAddress;

let DCSuccess = SecurityEvent
| where EventID == 4624
| project DCTime=TimeGenerated, Account, IpAddress;

AzureFailures
| join kind=inner (DCSuccess) on $left.UserPrincipalName == $right.Account
| where DCTime between (AzureTime .. AzureTime + 1h)
| project AzureTime, DCTime, UserPrincipalName, AzureIP=IPAddress, DCIP=IpAddress
```

---

## Workbooks

### Network Overview Workbook

```kql
// Client count over time
Syslog
| where Facility == "local0"
| where SyslogMessage contains "client"
| summarize ClientEvents = count() by bin(TimeGenerated, 1h)
| render timechart

// Top talkers
Syslog
| where Facility == "local0"
| extend MAC = extract("MAC=([0-9A-Fa-f:]+)", 1, SyslogMessage)
| summarize Events = count() by MAC
| top 10 by Events
| render piechart
```

### Security Overview Workbook

```kql
// Failed logins by source
SigninLogs
| where ResultType != "0"
| summarize FailedLogins = count() by IPAddress
| top 10 by FailedLogins
| render barchart

// Successful logins by location
SigninLogs
| where ResultType == "0"
| summarize Logins = count() by Location
| render piechart
```

---

## Cost Optimization

### Free Tier Maximization

| Feature | Free Allowance |
|---------|----------------|
| Log Analytics | 5GB/month (first 31 days) |
| Sentinel | 10GB/day (first 31 days trial) |
| Data retention | 31 days included |

### Cost Reduction Tips

1. **Filter logs at source**: Only send relevant syslog facilities
2. **Use Basic Logs tier**: For high-volume, low-query logs
3. **Set retention wisely**: 90 days is usually enough for learning
4. **Use commitment tiers**: If >100GB/day, use commitment pricing
5. **Archive old logs**: Move to cold storage after 90 days

### Estimated Monthly Costs

| Log Source | Volume Est. | Log Analytics | Sentinel | Total |
|------------|-------------|---------------|----------|-------|
| Omada Syslog | 2GB | $5.52 | $4.92 | $10.44 |
| Azure Activity | 1GB | $2.76 | $2.46 | $5.22 |
| Entra ID | 1GB | $2.76 | $2.46 | $5.22 |
| Domain Controller | 5GB | $13.80 | $12.30 | $26.10 |
| **Total** | **9GB** | **$24.84** | **$22.14** | **$46.98** |

---

## Maintenance Tasks

### Weekly
- [ ] Review Sentinel incidents
- [ ] Check data ingestion volume
- [ ] Validate all data sources connected

### Monthly
- [ ] Review and tune analytics rules
- [ ] Check for new Sentinel content updates
- [ ] Review cost and optimize if needed

### Quarterly
- [ ] Audit data retention settings
- [ ] Review and update detection rules
- [ ] Practice incident response procedures

---

## Troubleshooting

### No Syslog Data in Sentinel

1. Check rsyslog is receiving logs:
   ```bash
   tail -f /var/log/remote/omada/omada.log
   ```

2. Check AMA is running:
   ```bash
   systemctl status azuremonitoragent
   ```

3. Check DCR association:
   ```bash
   az monitor data-collection rule association list --resource <VM_RESOURCE_ID>
   ```

4. Query Log Analytics:
   ```kql
   Syslog
   | where TimeGenerated > ago(1h)
   | take 10
   ```

### High Ingestion Costs

1. Identify top data sources:
   ```kql
   Usage
   | where TimeGenerated > ago(30d)
   | summarize TotalGB = sum(Quantity) / 1024 by DataType
   | order by TotalGB desc
   ```

2. Filter noisy logs at source (rsyslog)
3. Consider Basic Logs tier for high-volume tables

---

## References

- [Microsoft Sentinel Documentation](https://learn.microsoft.com/en-us/azure/sentinel/)
- [Azure Monitor Agent Installation](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage)
- [KQL Quick Reference](https://learn.microsoft.com/en-us/azure/data-explorer/kql-quick-reference)
- [Sentinel Pricing](https://azure.microsoft.com/en-us/pricing/details/microsoft-sentinel/)

---

## Local Infrastructure Reference

| Component | IP | Purpose |
|-----------|-----|---------|
| linux-syslog-server01 | 192.168.40.5 | Syslog aggregator |
| Omada Controller | 192.168.0.103 | Network logs source |
| OPNsense | 192.168.91.30 | Firewall logs (future) |
| Domain Controller | TBD | Security events (future) |

---

*Created: January 7, 2026*
*Last Updated: January 7, 2026*
