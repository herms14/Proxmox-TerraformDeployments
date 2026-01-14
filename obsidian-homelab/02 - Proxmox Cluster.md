# Proxmox Cluster

> **Internal Documentation** - Contains API tokens and access credentials.

Related: [[00 - Homelab Index]] | [[11 - Credentials]] | [[05 - Terraform Configuration]]

---

## Cluster Nodes

**Cluster**: MorpheusCluster (3-node + Qdevice)

| Node | IP Address | Tailscale IP | Purpose |
|------|------------|--------------|---------|
| **node01** | 192.168.20.20 | 100.89.33.5 | Primary VM Host (K8s, LXCs, Core Services) |
| **node02** | 192.168.20.21 | 100.96.195.27 | Service Host (Traefik, Authentik) |
| **node03** | 192.168.20.22 | 100.88.228.34 | Desktop Node - Ryzen 9 5900XT (GitLab, Immich, Syslog) |

---

## Node03 Power Management

Node03 is a desktop PC with power-saving optimizations applied:

| Setting | Value | Effect |
|---------|-------|--------|
| CPU Governor | `powersave` | Reduces clock speed at idle |
| AMD P-State | `amd-pstate-epp` | Modern AMD power management |
| Max C-State | `9` | Enables deep sleep states |
| SATA Policy | `med_power_with_dipm` | SATA link power management |
| HDD Spindown | 20 minutes | Spins down 4TB HDD after idle |

**Expected idle power**: ~40-60W (down from ~100-150W)

**Systemd Services**:
- `power-save.service` - Applies CPU governor, SATA, PCIe settings at boot
- `powertop.service` - Runs powertop auto-tune at boot

**GRUB Configuration**:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_pstate=active processor.max_cstate=9"
```

**Verify Settings**:
```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor  # powersave
systemctl status power-save powertop
```

---

## Proxmox Version

- **Version**: Proxmox VE 9.1.2
- **Terraform Provider**: telmate/proxmox v3.0.2-rc06

---

## API Access

| Field | Value |
|-------|-------|
| API URL | `https://192.168.20.21:8006/api2/json` |
| Token ID | `terraform-deployment-user@pve!tf` |
| Token Secret | *(stored in terraform.tfvars)* |
| TLS Mode | Self-signed (insecure mode) |

### SSH Access

| Field | Value |
|-------|-------|
| User | `hermes-admin` (VMs), `root` (nodes) |
| Auth | SSH Key (ed25519) |
| Primary Key | `~/.ssh/homelab_ed25519` (no passphrase) |
| Public Key | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINVYlOowJQE4tC4GEo17MptDGdaQfWwMDMRxLdKd/yui hermes@homelab-nopass` |

See [[16 - SSH Configuration]] for detailed SSH setup and host aliases.

---

## VM Configuration Standards

### Default Specifications

| Setting | Value |
|---------|-------|
| CPU | 1 socket, 4 cores |
| Memory | 8GB (8192 MB) |
| Disk | 20GB |
| Storage | VMDisks (NFS) |
| Cloud-init User | hermes-admin |
| SSH Auth | Key only (password disabled) |

### Standard VM Features

| Feature | Configuration |
|---------|---------------|
| Cloud-init | Enabled |
| QEMU Guest Agent | Enabled |
| Auto-start | On Boot enabled |
| CPU Type | host |
| SCSI Controller | virtio-scsi-single |
| Network Model | virtio |
| BIOS | UEFI (ovmf) |
| Machine | q35 |

### Templates

| Template | OS | Boot Mode | Used For |
|----------|-----|-----------|----------|
| `tpl-ubuntuv24.04-v1` | Ubuntu 24.04 | UEFI | Ansible controller |
| `tpl-ubuntu-shared-v1` | Ubuntu | UEFI | All other VMs |

---

## LXC Configuration Standards

### Container Types

| Type | Security | Use Case |
|------|----------|----------|
| **Unprivileged** (default) | More secure | Most services |
| **Privileged** | Less secure | Docker with nesting |

### LXC Templates

Download templates on Proxmox nodes:

```bash
# Update template list
pveam update

# List available templates
pveam available

# Download Ubuntu 22.04 LXC template
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Download Debian 12 LXC template
pveam download local debian-12-standard_12.2-1_amd64.tar.zst
```

Templates stored in: `/var/lib/vz/template/cache/`

---

## Resource Sizing Guidelines

### Kubernetes Nodes

| Role | Cores | RAM | Notes |
|------|-------|-----|-------|
| Control Plane | 2 | 4GB | Minimum recommended |
| Worker Nodes | 4 | 8GB | Adjust based on workload |

### Docker Hosts

| Workload | Cores | RAM | Notes |
|----------|-------|-----|-------|
| Media Services | 4 | 8GB | For transcoding |
| General Services | 2-4 | 4-8GB | Standard services |

### LXC Containers

| Service Type | Cores | RAM |
|--------------|-------|-----|
| Reverse Proxy | 1-2 | 1GB |
| Web Servers | 1 | 512MB |
| Docker in LXC | 2-4 | 2-4GB |

---

## Node Exporter (Hardware Metrics)

All Proxmox nodes have node_exporter v1.7.0 installed for hardware metrics collection including CPU temperature.

| Node | Endpoint | Collectors |
|------|----------|------------|
| node01 | 192.168.20.20:9100 | hwmon, thermal_zone, cpu, meminfo |
| node02 | 192.168.20.21:9100 | hwmon, thermal_zone, cpu, meminfo |
| node03 | 192.168.20.22:9100 | hwmon, thermal_zone, cpu, meminfo |

**Service**: `/etc/systemd/system/node_exporter.service`
**Binary**: `/usr/local/bin/node_exporter`
**Prometheus Job**: `proxmox-nodes`

### Verify Node Exporter

```bash
# Check service status
systemctl status node_exporter

# Test metrics endpoint
curl http://localhost:9100/metrics | head -50

# Check temperature metrics
curl -s http://localhost:9100/metrics | grep -E "(hwmon|thermal)"
```

---

## Cluster Health Dashboard

A Grafana dashboard provides comprehensive cluster health monitoring with temperature tracking.

**Dashboard UID**: `proxmox-cluster-health`
**Location**: `/opt/monitoring/grafana/dashboards/proxmox-cluster-health.json`

| Panel | Description |
|-------|-------------|
| Cluster Status | Quorum, Nodes Online, VMs, Containers |
| CPU Temperature | Per-node gauges with color thresholds |
| Temperature History | 24-hour line chart for all nodes |
| Drive Temperatures | NVMe and GPU temperatures |
| Resource Usage | Top VMs by CPU, Top VMs by Memory |
| Storage | Pool usage bar gauges |

**Temperature Thresholds**: Green (<60°C), Yellow (60-80°C), Red (>80°C)

**Access**:
- Grafana: https://grafana.hrmsmrflrii.xyz/d/proxmox-cluster-health
- Glance: https://glance.hrmsmrflrii.xyz → Compute tab

---

## Management Commands

```bash
# SSH to nodes
ssh root@192.168.20.20  # node01
ssh root@192.168.20.21  # node02

# Cluster status
pvecm status

# Node resources
pvesh get /cluster/resources --type node

# VM config
qm config <vmid>

# Service status
systemctl status pve-cluster corosync pveproxy
```

---

## Related Documentation

- [[03 - Storage Architecture]] - Storage configuration
- [[01 - Network Architecture]] - Network configuration
- [[16 - SSH Configuration]] - SSH keys and access
- [[05 - Terraform Configuration]] - Deployment automation
- [[07 - Deployed Services]] - Deployed VMs and containers
- [[12 - Troubleshooting]] - Common issues

