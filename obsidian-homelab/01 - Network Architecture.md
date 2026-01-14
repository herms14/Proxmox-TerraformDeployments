# Network Architecture

> **Internal Documentation** - Contains credentials and sensitive information.

Related: [[00 - Homelab Index]] | [[11 - Credentials]] | [[10 - IP Address Map]]

---

## Physical Network Topology

```
                                    Internet
                                        │
                                        ▼
                              ┌─────────────────┐
                              │   ISP Router    │
                              │  192.168.100.1  │
                              │   (Converge)    │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │   Core Router   │
                              │   ER605 v2.20   │
                              │   192.168.0.1   │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │  Atreus Switch  │
                              │  ES20GP v1.0    │
                              │  192.168.90.51  │
                              │ (First Floor)   │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │   Core Switch   │
                              │  SG3210 v3.20   │
                              │  192.168.90.2   │
                              └────────┬────────┘
                                       │
          ┌────────────┬───────────────┼───────────────┬────────────┐
          │            │               │               │            │
          ▼            ▼               ▼               ▼            ▼
    ┌──────────┐ ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────┐
    │ Morpheus │ │  Pi-hole │  │ Synology │  │  Wireless │  │  Other   │
    │  Switch  │ │   DNS    │  │   NAS    │  │    APs    │  │ Devices  │
    │ SG2210P  │ │  .90.53  │  │  .20.31  │  │ EAP225/   │  │          │
    │  .90.3   │ │          │  │          │  │ EAP610    │  │          │
    └────┬─────┘ └──────────┘  └──────────┘  └───────────┘  └──────────┘
         │
    ┌────┼────┬────┐
    │    │    │    │
    ▼    ▼    ▼    ▼
  Node01 Node02 NAS  EAP
  (.20) (.21) (.31) (.12)
```

**Physical Path**: ER605 Gateway → Atreus Switch → Core Switch (SG3210) → Morpheus Switch → Proxmox Nodes

---

## Network Hardware

| Device | Model | IP Address | MAC Address | Purpose |
|--------|-------|------------|-------------|---------|
| Core Router | ER605 v2.20 | 192.168.0.1 | 8C-90-2D-4B-D9-6C | Main gateway |
| Core Switch | SG3210 v3.20 | 192.168.90.2 | 40-AE-30-B7-96-74 | Primary L2 switch |
| Morpheus Switch | SG2210P v5.20 | 192.168.90.3 | DC-62-79-2A-0D-66 | Proxmox connectivity |
| Atreus Switch | ES20GP v1.0 | 192.168.90.51 | A8-29-48-96-C7-12 | First floor |
| Computer Room EAP | EAP225 v4.0 | 192.168.90.12 | 0C-EF-15-50-39-52 | WiFi AP |
| Living Room EAP | EAP610 v3.0 | 192.168.90.10 | 3C-64-CF-37-96-EC | WiFi AP |
| Outdoor EAP | EAP603-Outdoor v1.0 | 192.168.90.11 | 78-20-51-C1-EA-A6 | Outdoor WiFi |

---

## Network Controller Credentials

### Omada Cloud Controller
- **Username**: `hermes-admin`
- **Password**: `cK67hBQ4by#eTB3BhAH`

### Device Passwords (Routers/EAPs)
- **Username**: `hermes-admin`
- **Password (old)**: `Zaq12wsxcde34rfv!!!0m@d@`
- **Password (new)**: `o8kS&Dd9R0`

### ISP Gateway (Converge)
- **URL**: http://192.168.100.1/
- **Model**: EG8245H5
- **Username**: `telcoadmin`
- **Password**: `Converge@huawei123`

---

## Complete VLAN Configuration

| VLAN ID | Name | Network | Gateway | Purpose | DHCP Range |
|---------|------|---------|---------|---------|------------|
| 1 | Default | 192.168.0.0/24 | 192.168.0.1 | Management (temporary) | .100-.199 |
| 10 | Internal | 192.168.10.0/24 | 192.168.10.1 | Main LAN | .50-.254 |
| **20** | **Homelab** | **192.168.20.0/24** | **192.168.20.1** | **Proxmox/VMs** | .50-.254 |
| 30 | IoT | 192.168.30.0/24 | 192.168.30.1 | IoT devices | .50-.254 |
| **40** | **Production** | **192.168.40.0/24** | **192.168.40.1** | **Docker/Apps** | .50-.254 |
| 50 | Guest | 192.168.50.0/24 | 192.168.50.1 | Guest WiFi | .50-.254 |
| 60 | Sonos | 192.168.60.0/24 | 192.168.60.1 | Sonos speakers | .50-.100 |
| 90 | Management | 192.168.90.0/24 | 192.168.90.1 | Network devices, Pi-hole DNS | .50-.254 |

---

## Switch Port Configurations

### Core Switch (SG3210)

| Port | Device | Mode | Native VLAN | Tagged VLANs |
|------|--------|------|-------------|--------------|
| 1 | OC300 Controller | Trunk | VLAN 1 | All VLANs |
| 2 | OPNsense Port | Access | VLAN 90 | - |
| 5 | Zephyrus Port | Access | VLAN 10 | - |
| 6 | Morpheus Rack Uplink | Trunk | VLAN 1 | 10,20,30,40,50,90 |
| 7 | Kratos PC | Trunk | VLAN 10 | 20 (Hyper-V) |
| 8 | Atreus Switch Uplink | Trunk | VLAN 1 | All VLANs |

### Morpheus Switch (SG2210P)

| Port | Device | Mode | Native VLAN | Tagged VLANs |
|------|--------|------|-------------|--------------|
| 1 | Core Switch Uplink | Trunk | VLAN 1 | All |
| 2 | **Proxmox Node 01** | Trunk | VLAN 20 | 10, 40 |
| 5 | Computer Room EAP | Trunk | VLAN 1 | All SSIDs |
| 6 | **Proxmox Node 02** | Trunk | VLAN 20 | 10, 40 |
| 7 | Synology NAS (eth0) | Access | VLAN 10 | - |
| 8 | Synology NAS (eth1) | Access | VLAN 20 | - |

### Atreus Switch (ES20GP)

| Port | Device | Mode | Native VLAN | Tagged VLANs |
|------|--------|------|-------------|--------------|
| 1 | First Floor EAP | Trunk | VLAN 1 | All SSIDs |
| 5 | Core Router | Trunk | VLAN 1 | All |
| 6 | Core Switch | Trunk | VLAN 1 | All |

---

## WiFi SSID Configuration

| SSID | VLAN | Security Key |
|------|------|--------------|
| NKD5380-Internal | 10 | `Zaq12wsxcde34rfv!!!Internal` |
| NHN7476-Homelab | 20 | `Zaq12wsxcde34rfv!!!HomeLab` |
| WOC321-IoT | 30 | `Zaq12wsxcde34rfv!!!IOT` |
| NAZ9229-Production | 40 | `Zaq12wsxcde34rfv!!!Production` |
| EAD6167-Guest | 50 | `Zaq12wsxcde34rfv!!!Guest` |
| NAZ9229-Sonos | 60 | `Zaq12wsxcde34rfv!!!Sonos` |
| NCP5653-Management | 90 | `Zaq12wsxcde34rfv!!!Management` |

### Backup SSIDs
| SSID | Security Key |
|------|--------------|
| ARA2802 | `Zaq12wsxcde34rfv!!!Backup` |
| NIR7714-MLO-Backup | `Zaq12wsxcde34rfv!!!Backup` |

---

## Domain & SSL Configuration

- **Domain**: `hrmsmrflrii.xyz`
- **Registrar**: GoDaddy
- **Nameservers**: Cloudflare
- **SSL**: Let's Encrypt wildcard via Cloudflare DNS-01
- **Reverse Proxy**: [[09 - Traefik Reverse Proxy]]
- **Internal DNS**: Pi-hole (192.168.90.53)

---

## Observability Endpoints

Internal endpoints for monitoring and tracing (See [[18 - Observability Stack]]):

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Traefik Metrics | 192.168.40.20:8082/metrics | Prometheus scrape target |
| OTEL Collector (gRPC) | 192.168.40.13:4317 | OTLP trace receiver |
| OTEL Collector (HTTP) | 192.168.40.13:4318 | OTLP trace receiver |
| OTEL Collector Metrics | 192.168.40.13:8888/metrics | Collector internal metrics |
| OTEL Pipeline Metrics | 192.168.40.13:8889/metrics | Pipeline exporter metrics |
| Jaeger | 192.168.40.13:16686 | Trace visualization UI |
| Jaeger Metrics | 192.168.40.13:14269/metrics | Jaeger internal metrics |

---

## Remote Access (Tailscale)

Tailscale provides secure remote access to the homelab from outside the local network using WireGuard encryption. node01 is configured as a **subnet router** to enable access to all VMs and containers.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Tailscale Network                            │
│                                                                      │
│   ┌──────────────┐         ┌──────────────┐         ┌─────────────┐ │
│   │   MacBook    │◄───────►│   node01     │◄───────►│   node02    │ │
│   │ 100.90.207.58│  WireGuard│ 100.89.33.5 │         │100.96.195.27│ │
│   └──────────────┘         │ SUBNET ROUTER│         └─────────────┘ │
│                            └──────┬───────┘                         │
│                                   │                                  │
└───────────────────────────────────┼──────────────────────────────────┘
                                    │ Advertises Routes
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
            ┌───────────┐   ┌───────────┐   ┌───────────┐
            │192.168.20 │   │192.168.40 │   │192.168.90 │
            │  /24      │   │  /24      │   │  /24      │
            │ Infra     │   │ Services  │   │ Mgmt/DNS  │
            └───────────┘   └───────────┘   └───────────┘
```

### Tailscale IP Mapping

| Device | Local IP | Tailscale IP | Role |
|--------|----------|--------------|------|
| node01 | 192.168.20.20 | 100.89.33.5 | **Subnet Router** |
| node02 | 192.168.20.21 | 100.96.195.27 | Peer |
| Synology NAS | 192.168.20.31 | 100.84.128.43 | Peer (inactive) |
| MacBook Pro | - | 100.90.207.58 | Client |

### Subnet Router Configuration

node01 advertises local networks to the Tailscale network:

| Network | Purpose | Example Hosts |
|---------|---------|---------------|
| 192.168.20.0/24 | Infrastructure VLAN | Proxmox nodes, Ansible, K8s |
| 192.168.40.0/24 | Services VLAN | Docker hosts, applications |
| 192.168.90.0/24 | Management VLAN | Network devices, Pi-hole DNS (192.168.90.53) |

**node01 Configuration:**
```bash
# IP forwarding (persisted in /etc/sysctl.d/99-tailscale.conf)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Tailscale subnet router command
tailscale up --advertise-routes=192.168.20.0/24,192.168.40.0/24,192.168.90.0/24 --accept-routes
```

### Split DNS Configuration

DNS queries for `*.hrmsmrflrii.xyz` routed to Pi-hole:

| Setting | Value |
|---------|-------|
| Nameserver | 192.168.90.53 (Pi-hole) |
| Restricted to domain | hrmsmrflrii.xyz |
| Override local DNS | Enabled |

Configured in **Tailscale Admin Console → DNS tab**.

### Client Configuration

**macOS:**
```bash
# CLI path (not in PATH by default)
/Applications/Tailscale.app/Contents/MacOS/Tailscale

# Accept subnet routes
/Applications/Tailscale.app/Contents/MacOS/Tailscale up --accept-routes

# Optional: Add alias to ~/.zshrc
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
```

**Linux/Windows:**
```bash
tailscale up --accept-routes
```

### What Works Remotely

| Access Type | Method | Example |
|-------------|--------|---------|
| SSH to any VM/container | Local IP via subnet router | `ssh 192.168.40.13` |
| Web services | Domain name via split DNS | `https://grafana.hrmsmrflrii.xyz` |
| Proxmox Web UI | Tailscale IP or local IP | `https://192.168.20.20:8006` |
| Direct container access | Local IP + port | `http://192.168.40.13:3030` |

### Remote Access Commands

```bash
# SSH via local IPs (through subnet router)
ssh hermes-admin@192.168.20.30    # Ansible controller
ssh hermes-admin@192.168.40.13    # Docker utilities

# SSH via Tailscale IPs (direct)
ssh root@100.89.33.5              # node01
ssh root@100.96.195.27            # node02

# Access services via domain (with split DNS)
curl https://grafana.hrmsmrflrii.xyz
curl https://glance.hrmsmrflrii.xyz
```

### Troubleshooting

```bash
# Verify routes are accepted
tailscale status

# Test connectivity to subnets
ping 192.168.20.1    # VLAN 20 gateway
ping 192.168.40.1    # VLAN 40 gateway
ping 192.168.90.53   # Pi-hole DNS

# Test DNS resolution
nslookup grafana.hrmsmrflrii.xyz 192.168.90.53

# Check Tailscale DNS status (macOS)
/Applications/Tailscale.app/Contents/MacOS/Tailscale dns status

# Restart Tailscale (macOS)
sudo killall Tailscale tailscaled
open -a Tailscale
```

### Security Features

| Feature | Benefit |
|---------|---------|
| WireGuard encryption | All traffic encrypted end-to-end |
| No port forwarding | No inbound ports exposed to internet |
| Device authentication | Only authorized devices can join |
| ACL control | Access controlled via Tailscale admin |
| Split DNS | DNS queries stay within encrypted tunnel |

> [!tip] Service URLs vs Tailscale
> With the subnet router configured, both service URLs (`*.hrmsmrflrii.xyz`) and local IPs work from anywhere via Tailscale.

---

## Network Maintenance

### Omada Backup
- **FTP Path**: `/OmadaConfigBackup`
- **FTP Username**: `omada-log-admin`
- **FTP Password**: `Vm8WRjgeg!&J3klc`

### DNS Server (Pi-hole)
- **IP**: 192.168.90.53
- **Admin UI**: http://192.168.90.53/admin
- **Local DNS**: Configure in Local DNS → DNS Records

---

## Related Documentation

- [[10 - IP Address Map]] - Complete IP allocation
- [[11 - Credentials]] - All access credentials
- [[02 - Proxmox Cluster]] - Node configurations
- [[09 - Traefik Reverse Proxy]] - SSL and routing
- [[18 - Observability Stack]] - OTEL and Jaeger tracing
- [[17 - Monitoring Stack]] - Prometheus and Grafana
