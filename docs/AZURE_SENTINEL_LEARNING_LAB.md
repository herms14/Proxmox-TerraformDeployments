# Azure Sentinel Learning Lab

> **Purpose**: Hands-on security monitoring lab using Microsoft Sentinel SIEM
> **Status**: Production - Data Flowing
> **Last Updated**: January 15, 2026

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Deployed Infrastructure](#2-deployed-infrastructure)
3. [Data Sources and Collection](#3-data-sources-and-collection)
4. [Analytics Rules Reference](#4-analytics-rules-reference)
5. [Learning Scenarios](#5-learning-scenarios)
6. [KQL Query Library](#6-kql-query-library)
7. [Incident Response Procedures](#7-incident-response-procedures)
8. [Maintenance and Operations](#8-maintenance-and-operations)

---

## 1. Architecture Overview

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AZURE SENTINEL SIEM                                 │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                    Microsoft Sentinel (law-homelab-sentinel)                 ││
│  │                                                                              ││
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   ││
│  │   │  Analytics   │  │   Hunting    │  │  Workbooks   │  │  Incidents   │   ││
│  │   │    Rules     │  │   Queries    │  │ (Dashboards) │  │   (Cases)    │   ││
│  │   └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                        │                                         │
│  ┌─────────────────────────────────────┼─────────────────────────────────────┐  │
│  │                    Log Analytics Workspace                                 │  │
│  │                                                                            │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────┐│  │
│  │  │  Syslog    │ │ Security   │ │  Windows   │ │  Azure     │ │Heartbeat ││  │
│  │  │  (Linux)   │ │   Event    │ │   Event    │ │ Activity   │ │          ││  │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘ └──────────┘│  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        ▲
                                        │
        ┌───────────────────────────────┼───────────────────────────────┐
        │                               │                               │
┌───────┴───────┐               ┌───────┴───────┐               ┌───────┴───────┐
│   ON-PREM     │               │  AZURE VMs    │               │    AZURE      │
│   HOMELAB     │               │ (Hybrid Lab)  │               │  PLATFORM     │
│               │               │               │               │               │
│ ┌───────────┐ │               │ ┌───────────┐ │               │ ┌───────────┐ │
│ │ Proxmox   │ │               │ │  AZDC01   │ │               │ │ Activity  │ │
│ │ Nodes x3  │ │               │ │  AZDC02   │ │               │ │   Logs    │ │
│ ├───────────┤ │               │ │  AZRODC01 │ │               │ ├───────────┤ │
│ │ Docker    │ │               │ │  AZRODC02 │ │               │ │  VNet     │ │
│ │ Hosts x3  │ │               │ └───────────┘ │               │ │ Diag Logs │ │
│ ├───────────┤ │               │      │        │               │ ├───────────┤ │
│ │ Syslog    │─┼───rsyslog────►│      │        │               │ │   NSG     │ │
│ │ Collector │ │               │      │        │               │ │   Logs    │ │
│ │192.168.40.5│ │               │    AMA       │               │ └───────────┘ │
│ └───────────┘ │               │   Agent       │               │               │
│      │        │               │      │        │               │               │
│   Arc Agent   │               │      │        │               │               │
│      │        │               │      ▼        │               │               │
│      └────────┼───────────────┼──► DCR ◄──────┼───────────────┘               │
│               │               │               │                               │
└───────────────┘               └───────────────┘
```

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **Log Analytics Workspace** | Central log repository | law-homelab-sentinel (Southeast Asia) |
| **Data Collection Endpoint** | Windows agent communication | dce-homelab-windows |
| **Data Collection Rules** | Define what data to collect | 3 DCRs (Windows Security, AD Events, Syslog) |
| **Azure Monitor Agent** | Collects and forwards logs | On all monitored VMs |
| **Azure Arc** | Hybrid server management | On linux-syslog-server01 |
| **Analytics Rules** | Automated threat detection | 10 custom rules deployed |

---

## 2. Deployed Infrastructure

### Terraform Configuration

| Resource | ID/Name | Purpose |
|----------|---------|---------|
| **Resource Group** | rg-homelab-sentinel | Contains all Sentinel resources |
| **Log Analytics Workspace** | law-homelab-sentinel | Central log repository |
| **Data Collection Endpoint** | dce-homelab-windows | Windows agent endpoint |

### Data Collection Rules (DCRs)

| DCR Name | Type | Data Collected |
|----------|------|----------------|
| **dcr-windows-security-events** | Windows | Security Event IDs (4624, 4625, 4672, etc.) |
| **dcr-activedirectory-events** | Windows | Directory Service, DNS, DFS logs |
| **dcr-syslog-extended** | Linux | auth, authpriv, syslog, daemon, etc. |

### DCR Associations

| VM | DCR | Status |
|----|-----|--------|
| AZDC01 | dcr-windows-security-events, dcr-activedirectory-events | Active |
| AZDC02 | dcr-windows-security-events, dcr-activedirectory-events | Active |
| AZRODC01 | dcr-windows-security-events, dcr-activedirectory-events | Active |
| AZRODC02 | dcr-windows-security-events, dcr-activedirectory-events | Active |
| linux-syslog-server01 | dcr-syslog-extended | Active (via Arc) |

### Diagnostic Settings

| Resource | Setting Name | Logs Forwarded |
|----------|--------------|----------------|
| Subscription | diag-activity-sentinel | Administrative, Security, Policy, Alert, ServiceHealth |
| VNet | diag-vnet-sentinel | VMProtectionAlerts, AllMetrics |
| NSG | diag-nsg-sentinel | NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter |

---

## 3. Data Sources and Collection

### Windows Security Events (Domain Controllers)

Events collected via Azure Monitor Agent:

| Category | Event IDs | Purpose |
|----------|-----------|---------|
| **Authentication** | 4624, 4625, 4626, 4634, 4647, 4648, 4672, 4740 | Logon success/failure, privilege use |
| **Account Management** | 4720-4726, 4738 | User create/delete/modify |
| **Group Management** | 4727-4734, 4756, 4757 | Group membership changes |
| **Kerberos** | 4768, 4769, 4771, 4776 | Ticket operations, credential validation |
| **Directory Service** | 4662, 5136, 5137, 5141 | AD object access and changes |
| **Audit** | 1102, 4688, 4697, 4698, 4719 | Log cleared, process creation, scheduled tasks |

### Linux Syslog (Homelab Infrastructure)

Collected from linux-syslog-server01 (192.168.40.5) which aggregates:

| Source | Facility | Events |
|--------|----------|--------|
| **Proxmox Nodes** | auth, daemon, syslog | Node authentication, services |
| **Docker Hosts** | daemon, local0-7 | Container events |
| **Network Devices** | local0-4 | OPNsense, Omada logs (future) |

### Azure Platform Logs

| Log Type | Source | Key Events |
|----------|--------|------------|
| **AzureActivity** | Subscription | Resource create/delete, policy changes |
| **VMProtectionAlerts** | VNet | DDoS mitigation events |
| **NSG Flow Logs** | Network Security Group | Traffic allow/deny (disabled - policy conflict) |

---

## 4. Analytics Rules Reference

### Windows Security Rules

| Rule Name | Severity | Trigger | MITRE ATT&CK |
|-----------|----------|---------|--------------|
| **Brute Force Attack** | High | >20 failed logons from same IP in 1h | T1110 (Credential Access) |
| **Sensitive Group Changed** | High | Member added/removed from Domain Admins, etc. | T1098 (Privilege Escalation) |
| **Security Log Cleared** | High | Event ID 1102 detected | T1070 (Defense Evasion) |

### Linux/Syslog Rules

| Rule Name | Severity | Trigger | MITRE ATT&CK |
|-----------|----------|---------|--------------|
| **SSH Brute Force** | High | >10 failed SSH attempts from same IP | T1110 (Credential Access) |
| **SSH from New IP** | Medium | Successful login from IP not seen in 7 days | T1078 (Valid Accounts) |
| **Sudo to Root Shell** | Medium | sudo command spawning /bin/bash or /bin/sh | T1548 (Privilege Escalation) |
| **Proxmox Critical Error** | High | Critical/Alert/Emergency syslog from nodes | T1499 (Impact) |

### Network Rules

| Rule Name | Severity | Trigger | MITRE ATT&CK |
|-----------|----------|---------|--------------|
| **Port Scan Detected** | Medium | >10 unique blocked ports from same IP | T1046 (Discovery) |
| **VPN Connection Failure** | Low | >5 VPN failures in 24 hours | T1133 (External Services) |
| **New Wireless Client** | Informational | Unknown MAC address on network | T1078 (Initial Access) |

---

## 5. Learning Scenarios

### Scenario 1: Brute Force Attack Simulation

**Objective**: Trigger the brute force detection rule and investigate the incident.

**Difficulty**: Beginner

#### Steps

1. **Generate Failed Logons** (from a test machine):
```powershell
# PowerShell - Run against Domain Controller
$dc = "AZDC01.hrmsmrflrii.xyz"
$creds = @(
    @{user="fakeuser1"; pass="wrongpass"},
    @{user="fakeuser2"; pass="wrongpass"},
    @{user="administrator"; pass="wrongpass"}
)

foreach ($i in 1..25) {
    $c = $creds[$i % 3]
    try {
        $secPass = ConvertTo-SecureString $c.pass -AsPlainText -Force
        $credential = New-Object PSCredential("$($c.user)@hrmsmrflrii.xyz", $secPass)
        Enter-PSSession -ComputerName $dc -Credential $credential -ErrorAction SilentlyContinue
    } catch { }
    Start-Sleep -Milliseconds 500
}
```

2. **Wait for Detection** (5-10 minutes for rule to trigger)

3. **Investigate in Sentinel**:
```kql
// Find the incident
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4625
| summarize FailedAttempts = count(), Accounts = make_set(TargetUserName) by IpAddress
| where FailedAttempts > 10
```

4. **Response Actions**:
   - Document source IP
   - Check if IP is internal or external
   - Block IP if malicious
   - Reset compromised accounts if any succeeded

#### Expected Outcome

- Sentinel incident created: "Brute Force Attack - Multiple Failed Logons"
- Incident contains: Source IP, target computer, failed attempt count
- Entity mapping shows IP and Host entities

---

### Scenario 2: Privilege Escalation Detection

**Objective**: Detect unauthorized addition to sensitive groups.

**Difficulty**: Intermediate

#### Steps

1. **Create Test User** (on Domain Controller):
```powershell
# Create a regular user
New-ADUser -Name "TestUser" -SamAccountName "testuser" -UserPrincipalName "testuser@hrmsmrflrii.xyz" -Enabled $true -AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force)
```

2. **Add to Domain Admins** (simulating privilege escalation):
```powershell
# This should trigger the alert
Add-ADGroupMember -Identity "Domain Admins" -Members "testuser"
```

3. **Investigate in Sentinel**:
```kql
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID in (4728, 4732, 4756)  // Member added to security/local/universal group
| where TargetUserName has_any ("Domain Admins", "Enterprise Admins", "Administrators")
| project TimeGenerated, Action="Member Added", GroupName=TargetUserName,
          MemberAdded=MemberName, ChangedBy=SubjectUserName, Computer
```

4. **Clean Up**:
```powershell
Remove-ADGroupMember -Identity "Domain Admins" -Members "testuser" -Confirm:$false
Remove-ADUser -Identity "testuser" -Confirm:$false
```

#### Expected Outcome

- Incident: "Sensitive Group Membership Changed"
- Shows: Group modified, member added, who made the change

---

### Scenario 3: SSH Brute Force (Linux)

**Objective**: Trigger SSH brute force detection from homelab systems.

**Difficulty**: Beginner

#### Steps

1. **Generate Failed SSH Attempts** (from any Linux machine):
```bash
# Install hydra if needed: apt install hydra
# Run against the syslog collector
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.40.5 -t 4 -w 1 -V
```

Or manually:
```bash
for i in {1..15}; do
  sshpass -p 'wrongpassword' ssh -o StrictHostKeyChecking=no fakeuser@192.168.40.5 2>/dev/null
  sleep 1
done
```

2. **Verify Logs Arrive**:
```kql
Syslog
| where TimeGenerated > ago(30m)
| where Facility in ("auth", "authpriv")
| where SyslogMessage has "Failed password"
| take 20
```

3. **Check for Alert**:
```kql
Syslog
| where TimeGenerated > ago(1h)
| where Facility in ("auth", "authpriv")
| where SyslogMessage has "Failed password"
| parse SyslogMessage with * "Failed password for " TargetUser " from " SourceIP " port" *
| summarize FailedAttempts = count() by SourceIP, Computer
| where FailedAttempts > 10
```

#### Expected Outcome

- Incident: "SSH Brute Force Attack Detected"
- Entity: Source IP flagged as potential attacker

---

### Scenario 4: Insider Threat - Log Tampering

**Objective**: Detect security log clearing (defense evasion).

**Difficulty**: Intermediate

#### Steps

1. **Clear Security Log** (on Domain Controller, requires admin):
```powershell
# WARNING: This clears the security log - only do in lab
wevtutil cl Security
```

2. **Investigate**:
```kql
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 1102
| project TimeGenerated, ClearedBy=SubjectUserName, Domain=SubjectDomainName, Computer
```

3. **Cross-Reference Activity**:
```kql
// What else did this user do around that time?
let clearer = SecurityEvent
| where EventID == 1102
| project SubjectUserName, ClearTime=TimeGenerated;

SecurityEvent
| where TimeGenerated between (clearer.ClearTime - 1h .. clearer.ClearTime)
| where SubjectUserName == clearer.SubjectUserName
| summarize Actions = count() by EventID, Activity
```

#### Expected Outcome

- High severity incident: "Security Event Log Cleared"
- Investigation reveals who cleared logs and their recent activity

---

### Scenario 5: Lateral Movement Detection

**Objective**: Detect suspicious remote logons across the domain.

**Difficulty**: Advanced

#### Steps

1. **Simulate Pass-the-Hash** (using legitimate tools for testing):
```powershell
# Use runas with saved credentials to access multiple systems
runas /user:HRMSMRFLRII\administrator "powershell -Command {Enter-PSSession AZDC02}"
runas /user:HRMSMRFLRII\administrator "powershell -Command {Enter-PSSession AZRODC01}"
```

2. **Hunt for Lateral Movement**:
```kql
// Find users logging into multiple systems in short timeframe
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4624
| where LogonType in (3, 10)  // Network and RemoteInteractive
| summarize
    SystemsAccessed = dcount(Computer),
    Systems = make_set(Computer),
    LogonCount = count()
  by TargetUserName, IpAddress, bin(TimeGenerated, 15m)
| where SystemsAccessed > 2
| project TimeGenerated, TargetUserName, IpAddress, SystemsAccessed, Systems
```

3. **Correlate with Process Creation**:
```kql
// What commands ran after remote logon?
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4688  // Process creation
| where ParentProcessName has_any ("wsmprovhost", "powershell", "cmd")
| project TimeGenerated, Computer, Account, NewProcessName, CommandLine
```

#### Expected Outcome

- Custom hunting query identifies multi-system access
- Process execution shows post-exploitation activity

---

### Scenario 6: Ransomware Behavior Detection

**Objective**: Detect behaviors associated with ransomware (mass file access, encryption).

**Difficulty**: Advanced

#### Steps

1. **Simulate Mass File Operations** (safe simulation):
```powershell
# Create test files
1..100 | ForEach-Object {
    New-Item -Path "C:\TestRansomware\file$_.txt" -ItemType File -Value "Test content"
}

# Simulate reading all files (ransomware reads before encrypting)
Get-ChildItem "C:\TestRansomware\*.txt" | ForEach-Object {
    Get-Content $_.FullName | Out-Null
}
```

2. **Hunt Query**:
```kql
// Unusual volume of file operations
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4663  // Object access
| summarize
    FileOperations = count(),
    UniqueFiles = dcount(ObjectName)
  by SubjectUserName, Computer, bin(TimeGenerated, 5m)
| where FileOperations > 100
```

---

### Scenario 7: Network Reconnaissance

**Objective**: Detect port scanning from internal systems.

**Difficulty**: Intermediate

#### Steps

1. **Run Port Scan** (from authorized test machine):
```bash
# Install nmap if needed
nmap -sS -p 1-1000 192.168.40.0/24
```

2. **Check Firewall Logs** (if OPNsense configured):
```kql
Syslog
| where TimeGenerated > ago(1h)
| where Facility == "local4" or Computer has "opnsense"
| where SyslogMessage has "block"
| parse SyslogMessage with * "SRC=" SourceIP " DST=" DestIP " " * "DPT=" DestPort " " *
| summarize BlockedPorts = dcount(DestPort), Ports = make_set(DestPort) by SourceIP
| where BlockedPorts > 10
```

#### Expected Outcome

- Incident: "Potential Port Scan Detected"
- Shows source IP and number of unique ports scanned

---

## 6. KQL Query Library

### Authentication Analysis

```kql
// Failed logons by user
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4625
| summarize FailedLogons = count() by TargetUserName
| order by FailedLogons desc
| take 10

// Successful logons outside business hours
SecurityEvent
| where TimeGenerated > ago(7d)
| where EventID == 4624
| where LogonType in (2, 10)  // Interactive, RemoteInteractive
| extend Hour = datetime_part("hour", TimeGenerated)
| where Hour < 6 or Hour > 22  // Before 6 AM or after 10 PM
| project TimeGenerated, Account=TargetUserName, Computer, LogonType

// Logon type breakdown
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4624
| extend LogonTypeName = case(
    LogonType == 2, "Interactive",
    LogonType == 3, "Network",
    LogonType == 4, "Batch",
    LogonType == 5, "Service",
    LogonType == 7, "Unlock",
    LogonType == 8, "NetworkCleartext",
    LogonType == 9, "NewCredentials",
    LogonType == 10, "RemoteInteractive",
    LogonType == 11, "CachedInteractive",
    "Other"
)
| summarize count() by LogonTypeName
| render piechart
```

### Active Directory Monitoring

```kql
// User account changes
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID in (4720, 4722, 4723, 4724, 4725, 4726, 4738)
| extend Action = case(
    EventID == 4720, "Created",
    EventID == 4722, "Enabled",
    EventID == 4723, "Password Changed (Self)",
    EventID == 4724, "Password Reset",
    EventID == 4725, "Disabled",
    EventID == 4726, "Deleted",
    EventID == 4738, "Modified",
    "Unknown"
)
| project TimeGenerated, Action, TargetAccount=TargetUserName, ChangedBy=SubjectUserName

// Group membership changes
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID in (4728, 4729, 4732, 4733, 4756, 4757)
| extend Action = case(
    EventID in (4728, 4732, 4756), "Member Added",
    EventID in (4729, 4733, 4757), "Member Removed",
    "Unknown"
)
| project TimeGenerated, Action, Group=TargetUserName, Member=MemberName, ChangedBy=SubjectUserName

// Kerberos ticket requests (TGT)
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4768
| project TimeGenerated, Account=TargetUserName, ServiceName, ClientAddress=IpAddress, Status
```

### Syslog Analysis

```kql
// SSH activity summary
Syslog
| where TimeGenerated > ago(24h)
| where Facility in ("auth", "authpriv")
| where SyslogMessage has_any ("Accepted", "Failed", "Invalid")
| extend Status = case(
    SyslogMessage has "Accepted", "Success",
    SyslogMessage has "Failed", "Failed",
    SyslogMessage has "Invalid", "Invalid User",
    "Other"
)
| summarize count() by Status, Computer
| render columnchart

// Critical errors by system
Syslog
| where TimeGenerated > ago(24h)
| where SeverityLevel in ("crit", "alert", "emerg")
| summarize ErrorCount = count() by Computer, Facility
| order by ErrorCount desc

// Sudo usage
Syslog
| where TimeGenerated > ago(24h)
| where ProcessName == "sudo"
| parse SyslogMessage with User " : TTY=" * " ; PWD=" * " ; USER=" TargetUser " ; COMMAND=" Command
| project TimeGenerated, User, TargetUser, Command, Computer
```

### Data Flow Health

```kql
// Events per hour by table
union Syslog, SecurityEvent, AzureActivity, Heartbeat
| where TimeGenerated > ago(24h)
| summarize count() by Type, bin(TimeGenerated, 1h)
| render timechart

// Data sources reporting
Heartbeat
| where TimeGenerated > ago(1h)
| summarize LastHeartbeat = max(TimeGenerated) by Computer, OSType
| extend Status = iff(LastHeartbeat > ago(15m), "Healthy", "Stale")

// Ingestion latency
union Syslog, SecurityEvent
| where TimeGenerated > ago(1h)
| extend IngestionTime = ingestion_time()
| extend Latency = IngestionTime - TimeGenerated
| summarize AvgLatency = avg(Latency), MaxLatency = max(Latency) by Type
```

---

## 7. Incident Response Procedures

### Triage Workflow

1. **Initial Assessment**
   - Review incident severity and description
   - Check entity information (accounts, IPs, hosts)
   - Determine if true positive or false positive

2. **Investigation**
   - Run related hunting queries
   - Check timeline of events
   - Correlate with other data sources

3. **Containment**
   - Disable compromised accounts
   - Block malicious IPs
   - Isolate affected systems

4. **Documentation**
   - Update incident notes
   - Tag related entities
   - Set appropriate status

### Incident Status Workflow

```
New → Active → In Progress → Resolved/Closed
         ↓
      False Positive
```

### Response Playbooks

#### Brute Force Attack

1. Confirm attack (review failed logon count)
2. Check if any logons succeeded
3. Block source IP if external
4. Reset passwords for targeted accounts
5. Enable account lockout policy if not set

#### Privilege Escalation

1. Identify who made the change
2. Verify if authorized
3. Remove unauthorized group membership
4. Review recent activity of modified account
5. Check for persistence mechanisms

#### SSH Brute Force

1. Verify attack origin (internal/external)
2. Check for successful logons
3. Add IP to fail2ban blocklist
4. Review SSH configuration (key-only auth?)
5. Consider rate limiting

---

## 8. Maintenance and Operations

### Daily Tasks

- [ ] Review new incidents in Sentinel
- [ ] Check data ingestion health (Heartbeat table)
- [ ] Verify all DCs are reporting SecurityEvent

### Weekly Tasks

- [ ] Review analytics rule effectiveness
- [ ] Tune false positive rules
- [ ] Check DCR associations are active
- [ ] Review cost and ingestion volume

### Monthly Tasks

- [ ] Update analytics rules with new detections
- [ ] Review and archive old incidents
- [ ] Check for Sentinel content updates
- [ ] Practice incident response scenarios

### Useful Commands

```bash
# Check data flow from Azure VM
ssh -i ~/.ssh/ubuntu-deploy-vm hermes-admin@10.90.10.5 \
  "az monitor log-analytics query --workspace 252e98de-4401-4364-9b2d-ca2637c53636 \
   --analytics-query 'union Syslog, SecurityEvent | summarize count() by Type' -o table"

# Verify AMA status on DC
az vm extension list --resource-group RG-AZUREHYBRID-IDENTITY-PROD --vm-name AZDC01 -o table

# Check DCR associations
az monitor data-collection rule association list \
  --resource "/subscriptions/2212d587-1bad-4013-b605-b421b1f83c30/resourceGroups/RG-AZUREHYBRID-IDENTITY-PROD/providers/Microsoft.Compute/virtualMachines/AZDC01"
```

### Cost Monitoring

```kql
// Daily ingestion by table
Usage
| where TimeGenerated > ago(30d)
| summarize DailyGB = sum(Quantity) / 1024 by DataType, bin(TimeGenerated, 1d)
| order by TimeGenerated desc, DailyGB desc

// Estimate monthly cost (rough: $2.76/GB for Log Analytics + $2.46/GB for Sentinel)
Usage
| where TimeGenerated > ago(30d)
| summarize TotalGB = sum(Quantity) / 1024
| extend EstimatedMonthlyCost = TotalGB * 5.22
```

---

## Related Files

| File | Location | Purpose |
|------|----------|---------|
| **Terraform Config** | `terraform/azure/sentinel-learning/` | Infrastructure as Code |
| **Main Config** | `terraform/azure/sentinel-learning/main.tf` | DCRs, DCE, Analytics Rules |
| **VNet Diagnostics** | `terraform/azure/sentinel-learning/vnet-diagnostics.tf` | VNet/NSG logging |
| **Syslog Rules** | `terraform/azure/sentinel-learning/analytics-rules-syslog.tf` | Linux detection rules |
| **Variables** | `terraform/azure/sentinel-learning/variables.tf` | Configuration variables |

---

**Document Version**: 1.0
**Last Updated**: January 15, 2026
**Author**: Hermes Miraflor II with Claude Code
