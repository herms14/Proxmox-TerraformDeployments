# Homelab Architecture Diagrams

This directory contains architecture diagrams for the homelab infrastructure.

## Generated Diagrams (PNG)

These diagrams are auto-generated using the Python `diagrams` library:

| Diagram | Description |
|---------|-------------|
| ![Infrastructure](homelab-infrastructure.png) | Complete infrastructure overview |
| ![Services](homelab-services.png) | Application services and their relationships |
| ![Network](homelab-network.png) | Network topology and VLAN architecture |

**Generator Script:** `scripts/generate-infrastructure-diagram.py`

**Requirements:**
- Python 3.x
- `diagrams` library (`pip install diagrams`)
- `graphviz` system package

**To regenerate:**
```bash
ssh ansible
cd ~/diagrams
python3 generate-infrastructure-diagram.py
```

---

## Mermaid Diagrams

The following Mermaid diagrams render in Obsidian, GitHub, and most Markdown viewers.

## Complete Infrastructure Overview

```mermaid
flowchart TB
    subgraph Internet["Internet"]
        WAN[Internet]
    end

    subgraph Network["Network Layer"]
        ISP["ISP Router<br/>192.168.100.1"]
        ER605["ER605 Gateway<br/>192.168.0.1"]

        subgraph Switches["Switches"]
            SG3210["SG3210 Core<br/>192.168.90.2"]
            SG2210P["SG2210P Morpheus<br/>192.168.90.3"]
        end

        OPNsense["OPNsense<br/>192.168.91.30"]
        Pihole["Pi-hole DNS<br/>192.168.90.53"]
    end

    subgraph Storage["Storage - Synology DS920+"]
        NAS["192.168.20.31<br/>34TB RAID"]
        VMDisks["VMDisks NFS"]
        Media["Media NFS"]
    end

    subgraph Proxmox["Proxmox Cluster"]
        subgraph Node01["node01 - 192.168.20.20"]
            N1["Primary Node<br/>Tailscale Subnet Router"]

            subgraph N1VMs["VMs on node01"]
                Ansible["Ansible<br/>192.168.20.30"]
                DockerMedia["docker-media<br/>192.168.40.11"]
                DockerUtils["docker-core-utils<br/>192.168.40.13"]
            end

            subgraph N1LXC["LXCs on node01"]
                LXC200["LXC 200 Glance<br/>192.168.40.12"]
                LXC201["LXC 201 Bots<br/>192.168.40.14"]
                LXC202["LXC 202 Pi-hole<br/>192.168.90.53"]
            end

            subgraph K8s["Kubernetes v1.28.15"]
                K8sCtrl["3x Controllers<br/>192.168.20.32-34"]
                K8sWork["6x Workers<br/>192.168.20.40-45"]
            end
        end

        subgraph Node02["node02 - 192.168.20.21"]
            N2["Secondary Node"]

            subgraph N2VMs["VMs on node02"]
                Traefik["Traefik<br/>192.168.40.20"]
                Authentik["Authentik<br/>192.168.40.21"]
                Immich["Immich<br/>192.168.40.22"]
                GitLab["GitLab<br/>192.168.40.23"]
                Runner["GitLab Runner<br/>192.168.40.24"]
            end
        end
    end

    WAN --> ISP --> ER605 --> SG3210 --> SG2210P
    SG3210 --> OPNsense
    SG2210P --> N1 & N2 & NAS
    NAS --> VMDisks & Media
    OPNsense -.-> Pihole
```

## Network Topology (VLANs)

```mermaid
flowchart LR
    subgraph Internet
        WAN((Internet))
    end

    subgraph Edge
        ISP[ISP Router]
        GW[ER605 Gateway]
    end

    subgraph VLANs["VLAN Architecture"]
        subgraph VLAN10["VLAN 10 - Internal<br/>192.168.10.0/24"]
            Workstations[Workstations]
            NAS10[Synology eth0]
        end

        subgraph VLAN20["VLAN 20 - Homelab<br/>192.168.20.0/24"]
            Proxmox[Proxmox Nodes]
            K8s[Kubernetes]
            NAS20[Synology eth1]
        end

        subgraph VLAN40["VLAN 40 - Services<br/>192.168.40.0/24"]
            Docker[Docker Hosts]
            Services[Applications]
        end

        subgraph VLAN90["VLAN 90 - Management<br/>192.168.90.0/24"]
            Switches[Network Switches]
            APs[Access Points]
            DNS[Pi-hole DNS]
        end

        subgraph VLAN91["VLAN 91 - Firewall<br/>192.168.91.0/24"]
            FW[OPNsense]
        end
    end

    WAN --> ISP --> GW
    GW --> VLAN10 & VLAN20 & VLAN40 & VLAN90 & VLAN91
```

## Services Architecture

```mermaid
flowchart TB
    Users((Users))

    subgraph Gateway["Gateway Layer"]
        Traefik["Traefik<br/>Reverse Proxy<br/>192.168.40.20"]
        Authentik["Authentik<br/>SSO/Auth<br/>192.168.40.21"]
    end

    subgraph MediaHost["docker-media - 192.168.40.11"]
        subgraph MediaStack["Media Stack"]
            Jellyfin[Jellyfin]
            Radarr[Radarr]
            Sonarr[Sonarr]
            Lidarr[Lidarr]
            Prowlarr[Prowlarr]
            Bazarr[Bazarr]
        end

        subgraph Requests["Request Management"]
            Overseerr[Overseerr]
            Jellyseerr[Jellyseerr]
        end

        subgraph Downloads["Downloads"]
            Deluge[Deluge]
            SABnzbd[SABnzbd]
            Tdarr[Tdarr]
            Autobrr[Autobrr]
        end

    end

    subgraph UtilsHost["docker-core-utils - 192.168.40.13"]
        subgraph Monitoring["Monitoring Stack"]
            Grafana[Grafana]
            Prometheus[Prometheus]
            UptimeKuma[Uptime Kuma]
            cAdvisor[cAdvisor]
        end

        subgraph Observability["Observability"]
            Jaeger[Jaeger Tracing]
            Speedtest[Speedtest]
        end

        subgraph Automation["Automation"]
            n8n[n8n Workflows]
            Sentinel[Sentinel Bot<br/>Unified Discord]
        end
    end

    subgraph LXC200["LXC 200 - 192.168.40.12"]
        Glance[Glance Dashboard]
        MediaAPI[Media Stats API]
        RedditMgr[Reddit Manager]
        NBAAPI[NBA Stats API]
        PiholeAPI[Pi-hole Stats API]
    end

    subgraph Node02Services["node02 Services"]
        Immich[Immich Photos<br/>192.168.40.22]
        GitLab[GitLab<br/>192.168.40.23]
        Runner[GitLab Runner<br/>192.168.40.24]
    end

    Users --> Traefik
    Traefik --> Authentik
    Traefik --> Jellyfin & Grafana & Glance & Immich & GitLab
    Prometheus --> Grafana
    GitLab --> Runner
```

## Storage Architecture

```mermaid
flowchart TB
    subgraph NAS["Synology DS920+ - 192.168.20.31"]
        Controller[NAS Controller]

        subgraph HDDs["Hard Drives (RAID)"]
            HDD1["8TB Seagate"]
            HDD2["4TB Seagate"]
            HDD3["12TB Seagate"]
            HDD4["10TB Seagate"]
        end

        subgraph SSDs["M.2 NVMe Cache"]
            SSD1["1TB Kingston"]
            SSD2["1TB Crucial"]
        end
    end

    subgraph NFSExports["NFS Exports"]
        subgraph ProxmoxManaged["Proxmox-Managed"]
            VMDisks["VMDisks<br/>/volume2/ProxmoxCluster-VMDisks"]
            ISOs["ISOs<br/>/volume2/ProxmoxCluster-ISOs"]
        end

        subgraph Manual["Manual Mounts"]
            Media["Media<br/>/volume2/Proxmox-Media"]
            LXCs["LXC Configs<br/>/volume2/Proxmox-LXCs"]
            Photos["Photos<br/>/volume2/ProxmoxData"]
        end
    end

    subgraph Consumers["Consumers"]
        Node01["node01"]
        Node02["node02"]
        DockerMedia["docker-media<br/>/mnt/media"]
        ImmichVM["Immich VM<br/>/mnt/appdata"]
    end

    Controller --> HDDs & SSDs
    Controller --> NFSExports
    VMDisks & ISOs --> Node01 & Node02
    Media --> DockerMedia
    Photos --> ImmichVM
```

## IP Address Map

```mermaid
flowchart LR
    subgraph VLAN20["VLAN 20 - Infrastructure<br/>192.168.20.0/24"]
        N1["node01: .20"]
        N2["node02: .21"]
        AN["Ansible: .30"]
        SN["Synology: .31"]
        KC["K8s Controllers: .32-.34"]
        KW["K8s Workers: .40-.45"]
    end

    subgraph VLAN40["VLAN 40 - Services<br/>192.168.40.0/24"]
        SL["Syslog: .5"]
        DM["docker-media: .11"]
        GL["Glance LXC: .12"]
        DU["docker-utils: .13<br/>(Sentinel Bot)"]
        TR["Traefik: .20"]
        AU["Authentik: .21"]
        IM["Immich: .22"]
        GI["GitLab: .23"]
        RU["Runner: .24"]
    end

    subgraph VLAN90["VLAN 90 - Management<br/>192.168.90.0/24"]
        CS["Core Switch: .2"]
        MS["Morpheus Switch: .3"]
        LR["Living Room AP: .10"]
        OD["Outdoor AP: .11"]
        CR["Computer Room AP: .12"]
        AS["Atreus Switch: .51"]
        PH["Pi-hole: .53"]
    end

    subgraph VLAN91["VLAN 91 - Firewall<br/>192.168.91.0/24"]
        OP["OPNsense: .30"]
    end
```

---

## Sentinel Bot Architecture

```mermaid
flowchart TB
    subgraph Discord["Discord Server"]
        CH1["#homelab-infrastructure"]
        CH2["#container-updates"]
        CH3["#media-downloads"]
        CH4["#project-management"]
        CH5["#claude-tasks"]
        CH6["#new-service-onboarding-workflow"]
    end

    subgraph SentinelBot["Sentinel Bot - 192.168.40.13:5050"]
        subgraph Core["Core Layer"]
            Bot["SentinelBot<br/>(discord.py 2.3+)"]
            DB["SQLite Database<br/>sentinel.db"]
            Router["Channel Router"]
        end

        subgraph Cogs["Cog Modules"]
            Homelab["homelab.py<br/>Proxmox Management"]
            Updates["updates.py<br/>Container Updates"]
            Media["media.py<br/>Download Tracking"]
            GitLabCog["gitlab.py<br/>Issue Management"]
            Tasks["tasks.py<br/>Claude Queue"]
            Onboarding["onboarding.py<br/>Service Verification"]
            Scheduler["scheduler.py<br/>Daily Reports"]
        end

        subgraph Webhooks["Webhook Server (Quart)"]
            WH["/webhook/watchtower"]
            JH["/webhook/jellyseerr"]
            API["/api/tasks"]
        end
    end

    subgraph External["External Services"]
        Proxmox["Proxmox Cluster<br/>192.168.20.20-21"]
        Prometheus["Prometheus<br/>192.168.40.13:9090"]
        Radarr["Radarr<br/>192.168.40.11:7878"]
        Sonarr["Sonarr<br/>192.168.40.11:8989"]
        Jellyseerr["Jellyseerr<br/>192.168.40.11:5056"]
        GitLab["GitLab<br/>192.168.40.23"]
        Watchtower["Watchtower<br/>(All Docker Hosts)"]
    end

    %% Discord connections
    CH1 --> Homelab
    CH2 --> Updates
    CH3 --> Media
    CH4 --> GitLabCog
    CH5 --> Tasks
    CH6 --> Onboarding

    %% Cog to external
    Homelab --> Proxmox & Prometheus
    Updates --> Watchtower
    Media --> Radarr & Sonarr & Jellyseerr
    GitLabCog --> GitLab

    %% Webhooks
    Watchtower --> WH
    Jellyseerr --> JH

    %% Core connections
    Bot --> Router --> Cogs
    Cogs --> DB
```

### Sentinel Bot Data Flow

```mermaid
sequenceDiagram
    participant User
    participant Discord
    participant Sentinel
    participant External as External Service
    participant DB as SQLite

    %% Command Flow
    User->>Discord: /command
    Discord->>Sentinel: Slash Command
    Sentinel->>External: API Call
    External-->>Sentinel: Response
    Sentinel->>DB: Log/Track
    Sentinel-->>Discord: Embed Response
    Discord-->>User: Display Result

    %% Webhook Flow
    Note over External,Sentinel: Webhook Notification
    External->>Sentinel: POST /webhook/*
    Sentinel->>DB: Record Event
    Sentinel->>Discord: Send Notification
    Discord-->>User: Display Alert
```

---

## How to Generate PNG Diagrams

### Using Python `diagrams` library:

```bash
# Install dependencies
pip install diagrams

# Run the generator script
cd tf-proxmox/scripts
python generate-homelab-diagrams.py
```

### Using Mermaid CLI:

```bash
# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Convert this file to PNG
mmdc -i HOMELAB_ARCHITECTURE.md -o homelab_architecture.png
```

### Online Rendering:

- **GitHub**: Mermaid diagrams render automatically
- **Obsidian**: Install Mermaid plugin for live preview
- **mermaid.live**: Paste diagram code for web-based editing
