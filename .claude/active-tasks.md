# Active Tasks

> Check this file BEFORE starting any work to avoid conflicts with other sessions.
> Update this file IMMEDIATELY when starting or completing work.

---

## Currently In Progress

### Azure Sentinel Homelab Integration (Active)
**Task**: Full Sentinel integration for homelab learning
**Status**: 🔄 IN PROGRESS
**Started**: 2026-01-15

**Scope:**
- Deploy Windows DCRs for Azure Domain Controllers
- Configure syslog forwarding from Proxmox/Docker/OPNsense
- Enable Azure VNet diagnostic logging
- Create simulation scenarios for learning
- Update learning documentation

**Progress:**
- [x] Deploy Windows DCR Terraform (terraform/azure/sentinel-learning/)
- [ ] Install AMA on Azure DCs (scripts/install-ama-azure-vms.sh) - **BLOCKED: VPN down**
- [x] Configure Proxmox syslog forwarding (all 3 nodes)
- [x] Configure Docker hosts syslog (LXCs: 200, 201, 205; VM: 107)
- [ ] Configure OPNsense logging - **REQUIRES MANUAL WEB UI CONFIG**
- [x] Enable VNet NSG flow logs (vnet-diagnostics.tf)
- [x] Add Sentinel analytics rules (analytics-rules-syslog.tf)
- [x] Create simulation scenarios (04 - Attack Simulation Scenarios.md)
- [x] Update learning documentation (05 - Deployment Runbook.md)
- [x] Configure DNS forwarders on DC01/DC02 (via QEMU guest agent)
- [x] Verify internet connectivity on all on-prem Windows VMs

**Syslog Forwarding Status:**
| Host | Type | Status | Config |
|------|------|--------|--------|
| node01 | Proxmox | ✅ Configured | /etc/rsyslog.d/50-sentinel-forward.conf |
| node02 | Proxmox | ✅ Configured | /etc/rsyslog.d/50-sentinel-forward.conf |
| node03 | Proxmox | ✅ Configured | /etc/rsyslog.d/50-sentinel-forward.conf |
| docker-lxc-media (205) | LXC | ✅ Configured | /etc/rsyslog.d/50-sentinel-forward.conf |
| docker-lxc-glance (200) | LXC | ✅ Configured | /etc/rsyslog.d/50-sentinel-forward.conf |
| docker-lxc-bots (201) | LXC | ✅ Configured | /etc/rsyslog.d/50-sentinel-forward.conf |
| docker-vm-core-utilities01 (107) | VM | ✅ Configured | /etc/rsyslog.d/50-sentinel-forward.conf |

**Files Created:**
- `terraform/azure/sentinel-learning/vnet-diagnostics.tf`
- `terraform/azure/sentinel-learning/analytics-rules-syslog.tf`
- `ansible/playbooks/azure-sentinel/configure-syslog-forwarding.yml`
- `ansible/playbooks/azure-sentinel/configure-dns-forwarders.yml`
- `ansible/playbooks/azure-sentinel/check-onprem-windows-internet.yml`
- `ansible/playbooks/azure-sentinel/fix-onprem-windows-internet.yml`
- `ansible/playbooks/azure-sentinel/inventory.yml`
- `ansible/playbooks/azure-sentinel/inventory-onprem-windows.yml`
- `scripts/check-windows-vm-internet.ps1`
- `scripts/install-ama-azure-vms.sh`

**Remaining Manual Steps:**

### 1. Configure OPNsense Syslog (Web UI Required)
1. Login to OPNsense: https://192.168.91.30
2. Navigate to: **System → Settings → Logging / Targets**
3. Add Remote Target:
   - Enabled: Yes
   - Transport: UDP(4)
   - Applications: filterlog, ipsec, openvpn
   - Levels: Warning and above
   - Hostname: 192.168.40.5
   - Port: 514
   - Facility: Local4
4. Save and Apply

### 2. Deploy Terraform to Azure (VPN must be UP)
```bash
ssh ubuntu-deploy
cd /opt/terraform/sentinel-learning
terraform init && terraform plan && terraform apply
```

### 3. Install AMA on Azure DCs (VPN must be UP)
```bash
./scripts/install-ama-azure-vms.sh
```

---

### Instance A (Previous Session) - COMPLETED
**Task**: Documentation Update - Technical Manual & Book
**Status**: ✅ DONE
- Updated Technical Manual to v5.8 (Azure Hybrid Lab section ~600 lines)
- Updated Book Chapter 25 with Packer/Terraform narrative

### Instance B (Previous Session) - COMPLETED
**Task 1: VM IP Discovery** ✅ DONE
**Task 2: Static IP Configuration** ✅ DONE

| VM | VMID | Static IP | Status |
|----|------|-----------|--------|
| DC01 | 300 | 192.168.80.2 | ✅ Configured |
| DC02 | 301 | 192.168.80.3 | ✅ Configured |
| FS01 | 302 | 192.168.80.4 | ✅ Configured |
| FS02 | 303 | 192.168.80.5 | ✅ Configured |
| SQL01 | 304 | 192.168.80.6 | ✅ Configured |
| AADCON01 | 305 | 192.168.80.7 | ✅ Configured |
| AADPP01 | 306 | 192.168.80.8 | ✅ Configured |
| AADPP02 | 307 | 192.168.80.9 | ✅ Configured |
| IIS01 | 310 | 192.168.80.10 | ✅ Configured |
| IIS02 | 311 | 192.168.80.11 | ✅ Configured |
| CLIENT01 | 308 | 192.168.80.12 | ✅ Configured |
| CLIENT02 | 309 | 192.168.80.13 | ✅ Configured |

**Network Config**: Gateway 192.168.80.1, DNS 192.168.90.53 (Pi-hole)

**Task 3: Windows 11 Template Status** ⚠️
- VM 9011 is **running** but QEMU guest agent NOT responding
- Likely stuck in Windows OOBE or installation
- Uses BIOS (not UEFI) - may need rebuild with WS2022 fixes
- **Action needed**: Check via VNC console, may need manual intervention or rebuild

---

## Recently Completed

### Azure Hybrid Lab - Full Deployment Complete
**Completed**: 2026-01-14
**Status**: ✅ SUCCESS

**What was accomplished:**

1. **Packer Template Build** (Template 9022)
   - Rebuilt Windows Server 2022 template on node03
   - Build time: ~7 minutes
   - Fixed WinRM connection issues by making `enable-remoting.ps1` idempotent
   - Fixed Windows Defender deleting Packer scripts
   - Added `sysprep-unattend.xml` for fully automated OOBE skip on cloned VMs

2. **Terraform VM Deployment** (12 VMs)
   - All 12 VMs successfully deployed to node03
   - Total deployment time: ~30 minutes
   - VMs boot directly to desktop without manual intervention
   - QEMU Guest Agent operational on all VMs
   - WinRM service running and ready for Ansible

**Deployed VMs:**

| VM | VMID | IP (DHCP) | Role | Status |
|----|------|-----------|------|--------|
| DC01 | 300 | 192.168.80.x | Primary Domain Controller | Running |
| DC02 | 301 | 192.168.80.x | Secondary Domain Controller | Running |
| FS01 | 302 | 192.168.80.x | File Server | Running |
| FS02 | 303 | 192.168.80.x | File Server | Running |
| SQL01 | 304 | 192.168.80.x | SQL Server | Running |
| AADCON01 | 305 | 192.168.80.x | Entra ID Connect | Running |
| AADPP01 | 306 | 192.168.80.x | Password Protection Proxy | Running |
| AADPP02 | 307 | 192.168.80.x | Password Protection Proxy | Running |
| CLIENT01 | 308 | 192.168.80.x | Domain Workstation | Running |
| CLIENT02 | 309 | 192.168.80.x | Domain Workstation | Running |
| IIS01 | 310 | 192.168.80.x | Web Server | Running |
| IIS02 | 311 | 192.168.80.x | Web Server | Running |

**Documentation Updated:**
- `packer/windows-server-2022-proxmox/README.md` - Comprehensive Packer documentation
- `terraform/proxmox/README.md` - Terraform deployment guide
- `DEPLOYMENT_RUNBOOK.md` - Updated for Proxmox deployment

**Key Technical Fixes Applied:**

1. **WinRM Connection Drops** - `enable-remoting.ps1` now checks if remoting is already enabled before calling `Enable-PSRemoting` (which restarts WinRM)

2. **Script File Deletion** - Added Windows Defender exclusion in `autounattend.xml`:
   ```xml
   <CommandLine>Set-MpPreference -DisableRealtimeMonitoring $true; Add-MpPreference -ExclusionPath 'C:\Windows\Temp'</CommandLine>
   ```

3. **Boot Order** - Fixed UEFI boot menu issue with `boot = "order=ide2"`

4. **Post-Sysprep OOBE** - `sysprep-unattend.xml` copied before sysprep, enables WinRM and auto-logon on cloned VMs

---

## Next Steps (For Future Sessions)

### Phase 3: Network Configuration
```bash
# Get current DHCP IPs
for vmid in 300 301 302 303 304 305 306 307 308 309 310 311; do
  ssh root@192.168.20.22 "qm guest exec $vmid -- ipconfig 2>/dev/null | grep IPv4"
done

# Configure static IPs via Ansible
cd ~/azure-hybrid-lab/ansible
ansible-playbook playbooks/configure-network.yml --ask-vault-pass
```

### Phase 4: Active Directory Setup
```bash
ansible-playbook playbooks/install-ad-forest.yml --ask-vault-pass  # DC01
# Wait 10 minutes
ansible-playbook playbooks/promote-dc02.yml --ask-vault-pass
ansible-playbook playbooks/domain-join.yml --ask-vault-pass
```

### Phase 5: Azure Infrastructure
```bash
cd ~/azure-hybrid-lab/terraform
terraform apply  # Deploy Azure VPN Gateway, DCs
```

---

## Interrupted Tasks (Need Resumption)

### Windows 11 Packer Template Build
**Status**: Unknown (may have timed out)
**VM ID**: 9011 on node03

Check status:
```bash
ssh root@192.168.20.22 "qm list | grep 9011"
```

If needed, can apply same fixes as WS2022 template.

### Node03 NVIDIA RTX 3050 GPU Monitoring
**Blocked**: 2026-01-11
**Reason**: NVIDIA driver 550.163 doesn't support kernel 6.17.4-2-pve

**What's needed:**
- Wait for NVIDIA driver update that supports kernel 6.17+
- Check periodically: `apt update && apt upgrade nvidia-driver`

---

## Infrastructure Notes

- **Proxmox Cluster**: MorpheusCluster (node01, node02, node03) + Qdevice
- **Template Location**: node03 (VM ID 9022)
- **VLAN 80**: 192.168.80.0/24 - Azure Hybrid Lab network
- **Ansible Controller**: 192.168.20.30 (hermes-admin)

### Credentials

| Purpose | Username | Password |
|---------|----------|----------|
| Windows VMs | Administrator | c@llimachus14 |
| Domain Admin | AZURELAB\Administrator | c@llimachus14 |
| Proxmox API | terraform-deployment-user@pve!tf | (see terraform.tfvars) |

---

- Multiple Claude instances may run in parallel - always check active-tasks first
- Glance pages are protected - don't modify without permission
