# Deployment Runbook - Azure Hybrid Lab

Complete deployment guide for the Azure Hybrid Lab infrastructure on Proxmox VE.

## Overview

This runbook guides you through deploying a hybrid Active Directory environment with:
- **12 On-premises Windows VMs** on Proxmox (VLAN 80)
- **Azure Infrastructure** with VPN connectivity
- **Entra ID Integration** with hybrid identity

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AZURE HYBRID LAB                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ON-PREMISES (Proxmox Cluster)                    AZURE                         │
│  ┌─────────────────────────────────┐              ┌──────────────────────────┐  │
│  │  VLAN 80: 192.168.80.0/24       │              │  VNet: 10.0.0.0/16       │  │
│  │                                  │              │                          │  │
│  │  DC01, DC02 (Domain Controllers)│    VPN      │  AZDC01, AZDC02          │  │
│  │  FS01, FS02 (File Servers)      │ ◄────────► │  AZRODC01, AZRODC02      │  │
│  │  SQL01 (SQL Server)             │   IPsec    │  AKS Cluster             │  │
│  │  AADCON01 (Entra Connect)       │              │                          │  │
│  │  AADPP01/02 (Password Proxy)    │              └──────────────────────────┘  │
│  │  IIS01/02 (Web Servers)         │                                            │
│  │  CLIENT01/02 (Workstations)     │                                            │
│  └─────────────────────────────────┘                                            │
│                                                                                  │
│  Proxmox Nodes: node01, node02, node03                                          │
│  Template: 9022 (Windows Server 2022)                                           │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites Checklist

- [ ] Proxmox VE cluster operational (MorpheusCluster)
- [ ] ISOs uploaded: Windows Server 2022, VirtIO drivers
- [ ] VLAN 80 configured on network switch
- [ ] Ansible Controller (192.168.20.30) accessible
- [ ] SSH key configured for Proxmox access
- [ ] Azure CLI authenticated (`az login`)

---

## Phase 1: Packer Template Build

### Step 1.1: Prepare Ansible Controller

```bash
# SSH to Ansible Controller
ssh hermes-admin@192.168.20.30

# Create project directory
mkdir -p ~/azure-hybrid-lab
cd ~/azure-hybrid-lab

# Copy/sync files from your local machine
# (Use SCP, rsync, or git clone)
```

### Step 1.2: Install Packer

```bash
# Install HashiCorp repository
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer

# Verify installation
packer version
```

### Step 1.3: Configure Packer Variables

```bash
cd ~/azure-hybrid-lab/packer/windows-server-2022-proxmox
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
nano variables.pkrvars.hcl
```

Configure these settings:
```hcl
proxmox_api_url          = "https://192.168.20.22:8006/api2/json"
proxmox_api_token_id     = "terraform-deployment-user@pve!tf"
proxmox_api_token_secret = "your-api-token-secret"
proxmox_node             = "node03"
ws2022_iso_file          = "ws2022.iso"
virtio_iso_file          = "virtio-win.iso"
admin_password           = "your-admin-password"
vlan_tag                 = 80
```

### Step 1.4: Build the Template

```bash
cd ~/azure-hybrid-lab/packer/windows-server-2022-proxmox

# Initialize plugins
packer init .

# Validate configuration
packer validate -var-file="variables.pkrvars.hcl" .

# Build template (takes ~7 minutes)
packer build -var-file="variables.pkrvars.hcl" .
```

**Expected Output:**
```
Build 'windows-server-2022.proxmox-iso.ws2022' finished after 6 minutes 48 seconds.
==> Builds finished. The artifacts of successful builds are:
--> windows-server-2022.proxmox-iso.ws2022: A template was created: 9022
```

### Step 1.5: Verify Template

```bash
ssh root@192.168.20.22 "qm list | grep 9022"
```

Expected: `9022 WS2022-Template stopped`

---

## Phase 2: VM Deployment with Terraform

### Step 2.1: Configure Terraform

```bash
cd ~/azure-hybrid-lab/terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Configure:
```hcl
proxmox_api_url      = "https://192.168.20.22:8006"
proxmox_api_token    = "terraform-deployment-user@pve!tf=your-token-secret"
ssh_private_key_path = "~/.ssh/homelab_ed25519"
use_template         = true
vm_template_id       = 9022
admin_password       = "your-admin-password"
```

### Step 2.2: Deploy VMs

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Deploy 12 VMs (takes ~30 minutes)
terraform apply -auto-approve
```

### Step 2.3: Verify Deployment

```bash
# List all VMs
ssh root@192.168.20.22 "qm list | grep -E '30[0-9]|31[01]'"

# Check VM is responding via guest agent
ssh root@192.168.20.22 "qm guest exec 300 -- ipconfig"

# Check WinRM service status
ssh root@192.168.20.22 "qm guest exec 300 -- powershell -Command 'Get-Service WinRM'"
```

---

## Phase 3: Network Configuration

### Step 3.1: Update Ansible Inventory

Edit `ansible/inventory/hosts.yml` with current DHCP IPs (temporary):

```bash
# Get current IPs from QEMU guest agent
for vmid in 300 301 302 303 304 305 306 307 308 309 310 311; do
  echo "VM $vmid:"
  ssh root@192.168.20.22 "qm guest exec $vmid -- ipconfig 2>/dev/null | grep IPv4"
done
```

### Step 3.2: Configure Static IPs via Ansible

```bash
cd ~/azure-hybrid-lab/ansible

# Create vault file with passwords
ansible-vault create group_vars/vault.yml
```

Add to vault.yml:
```yaml
vault_windows_password: "your-admin-password"
vault_domain_admin_password: "your-domain-admin-password"
vault_safe_mode_password: "your-safe-mode-password"
```

```bash
# Run network configuration playbook
ansible-playbook playbooks/configure-network.yml --ask-vault-pass
```

### Step 3.3: Verify Static IPs

```bash
# Ping test each VM
for ip in 2 3 4 5 6 7 8 9 10 11 12 13; do
  ping -c 1 192.168.80.$ip
done
```

---

## Phase 4: Active Directory Setup

### Step 4.1: Install AD Forest on DC01

```bash
ansible-playbook playbooks/install-ad-forest.yml --ask-vault-pass
```

Wait ~10 minutes for DC01 to reboot and AD to be operational.

### Step 4.2: Verify DC01

```bash
ansible DC01 -m win_shell -a "Get-ADDomain" --ask-vault-pass
```

### Step 4.3: Promote DC02

```bash
ansible-playbook playbooks/promote-dc02.yml --ask-vault-pass
```

### Step 4.4: Join Member Servers

```bash
ansible-playbook playbooks/domain-join.yml --ask-vault-pass
```

### Step 4.5: Verify AD

```bash
# List all domain controllers
ansible DC01 -m win_shell -a "Get-ADDomainController -Filter *" --ask-vault-pass

# Check replication
ansible DC01 -m win_shell -a "repadmin /replsummary" --ask-vault-pass
```

---

## Phase 5: Azure Infrastructure

### Step 5.1: Configure Azure Terraform

```bash
cd ~/azure-hybrid-lab/terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Configure:
```hcl
admin_password = "your-azure-vm-password"
vpn_psk        = "your-vpn-preshared-key"
```

### Step 5.2: Deploy Azure Infrastructure

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan  # Takes ~30-45 minutes for VPN Gateway
```

### Step 5.3: Note VPN Gateway IP

```bash
terraform output vpn_gateway_public_ip
```

---

## Phase 6: VPN Configuration

### Step 6.1: Configure Omada Router

See [docs/VPN_CONFIGURATION.md](docs/VPN_CONFIGURATION.md) for detailed steps.

Key settings:
- **Remote Gateway**: Azure VPN Gateway public IP
- **Pre-Shared Key**: Same as Terraform `vpn_psk`
- **Remote Subnets**: 10.0.0.0/16
- **Local Networks**: 192.168.80.0/24

### Step 6.2: Verify VPN Tunnel

From on-premises DC01:
```powershell
# Test connectivity to Azure
Test-NetConnection -ComputerName 10.0.2.4 -Port 3389
ping 10.0.2.4
```

---

## Phase 7: Azure Domain Controllers

### Step 7.1: Promote Azure DCs

```bash
ansible-playbook playbooks/promote-azure-dcs.yml --ask-vault-pass
```

### Step 7.2: Verify Hybrid AD

```bash
# List all DCs (on-prem and Azure)
ansible DC01 -m win_shell -a "Get-ADDomainController -Filter * | Select Name, IPv4Address, Site" --ask-vault-pass

# Check replication
ansible DC01 -m win_shell -a "repadmin /showrepl" --ask-vault-pass
```

---

## Verification Commands

### On-Premises VMs

```bash
# Ping all VMs
ansible all_vms -m win_ping --ask-vault-pass

# Check domain membership
ansible member_servers -m win_shell -a "(Get-WmiObject Win32_ComputerSystem).Domain" --ask-vault-pass

# Check DNS resolution
ansible all_vms -m win_shell -a "nslookup azurelab.local" --ask-vault-pass
```

### Azure VMs

```bash
# Ping Azure VMs
ansible azure_dcs -m win_ping --ask-vault-pass

# Verify AD replication
ansible AZDC01 -m win_shell -a "repadmin /showrepl" --ask-vault-pass
```

---

## Resource Summary

### On-Premises (VLAN 80 - Proxmox)

| VM | VMID | IP | Role | Cores | RAM |
|----|------|-----|------|-------|-----|
| DC01 | 300 | 192.168.80.2 | Primary DC | 2 | 4 GB |
| DC02 | 301 | 192.168.80.3 | Secondary DC | 2 | 4 GB |
| FS01 | 302 | 192.168.80.4 | File Server | 2 | 2 GB |
| FS02 | 303 | 192.168.80.5 | File Server | 2 | 2 GB |
| SQL01 | 304 | 192.168.80.6 | SQL Server | 4 | 8 GB |
| AADCON01 | 305 | 192.168.80.7 | Entra Connect | 2 | 4 GB |
| AADPP01 | 306 | 192.168.80.8 | Password Protection | 2 | 2 GB |
| AADPP02 | 307 | 192.168.80.9 | Password Protection | 2 | 2 GB |
| IIS01 | 310 | 192.168.80.10 | Web Server | 2 | 2 GB |
| IIS02 | 311 | 192.168.80.11 | Web Server | 2 | 2 GB |
| CLIENT01 | 308 | 192.168.80.12 | Workstation | 2 | 2 GB |
| CLIENT02 | 309 | 192.168.80.13 | Workstation | 2 | 2 GB |

### Azure

| Resource | IP/Config | Purpose |
|----------|-----------|---------|
| AZDC01 | 10.0.2.4 | Azure Primary DC |
| AZDC02 | 10.0.2.5 | Azure Secondary DC |
| AZRODC01 | 10.0.2.6 | Azure RODC |
| AZRODC02 | 10.0.2.7 | Azure RODC |
| VPN Gateway | Dynamic | Site-to-Site VPN |
| AKS | 10.1.0.0/22 | Kubernetes Cluster |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Packer WinRM timeout | Check VM has IP 192.168.80.99, verify VLAN 80 config |
| Template clone fails | Remove partial VM: `qm destroy <vmid> --purge` |
| VM no network | Verify VLAN 80 tagged on switch port |
| WinRM connection fails | Check firewall, verify WinRM enabled on VM |
| DNS resolution fails | Verify DNS servers point to DCs |
| VPN tunnel down | Check pre-shared key, IKE/IPsec settings |
| AD replication fails | Check sites/subnets config, VPN connectivity |

---

## Clean Up

### Destroy On-Premises VMs

```bash
cd ~/azure-hybrid-lab/terraform/proxmox
terraform destroy
```

### Destroy Azure Resources

```bash
cd ~/azure-hybrid-lab/terraform
terraform destroy
```

### Remove Template

```bash
ssh root@192.168.20.22 "qm destroy 9022 --purge"
```

---

## Related Documentation

- [Packer Template Details](packer/windows-server-2022-proxmox/README.md)
- [Terraform Proxmox Deployment](terraform/proxmox/README.md)
- [IP Addressing Scheme](docs/IP_ADDRESSING.md)
- [VPN Configuration](docs/VPN_CONFIGURATION.md)
- [Architecture Overview](docs/ARCHITECTURE.md)
