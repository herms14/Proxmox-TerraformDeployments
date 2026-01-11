# Proxmox Cluster Configuration

> Part of the [Proxmox Infrastructure Documentation](../CLAUDE.md)

## Cluster Nodes

**Cluster**: MorpheusCluster (3-node + Qdevice)

| Node | IP Address | Purpose | Workload Type |
|------|------------|---------|---------------|
| **node01** | 192.168.20.20 | Primary VM Host | K8s cluster, LXCs, Core Services |
| **node02** | 192.168.20.21 | Service Host | Traefik, Authentik, GitLab, Immich |
| **node03** | 192.168.20.22 | Desktop Node (Ryzen 9) | GitLab, Immich, Syslog Server |

### Node03 Hardware

| Component | Details |
|-----------|---------|
| CPU | AMD Ryzen 9 5900XT 16-Core |
| Storage | 1TB Kingston NVMe (PBS daily), 1TB Lexar NVMe (unused), 1TB Samsung SSD (boot), 4TB Seagate HDD (PBS main) |
| Type | Desktop PC (converted to server) |
| Special Role | Hosts Proxmox Backup Server (PBS) LXC |

### Proxmox Backup Server (PBS)

PBS is deployed as an LXC container on node03, providing enterprise-grade backups with deduplication.

| Setting | Value |
|---------|-------|
| VMID | 100 |
| Hostname | pbs-server |
| IP | 192.168.20.50 |
| Web UI | https://192.168.20.50:8007 |

**Datastores:**

| Datastore | Storage | Size | Purpose |
|-----------|---------|------|---------|
| `main` | Seagate 4TB HDD | 3.4TB | Weekly/monthly archival backups |
| `daily` | Kingston 1TB NVMe | 870GB | Daily backups (fast restore) |

**Proxmox VE Storage IDs:**
- `pbs-main` - HDD datastore for archival
- `pbs-daily` - SSD datastore for daily backups

See [PBS Deployment Guide](./PBS_DEPLOYMENT.md) for full configuration details.

## Wake-on-LAN

All nodes have Wake-on-LAN enabled and configured to persist across reboots.

| Node | MAC Address | Interface |
|------|-------------|-----------|
| node01 | `38:05:25:32:82:76` | nic0 |
| node02 | `84:47:09:4d:7a:ca` | nic0 |
| node03 | `TBD` | nic0 |

### Wake Nodes Remotely

```bash
# From MacBook (Python, no dependencies)
python3 scripts/wake-nodes.py          # Wake both nodes
python3 scripts/wake-nodes.py node01   # Wake node01 only
python3 scripts/wake-nodes.py node02   # Wake node02 only

# Using wakeonlan tool
brew install wakeonlan                 # macOS
wakeonlan 38:05:25:32:82:76           # node01
wakeonlan 84:47:09:4d:7a:ca           # node02
```

### Configuration Details

WoL is enabled via `/etc/network/interfaces` on each node:
```
iface nic0 inet manual
    post-up ethtool -s nic0 wol g
```

**BIOS Requirement**: Ensure WoL is enabled in each node's BIOS/UEFI:
- Look for: Power Management → Wake on LAN → Enabled
- May also be called "Resume on LAN" or "Power On by PCIe"

## Adding a New Node to the Cluster

When adding a new Proxmox node (e.g., node03), follow this checklist to ensure all systems are updated.

### Checklist Overview

| System | Auto-Updates? | Action Required |
|--------|---------------|-----------------|
| Proxmox Cluster | Manual | Join node to cluster |
| Prometheus/PVE Exporter | Manual | Add target (if separate exporter) |
| Grafana Dashboards | ✓ Auto | None - uses dynamic queries |
| Glance Monitor Widget | Manual | Add node to `glance.yml` |
| Wake-on-LAN | Manual | Enable WoL, add to script |
| DNS (OPNsense) | Manual | Add DNS record |
| Tailscale | Manual | Install and authenticate |
| Documentation | Manual | Update all docs |

### Step 1: Join Node to Proxmox Cluster

On the **new node**:
```bash
# Get join command from existing node
ssh root@192.168.20.20 "pvecm add <new_node_ip>"

# Or from new node, join existing cluster
pvecm add 192.168.20.20
```

Verify cluster status:
```bash
pvecm status
# Should show all nodes with "Quorate: Yes"
```

### Step 2: Update Prometheus Monitoring

If using a centralized PVE exporter, add the new node to `/opt/monitoring/prometheus/prometheus.yml`:

```yaml
- job_name: 'proxmox'
  static_configs:
    - targets:
      - 192.168.20.20:9221  # node01
      - 192.168.20.21:9221  # node02
```

Restart Prometheus:
```bash
ssh hermes-admin@192.168.40.13 "cd /opt/monitoring && sudo docker compose restart prometheus"
```

**Note**: Grafana dashboards auto-discover new nodes via regex queries like `pve_up{id=~"node/.*"}`.

### Step 3: Update Glance Dashboard

Edit `/opt/glance/config/glance.yml` on the Glance LXC (192.168.40.12):

```yaml
    - type: monitor
      title: Proxmox Cluster
      cache: 1m
      sites:
      - title: Node 01
        url: https://192.168.20.20:8006
        icon: si:proxmox
        allow-insecure: true
      - title: Node 02
        url: https://192.168.20.21:8006
        icon: si:proxmox
        allow-insecure: true
```

Restart Glance:
```bash
ssh hermes-admin@192.168.40.12 "cd /opt/glance && sudo docker compose restart"
```

### Step 4: Enable Wake-on-LAN

On the **new node**:
```bash
# Enable WoL
ethtool -s nic0 wol g

# Make persistent - add to /etc/network/interfaces under "iface nic0":
#     post-up ethtool -s nic0 wol g

# Get MAC address
ip link show nic0 | grep ether
```

Update `scripts/wake-nodes.py` with the new MAC address.

**BIOS**: Ensure WoL is enabled in BIOS (Power Management → Wake on LAN).

### Step 5: Configure DNS

Add DNS record in OPNsense (192.168.91.30):
- **Services → Unbound DNS → Host Overrides**
- Add: `<hostname>.hrmsmrflrii.xyz` → `<node_ip>`

### Step 6: Install Tailscale (Optional)

For remote access via Tailscale:
```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate
tailscale up

# Note the Tailscale IP for documentation
tailscale ip -4
```

### Step 7: Update Documentation

Update these files with the new node:
- `.claude/context.md` - Add to cluster table
- `CLAUDE.md` - Update Infrastructure Overview
- `docs/PROXMOX.md` - Add to Cluster Nodes table
- `docs/NETWORKING.md` - Add to IP allocations and Tailscale mapping
- `docs/INVENTORY.md` - Update node count
- `scripts/wake-nodes.py` - Add MAC address
- Obsidian vault - Update `02 - Proxmox Cluster.md`
- GitHub Wiki - Update `Proxmox-Cluster.md`

### Step 8: Verify Everything

```bash
# Check cluster status
ssh root@192.168.20.20 "pvecm status"

# Check Prometheus targets
curl -s http://192.168.40.13:9090/api/v1/targets | jq '.data.activeTargets[] | select(.job=="proxmox") | .labels.instance'

# Check Grafana shows new node
# Visit: https://grafana.hrmsmrflrii.xyz/d/proxmox-compute

# Test WoL (after shutting down node)
python3 scripts/wake-nodes.py <nodename>
```

## Proxmox Version

- **Version**: Proxmox VE 9.1.2
- **Terraform Provider**: telmate/proxmox v3.0.2-rc06 (RC for PVE 9.x compatibility)

## API Access

- **API URL**: https://192.168.20.21:8006/api2/json
- **Authentication**: API Token (`terraform-deployment-user@pve!tf`)
- **TLS**: Self-signed certificate (insecure mode enabled for Terraform)

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

### SSH Key

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAby7br+5MzyDus2fi2UFjUBZvGucN40Gxa29bgUTbfz hermes@homelab
```

### Standard VM Features

| Feature | Configuration |
|---------|---------------|
| Cloud-init | Enabled for automated provisioning |
| QEMU Guest Agent | Enabled |
| Auto-start | On Boot enabled |
| CPU Type | host (maximum performance) |
| SCSI Controller | virtio-scsi-single |
| Network Model | virtio |
| BIOS | UEFI (ovmf) |
| Machine | q35 |

### Templates

| Template | OS | Boot Mode | Used For |
|----------|-----|-----------|----------|
| `tpl-ubuntuv24.04-v1` | Ubuntu 24.04 | UEFI | Ansible controller |
| `tpl-ubuntu-shared-v1` | Ubuntu | UEFI | All other VMs |

## LXC Configuration Standards

### Container Types

| Type | Security | Use Case |
|------|----------|----------|
| **Unprivileged** (default) | More secure | Most services |
| **Privileged** | Less secure | Docker with nesting |

### Standard Features

| Feature | Configuration |
|---------|---------------|
| Nesting | Only for Docker hosts |
| Auto-start | Enabled for production |
| SSH Keys | Pre-configured |

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

## UEFI Boot Configuration

All VMs use UEFI boot mode. Template must match:

```hcl
# modules/linux-vm/main.tf
bios    = "ovmf"
machine = "q35"

efidisk {
  storage           = var.storage
  efitype           = "4m"
  pre_enrolled_keys = true
}

scsihw = "virtio-scsi-single"
```

**Key Lesson**: Always verify template boot mode with `qm config <vmid>` before deploying.

## Node03 Power Management

Node03 is a desktop PC (Ryzen 9 5900XT) configured with power-saving optimizations to reduce idle power consumption from ~100-150W to ~40-60W.

### Applied Configurations

| Setting | Value | Effect |
|---------|-------|--------|
| CPU Governor | `powersave` | Reduces clock speed at idle |
| AMD P-State | `amd-pstate-epp` | Modern AMD power management |
| Max C-State | `9` | Enables deep sleep states |
| SATA Policy | `med_power_with_dipm` | SATA link power management |
| PCIe ASPM | `powersave` | PCIe Active State Power Management |
| HDD Spindown | 20 minutes | Spins down 4TB HDD after idle |

### GRUB Configuration

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_pstate=active processor.max_cstate=9"
```

### Systemd Services

| Service | Purpose | Runs At |
|---------|---------|---------|
| `power-save.service` | Applies CPU governor, SATA, PCIe settings | Boot |
| `powertop.service` | Auto-tunes additional power settings | Boot |

### Power-Save Script

Located at `/usr/local/bin/power-save.sh`:
- Sets CPU governor to powersave
- Enables SATA link power management
- Configures PCIe ASPM
- Sets NVMe power tolerance
- Enables audio codec power save

### Verify Current Settings

```bash
# Check CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Check scaling driver
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver

# Check services
systemctl status power-save powertop

# Monitor power impact
powertop
```

### BIOS Settings (Recommended)

For maximum power savings, ensure these are enabled in BIOS:
- Cool'n'Quiet: Enabled
- Global C-State Control: Enabled
- Power Supply Idle Control: Low Current Idle
- CPPC: Enabled
- CPPC Preferred Cores: Enabled

## Node Exporter (Hardware Metrics)

All Proxmox nodes have node_exporter v1.7.0 installed for hardware metrics collection, including CPU temperature monitoring.

### Installation Details

| Component | Value |
|-----------|-------|
| Version | 1.7.0 |
| Port | 9100 |
| Binary | `/usr/local/bin/node_exporter` |
| Service | `node_exporter.service` |

### Collectors Enabled

| Collector | Purpose |
|-----------|---------|
| `hwmon` | Hardware sensors (CPU temp, fan speed) |
| `thermal_zone` | Thermal zone temperatures |
| `cpu` | CPU utilization |
| `meminfo` | Memory statistics |
| `filesystem` | Disk usage |
| `loadavg` | System load |
| `netdev` | Network interface stats |

### Service Configuration

Located at `/etc/systemd/system/node_exporter.service`:

```ini
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter --collector.hwmon --collector.thermal_zone --collector.cpu --collector.meminfo --collector.filesystem --collector.loadavg --collector.netdev
Restart=always

[Install]
WantedBy=multi-user.target
```

### Prometheus Scrape Config

Added to `/opt/monitoring/prometheus/prometheus.yml` on docker-vm-core-utilities01:

```yaml
- job_name: 'proxmox-nodes'
  static_configs:
    - targets:
      - 192.168.20.20:9100
      labels:
        node: 'node01'
    - targets:
      - 192.168.20.21:9100
      labels:
        node: 'node02'
    - targets:
      - 192.168.20.22:9100
      labels:
        node: 'node03'
```

### Verify Node Exporter

```bash
# Check service status
systemctl status node_exporter

# Test metrics endpoint
curl http://localhost:9100/metrics | head -50

# Check temperature metrics
curl -s http://localhost:9100/metrics | grep -E "(hwmon|thermal)"
```

## Cluster Health Dashboard

A Grafana dashboard provides comprehensive cluster health monitoring with temperature tracking.

### Dashboard Details

| Setting | Value |
|---------|-------|
| Dashboard UID | `proxmox-cluster-health` |
| Title | Proxmox Cluster Health |
| Location | `/opt/monitoring/grafana/dashboards/proxmox-cluster-health.json` |
| Glance Integration | Compute tab (iframe) |

### Dashboard Panels

| Panel | Description |
|-------|-------------|
| Cluster Quorum | Shows quorum status (Yes/No) |
| Nodes Online | Count of online cluster nodes |
| Total VMs | Running and stopped VM count |
| Total Containers | Running and stopped LXC count |
| CPU Temperature (per node) | Real-time temperature gauges |
| Temperature History | 24-hour temperature chart |
| NVMe Temperature | NVMe drive temperatures |
| GPU Temperature | GPU temperatures (if present) |
| Top VMs by CPU | Highest CPU consuming VMs |
| Top VMs by Memory | Highest memory consuming VMs |
| VM Status Timeline | Historical VM state changes |
| Storage Pool Usage | Disk usage per storage pool |

### Access Dashboard

| Method | URL |
|--------|-----|
| Grafana Direct | https://grafana.hrmsmrflrii.xyz/d/proxmox-cluster-health |
| Glance Embedded | https://glance.hrmsmrflrii.xyz → Compute tab |
| Kiosk Mode | http://192.168.40.13:3030/d/proxmox-cluster-health?kiosk&theme=transparent |

## Useful Commands

### Check Node Status

```bash
# Cluster status
pvecm status

# Node resources
pvesh get /cluster/resources --type node

# Corosync membership
corosync-cmapctl runtime.votequorum.quorate
```

### Template Management

```bash
# List VM templates
qm list | grep template

# Check template config
qm config <vmid>

# Clone from template
qm clone <template_vmid> <new_vmid> --name <hostname>
```

### Node Health

```bash
# Service status
systemctl status pve-cluster corosync

# Cluster logs
journalctl -u corosync -n 50

# Restart cluster services (if needed)
systemctl restart pve-cluster && systemctl restart corosync
```

## Related Documentation

- [Storage](./STORAGE.md) - Storage configuration
- [Networking](./NETWORKING.md) - Network configuration
- [Terraform](./TERRAFORM.md) - Deployment automation
- [Inventory](./INVENTORY.md) - Deployed VMs and containers
- [Troubleshooting](./TROUBLESHOOTING.md) - Common issues
