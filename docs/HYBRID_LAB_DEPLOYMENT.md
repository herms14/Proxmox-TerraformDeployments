# Hybrid Lab Deployment Guide

This guide covers the deployment of the Windows Server Active Directory hybrid lab on Proxmox VE.

## Architecture Overview

```
                         VLAN 80 (192.168.80.0/24)
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
   ┌────▼────┐              ┌──────▼──────┐            ┌──────▼──────┐
   │ node01  │              │   node03    │            │   Azure     │
   │(clients)│              │  (servers)  │            │  (Entra)    │
   └────┬────┘              └──────┬──────┘            └─────────────┘
        │                          │
   CLIENT01                   DC01 (PDC)
   CLIENT02                   DC02
                              SQL01
                              FS01, FS02
                              AADCON01
                              AADPP01, AADPP02
```

## VM Inventory

| VM | IP | Role | OS | Node | vCPU | RAM | Disk |
|----|-----|------|-----|------|------|-----|------|
| DC01 | 192.168.80.2 | Primary Domain Controller | WS 2025 | node03 | 2 | 4 GB | 60 GB |
| DC02 | 192.168.80.3 | Secondary Domain Controller | WS 2025 | node03 | 2 | 4 GB | 60 GB |
| FS01 | 192.168.80.4 | File Server 1 | WS 2022 | node03 | 2 | 4 GB | 100 GB |
| FS02 | 192.168.80.5 | File Server 2 | WS 2022 | node03 | 2 | 4 GB | 100 GB |
| SQL01 | 192.168.80.6 | SQL Server 2022 Standard | WS 2025 | node03 | 4 | 8 GB | 120 GB |
| AADCON01 | 192.168.80.7 | Entra ID Connect | WS 2022 | node03 | 2 | 4 GB | 60 GB |
| AADPP01 | 192.168.80.8 | Password Protection Proxy 1 | WS 2025 | node03 | 2 | 4 GB | 60 GB |
| AADPP02 | 192.168.80.9 | Password Protection Proxy 2 | WS 2025 | node03 | 2 | 4 GB | 60 GB |
| CLIENT01 | 192.168.80.12 | Windows 11 Workstation | Win 11 | node01 | 2 | 4 GB | 60 GB |
| CLIENT02 | 192.168.80.13 | Windows 11 Workstation | Win 11 | node01 | 2 | 4 GB | 60 GB |

**Totals**: 22 vCPU, 44 GB RAM, 740 GB Disk

## Domain Configuration

| Setting | Value |
|---------|-------|
| Forest/Domain Name | hrmsmrflrii.xyz |
| NetBIOS Name | HRMSMRFLRII |
| Forest Functional Level | Windows Server 2025 |
| Domain Functional Level | Windows Server 2025 |
| DNS Servers | 192.168.80.2, 192.168.80.3 |
| Gateway | 192.168.80.1 |

---

## Step 1: Configure VLAN 80 on OPNsense

### 1.1 Create VLAN Interface

1. Log into OPNsense: `https://192.168.91.30`
2. Navigate to **Interfaces → Other Types → VLAN**
3. Click **+** to add new VLAN:

| Setting | Value |
|---------|-------|
| Parent Interface | `vtnet1` (LAN trunk) |
| VLAN Tag | `80` |
| VLAN Priority | Leave default |
| Description | `VLAN80_HybridLab` |

4. Click **Save**

### 1.2 Assign Interface

1. Navigate to **Interfaces → Assignments**
2. Find the new VLAN in the dropdown (shows as `vlan 80 on vtnet1`)
3. Click **+** to assign it
4. Click **Save**

### 1.3 Configure Interface

1. Click on the new interface (e.g., **OPT4** or **VLAN80**)
2. Configure:

| Setting | Value |
|---------|-------|
| Enable | ✓ Checked |
| Description | `VLAN80_HybridLab` |
| IPv4 Configuration Type | `Static IPv4` |
| IPv4 Address | `192.168.80.1` / `24` |

3. Click **Save** then **Apply Changes**

### 1.4 Configure DHCP (Optional)

1. Navigate to **Services → DHCPv4 → VLAN80_HybridLab**
2. Configure:

| Setting | Value |
|---------|-------|
| Enable | ✓ Checked |
| Range | `192.168.80.100` to `192.168.80.254` |
| DNS Servers | `192.168.80.2`, `192.168.80.3` |
| Gateway | `192.168.80.1` |
| Domain Name | `hrmsmrflrii.xyz` |

3. Click **Save**

### 1.5 Create Firewall Rules

1. Navigate to **Firewall → Rules → VLAN80_HybridLab**
2. Add the following rules:

**Rule 1: Allow All Internal**
| Setting | Value |
|---------|-------|
| Action | Pass |
| Interface | VLAN80_HybridLab |
| Direction | in |
| Protocol | any |
| Source | VLAN80_HybridLab net |
| Destination | any |
| Description | Allow VLAN80 outbound |

**Rule 2: Allow from Infrastructure VLAN**
| Setting | Value |
|---------|-------|
| Action | Pass |
| Interface | VLAN80_HybridLab |
| Direction | in |
| Protocol | any |
| Source | 192.168.20.0/24 |
| Destination | VLAN80_HybridLab net |
| Description | Allow from Infrastructure |

3. Click **Apply Changes**

### 1.6 Add DNS Entries (After DC Deployment)

1. Navigate to **Services → Unbound DNS → Overrides**
2. Add Host Overrides for each VM:

| Host | Domain | IP |
|------|--------|-----|
| dc01 | hrmsmrflrii.xyz | 192.168.80.2 |
| dc02 | hrmsmrflrii.xyz | 192.168.80.3 |
| fs01 | hrmsmrflrii.xyz | 192.168.80.4 |
| fs02 | hrmsmrflrii.xyz | 192.168.80.5 |
| sql01 | hrmsmrflrii.xyz | 192.168.80.6 |
| aadcon01 | hrmsmrflrii.xyz | 192.168.80.7 |
| aadpp01 | hrmsmrflrii.xyz | 192.168.80.8 |
| aadpp02 | hrmsmrflrii.xyz | 192.168.80.9 |
| client01 | hrmsmrflrii.xyz | 192.168.80.12 |
| client02 | hrmsmrflrii.xyz | 192.168.80.13 |

---

## Step 2: Upload ISOs to Proxmox

### Required ISOs

| ISO | NAS Path | Proxmox Name |
|-----|----------|--------------|
| Windows Server 2025 | `Windows Server 2025/en-us_windows_server_2025_updated_dec_2025_x64_dvd_c54ab58b.iso` | `ws2025-dec2025.iso` |
| Windows Server 2022 | `Windows Server 2022/en-us_windows_server_2022_updated_dec_2025_x64_dvd_84450f64.iso` | `ws2022-dec2025.iso` |
| Windows 11 | `Windows 11/en-us_windows_11_consumer_editions_version_25h2_updated_dec_2025_x64_dvd_115b2867.iso` | `win11-25h2-dec2025.iso` |
| SQL Server 2022 | `SQL Server 2022/enu_sql_server_2022_standard_edition_x64_dvd_43079f69.iso` | `sql2022-std.iso` |
| VirtIO Drivers | Download from Proxmox | `virtio-win.iso` |

### Upload Commands

From the Ansible controller (192.168.20.30):

```bash
# SSH to Ansible controller
ssh hermes-admin@192.168.20.30

# Mount NAS if not already mounted
sudo mkdir -p /mnt/nas-isos
sudo mount -t cifs "//192.168.10.31/Main Volume/ISOs" /mnt/nas-isos -o username=hermes-admin,vers=3.0

# Copy ISOs to Proxmox node03
scp "/mnt/nas-isos/Windows Server 2025/en-us_windows_server_2025_updated_dec_2025_x64_dvd_c54ab58b.iso" \
    root@192.168.20.22:/var/lib/vz/template/iso/ws2025-dec2025.iso

scp "/mnt/nas-isos/Windows Server 2022/en-us_windows_server_2022_updated_dec_2025_x64_dvd_84450f64.iso" \
    root@192.168.20.22:/var/lib/vz/template/iso/ws2022-dec2025.iso

scp "/mnt/nas-isos/Windows 11/en-us_windows_11_consumer_editions_version_25h2_updated_dec_2025_x64_dvd_115b2867.iso" \
    root@192.168.20.22:/var/lib/vz/template/iso/win11-25h2-dec2025.iso

scp "/mnt/nas-isos/SQL Server 2022/enu_sql_server_2022_standard_edition_x64_dvd_43079f69.iso" \
    root@192.168.20.22:/var/lib/vz/template/iso/sql2022-std.iso

# Download VirtIO drivers
ssh root@192.168.20.22 "wget -O /var/lib/vz/template/iso/virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
```

### Alternative: Proxmox Web UI Upload

1. Log into Proxmox: `https://proxmox.hrmsmrflrii.xyz`
2. Select **node03** → **local** → **ISO Images**
3. Click **Upload** and select each ISO file
4. For VirtIO: Click **Download from URL** and use:
   `https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso`

---

## Step 3: Build Packer Templates

### Prerequisites

Ensure Packer is installed on the Ansible controller:

```bash
ssh hermes-admin@192.168.20.30

# Check Packer version
packer --version

# If not installed
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer
```

### Build Windows Server 2025 Template

```bash
cd ~/homelab-infra-automation-project/packer/windows-server-2025-proxmox

# Update variables.pkrvars.hcl with your credentials
nano variables.pkrvars.hcl

# Validate template
packer validate -var-file=variables.pkrvars.hcl windows-server-2025.pkr.hcl

# Build template
packer build -var-file=variables.pkrvars.hcl windows-server-2025.pkr.hcl
```

### Build Windows 11 Template

```bash
cd ~/homelab-infra-automation-project/packer/windows-11-proxmox

# Update variables.pkrvars.hcl with your credentials
nano variables.pkrvars.hcl

# Validate template
packer validate -var-file=variables.pkrvars.hcl windows-11.pkr.hcl

# Build template
packer build -var-file=variables.pkrvars.hcl windows-11.pkr.hcl
```

**Expected Build Time**: 45-60 minutes per template

---

## Step 4: Deploy VMs with Terraform

```bash
cd ~/homelab-infra-automation-project/terraform/hybrid-lab

# Update terraform.tfvars with credentials
nano terraform.tfvars

# Initialize Terraform
terraform init

# Preview deployment
terraform plan

# Deploy VMs
terraform apply
```

**Expected Deployment Time**: 15-20 minutes for all 10 VMs

---

## Step 5: Configure Active Directory

### Full Deployment (Recommended)

```bash
cd ~/homelab-infra-automation-project/ansible-playbooks/hybrid-lab

# Run full deployment
ansible-playbook -i inventory.yml site.yml
```

### Phased Deployment

```bash
# Phase 1: Domain Controllers
ansible-playbook -i inventory.yml install-ad-forest.yml
ansible-playbook -i inventory.yml promote-dc02.yml

# Phase 2: Domain Join
ansible-playbook -i inventory.yml domain-join.yml

# Phase 3: Server Configuration
ansible-playbook -i inventory.yml configure-file-servers.yml
ansible-playbook -i inventory.yml install-sql.yml

# Phase 4: Identity Services
ansible-playbook -i inventory.yml install-adconnect.yml
ansible-playbook -i inventory.yml install-password-protection.yml
```

---

## Post-Deployment Verification

### Test Domain Controllers

```powershell
# On DC01
Get-ADForest
Get-ADDomain
Get-ADDomainController -Filter *
repadmin /replsummary
```

### Test Domain Join

```powershell
# On any member server
(Get-WmiObject Win32_ComputerSystem).Domain
nltest /dsgetdc:hrmsmrflrii.xyz
```

### Test DNS

```bash
# From any server
nslookup dc01.hrmsmrflrii.xyz
nslookup dc02.hrmsmrflrii.xyz
```

### Test SQL Server

```powershell
# On SQL01
Invoke-Sqlcmd -Query "SELECT @@VERSION" -ServerInstance "localhost"
```

---

## Troubleshooting

### Packer Build Fails

```bash
# Enable debug logging
PACKER_LOG=1 packer build -var-file=variables.pkrvars.hcl windows-server-2025.pkr.hcl

# Common issues:
# - WinRM not starting: Check autounattend.xml FirstLogonCommands
# - ISO not found: Verify ISO path in variables.pkrvars.hcl
# - Network timeout: Ensure VLAN 80 is configured with Packer build IPs
```

### Terraform Apply Fails

```bash
# Check template exists
ssh root@192.168.20.22 "qm list | grep Template"

# Check storage availability
ssh root@192.168.20.22 "pvesm status"
```

### Ansible Domain Join Fails

```bash
# Verify DNS is pointing to DC
nslookup hrmsmrflrii.xyz 192.168.80.2

# Verify WinRM connectivity
ansible -i inventory.yml all -m win_ping

# Check firewall ports
Test-NetConnection -ComputerName dc01 -Port 389
```

---

## File Structure

```
homelab-infra-automation-project/
├── packer/
│   ├── windows-server-2025-proxmox/
│   │   ├── windows-server-2025.pkr.hcl
│   │   ├── autounattend.xml
│   │   ├── variables.pkrvars.hcl
│   │   └── scripts/
│   │       ├── setup-winrm.ps1
│   │       ├── install-virtio.ps1
│   │       └── enable-remoting.ps1
│   └── windows-11-proxmox/
│       ├── windows-11.pkr.hcl
│       ├── autounattend.xml
│       ├── variables.pkrvars.hcl
│       └── scripts/
│           ├── setup-winrm.ps1
│           ├── install-virtio.ps1
│           └── enable-remoting.ps1
├── terraform/
│   └── hybrid-lab/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
└── ansible-playbooks/
    └── hybrid-lab/
        ├── inventory.yml
        ├── site.yml
        ├── install-ad-forest.yml
        ├── promote-dc02.yml
        ├── domain-join.yml
        ├── configure-file-servers.yml
        ├── install-sql.yml
        ├── install-adconnect.yml
        └── install-password-protection.yml
```
