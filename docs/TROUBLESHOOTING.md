# Troubleshooting Guide

> Part of the [Proxmox Infrastructure Documentation](../CLAUDE.md)

## Resolved Issues

### Corosync SIGSEGV Crash (Node03)

**Resolved**: December 2025

**Symptoms**:
- `corosync.service` fails to start with `status=11/SEGV`
- Logs stop at: `Initializing transport (Kronosnet)`
- Node cannot join cluster
- Reinstalling corosync alone doesn't fix it

**Root Cause**: Broken or mismatched NSS crypto stack (`libnss3`) caused Corosync to segfault during encrypted cluster transport initialization.

**Why It Happened**:
- Corosync uses kronosnet (knet) for cluster networking
- knet loads a crypto plugin (`crypto_nss`)
- The plugin relies on NSS crypto libraries (`libnss3`)
- Corrupted or mismatched library versions caused the crash

**Diagnosis**:

```bash
# 1. Validate configuration (should pass)
corosync -t

# 2. Install debug tools
apt install systemd-coredump gdb strace

# 3. After crash, analyze core dump
coredumpctl info corosync
```

**Stack trace showed failure in**: `PK11_CipherOp` -> `libnss3.so` -> `crypto_nss.so` -> `libknet.so`

**Resolution**:

Reinstall the entire crypto and transport dependency chain:

```bash
apt install --reinstall -y \
  libnss3 libnss3-tools \
  libknet1t64 libnozzle1t64 \
  corosync libcorosync-common4
```

**Verification**:

```bash
# Start corosync
systemctl start corosync

# Check status
systemctl status corosync

# Verify crypto plugin loaded
journalctl -u corosync | grep crypto_nss

# Check cluster
pvecm status
```

**Expected Output**:
- `crypto_nss.so has been loaded successfully`
- Quorate: Yes
- All nodes visible

**Prevention**:
- Keep all nodes package-consistent: `apt update && apt full-upgrade -y`
- Avoid partial upgrades (crypto libraries are version-sensitive)
- If corosync crashes again, check core dump first

---

### Cloud-init VM Boot Failure - UEFI/BIOS Mismatch

**Resolved**: December 15, 2025

**Symptoms**:
- VM creates successfully via Terraform
- Console stops at: `Btrfs loaded, zoned=yes, fsverity=yes`
- Boot hangs before cloud-init
- VM unreachable via SSH/ping
- Shows "running" but stuck during boot

**Root Cause**: UEFI/BIOS boot mode mismatch between template and Terraform config.

**Template** (tpl-ubuntuv24.04-v1):
- BIOS: `ovmf` (UEFI)
- EFI Disk: Present
- Machine: `q35`
- SCSI: `virtio-scsi-single`

**Terraform** (before fix):
- BIOS: `seabios` (Legacy)
- SCSI: `lsi`

**Resolution**: Updated `modules/linux-vm/main.tf`:

```hcl
bios    = "ovmf"
machine = "q35"

efidisk {
  storage           = var.storage
  efitype           = "4m"
  pre_enrolled_keys = true
}

scsihw = "virtio-scsi-single"
```

**Lesson**: Always verify template boot mode with `qm config <vmid>` before deploying.

---

### Node Showing Question Mark / Unhealthy Status

**Resolved**: December 16, 2025

**Symptoms**:
- Question mark icon in Proxmox web UI
- "NR" (Not Ready) status in cluster membership

**Diagnosis**:

```bash
# Check connectivity
ping 192.168.20.22

# Check SSH access
ssh root@192.168.20.22 "uptime"

# Check cluster status
ssh root@192.168.20.22 "pvecm status"
ssh root@192.168.20.21 "pvecm status"

# Check cluster resources
ssh root@192.168.20.22 "pvesh get /cluster/resources --type node"
```

**What to Look For**:
- "System is going down" = active shutdown
- "NR" in membership vs "A,NV,NMW" for healthy nodes
- Node status should show "online"

**Resolution**:

1. If shutdown in progress: `shutdown -c` (may fail if too late)
2. If shutdown completed: Power on via physical access, IPMI, or WoL
3. Verify cluster rejoin:
   ```bash
   ssh root@192.168.20.22 "pvecm status"
   ssh root@192.168.20.22 "systemctl status corosync pve-cluster"
   ```
4. If "NR" persists:
   ```bash
   ssh root@192.168.20.22 "systemctl restart pve-cluster && systemctl restart corosync"
   ```

**Verification**:
```bash
# All nodes should show "online"
ssh root@192.168.20.22 "pvesh get /cluster/resources --type node"

# Should show "Quorate: Yes"
ssh root@192.168.20.22 "pvecm status"

# Should show "Members[3]: 1 2 3"
ssh root@192.168.20.22 "journalctl -u corosync -n 50 | grep -E 'Members|quorum'"
```

---

## Common Issues

### Connection Refused Errors

**Symptom**: `dial tcp 192.168.20.21:8006: connectex: No connection could be made`

**Cause**: Proxmox API temporarily unavailable during heavy operations

**Solution**: Wait and retry, or check Proxmox node status:
```bash
ssh root@192.168.20.21 "systemctl status pveproxy"
```

---

### Template Not Found (LXC)

**Symptom**: `template 'local:vztmpl/...' does not exist`

**Solution**: Download template on target node:
```bash
ssh root@<node> "pveam update && pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
```

---

### Tainted Resources

**Symptom**: Resources marked as tainted, requiring replacement

**Solution**: Run `terraform apply` to recreate properly

---

### State Lock

**Symptom**: Terraform state is locked

**Solution**:
1. Ensure no other terraform operations running
2. Force unlock if needed (caution):
   ```bash
   terraform force-unlock <lock-id>
   ```

---

### VLAN-Aware Bridge Missing

**Symptom**: `QEMU exited with code 1` on VM deployment

**Cause**: Node missing VLAN-aware bridge configuration

**Solution**: Configure `/etc/network/interfaces`:
```bash
auto vmbr0
iface vmbr0 inet static
    address 192.168.20.XX/24
    gateway 192.168.20.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

Then reload:
```bash
ifreload -a
# or reboot
```

Verify:
```bash
ip -d link show vmbr0 | grep vlan_filtering
# Should show "vlan_filtering 1"
```

---

### NFS Mount Failures

**Symptom**: Mount fails or is stale

**Diagnosis**:
```bash
# Check NFS exports from NAS
showmount -e 192.168.20.31

# Check current mounts
df -h | grep nfs

# Test mount manually
mount -t nfs 192.168.20.31:/volume2/ProxmoxCluster-VMDisks /mnt/test
```

**Common Fixes**:
- Ensure NFS service running on NAS
- Check firewall rules (NFS ports 111, 2049)
- Verify export permissions include Proxmox node IPs
- For stale mounts: `umount -l /mnt/stale && mount -a`

---

## Diagnostic Commands

### Terraform

```bash
# Check state
terraform state list

# Show specific resource
terraform state show module.vms["k8s-controlplane01"].proxmox_vm_qemu.linux_vm

# Refresh state
terraform refresh

# Validate configuration
terraform validate

# Format files
terraform fmt
```

### Proxmox

```bash
# Cluster status
pvecm status

# Node resources
pvesh get /cluster/resources --type node

# VM config
qm config <vmid>

# LXC config
pct config <ctid>

# Service status
systemctl status pve-cluster corosync pveproxy

# Corosync logs
journalctl -xeu corosync

# Core dump analysis
coredumpctl info corosync
```

### Ansible

```bash
# Test connectivity
ansible all -m ping

# Check specific host
ansible docker-vm-media01 -m setup
```

### Network

```bash
# Check VLAN filtering
ip -d link show vmbr0 | grep vlan_filtering

# Check bridge ports
bridge link show

# Check routes
ip route show
```

## Related Documentation

- [Proxmox](./PROXMOX.md) - Cluster configuration
- [Networking](./NETWORKING.md) - Network configuration
- [Terraform](./TERRAFORM.md) - Deployment configuration
- [legacy/TROUBLESHOOTING.md](./legacy/TROUBLESHOOTING.md) - Extended troubleshooting
