#!/usr/bin/env python3
"""
Homelab Infrastructure Diagram Generator

Generates beautiful infrastructure diagrams using the diagrams library.
Install: pip install diagrams

Usage:
    python generate-homelab-diagrams.py

Output:
    - homelab_complete.png - Full infrastructure overview
    - homelab_network.png - Network topology
    - homelab_services.png - Services and containers
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.compute import Server
from diagrams.onprem.container import Docker
from diagrams.onprem.network import Internet, Nginx
from diagrams.onprem.database import PostgreSQL
from diagrams.onprem.monitoring import Grafana, Prometheus
from diagrams.onprem.security import Vault
from diagrams.onprem.client import User
from diagrams.generic.network import Switch, Router, Firewall
from diagrams.generic.storage import Storage
from diagrams.generic.compute import Rack
from diagrams.generic.os import Ubuntu, LinuxGeneral
from diagrams.generic.blank import Blank

# Custom node attributes
graph_attr = {
    "fontsize": "20",
    "bgcolor": "white",
    "splines": "spline",
    "nodesep": "0.8",
    "ranksep": "1.2",
    "pad": "0.5"
}

node_attr = {
    "fontsize": "11",
}

edge_attr = {
    "fontsize": "10",
}


def create_complete_diagram():
    """Create the complete infrastructure overview diagram."""

    with Diagram(
        "Homelab Infrastructure - MorpheusCluster",
        filename="homelab_complete",
        show=False,
        direction="TB",
        graph_attr=graph_attr,
        node_attr=node_attr,
        edge_attr=edge_attr
    ):

        # Internet & External
        internet = Internet("Internet")

        with Cluster("Network Layer"):
            with Cluster("Physical Network"):
                isp = Router("ISP Router\n192.168.100.1")
                er605 = Router("ER605\nCore Router\n192.168.0.1")

                with Cluster("Switches"):
                    core_switch = Switch("SG3210\nCore Switch\n192.168.90.2")
                    morpheus_switch = Switch("SG2210P\nMorpheus\n192.168.90.3")

                with Cluster("WiFi"):
                    eap610 = Server("EAP610\nLiving Room")
                    eap225 = Server("EAP225\nComputer Room")
                    eap603 = Server("EAP603\nOutdoor")

                firewall = Firewall("OPNsense\n192.168.91.30")

            internet >> isp >> er605 >> core_switch >> morpheus_switch
            core_switch >> firewall
            core_switch - eap610
            core_switch - eap225
            core_switch - eap603

        with Cluster("Storage Layer"):
            with Cluster("Synology NAS - 192.168.20.31"):
                nas = Storage("DS920+\n34TB RAID")

                with Cluster("Storage Pools"):
                    vm_disks = Storage("VMDisks\nNFS")
                    isos = Storage("ISOs\nNFS")
                    media = Storage("Media\nNFS")
                    photos = Storage("Photos\nNFS")

        with Cluster("Proxmox Cluster - VLAN 20"):
            with Cluster("node01 - 192.168.20.20\nPrimary"):
                node01 = Server("node01\nSubnet Router")

                with Cluster("node01 VMs"):
                    ansible = Ubuntu("Ansible\n192.168.20.30")
                    docker_media = Docker("docker-media\n192.168.40.11")
                    docker_utils = Docker("docker-core-utils\n192.168.40.13")

                with Cluster("node01 LXCs"):
                    lxc_glance = LinuxGeneral("LXC 200\nGlance\n192.168.40.12")
                    lxc_bots = LinuxGeneral("LXC 201\nDiscord Bots\n192.168.40.14")
                    lxc_pihole = LinuxGeneral("LXC 202\nPi-hole\n192.168.90.53")

                with Cluster("Kubernetes Control Plane"):
                    k8s_ctrl1 = Server("k8s-ctrl01\n192.168.20.32")
                    k8s_ctrl2 = Server("k8s-ctrl02\n192.168.20.33")
                    k8s_ctrl3 = Server("k8s-ctrl03\n192.168.20.34")

                with Cluster("Kubernetes Workers"):
                    k8s_w1 = Server("worker01\n.20.40")
                    k8s_w2 = Server("worker02\n.20.41")
                    k8s_w3 = Server("worker03\n.20.42")
                    k8s_w4 = Server("worker04\n.20.43")
                    k8s_w5 = Server("worker05\n.20.44")
                    k8s_w6 = Server("worker06\n.20.45")

            with Cluster("node02 - 192.168.20.21"):
                node02 = Server("node02")

                with Cluster("node02 VMs"):
                    traefik = Nginx("Traefik\n192.168.40.20")
                    authentik = Vault("Authentik\n192.168.40.21")
                    immich = Server("Immich\n192.168.40.22")
                    gitlab = Server("GitLab\n192.168.40.23")
                    gitlab_runner = Server("Runner\n192.168.40.24")
                    syslog = Server("Syslog\n192.168.40.5")

        # Connections
        morpheus_switch >> node01
        morpheus_switch >> node02
        morpheus_switch >> nas

        node01 >> ansible
        node01 >> docker_media
        node01 >> docker_utils
        node01 >> lxc_glance
        node01 >> lxc_bots
        node01 >> lxc_pihole

        node02 >> traefik
        node02 >> authentik
        node02 >> immich
        node02 >> gitlab
        node02 >> gitlab_runner

        # Storage connections
        nas >> vm_disks
        nas >> isos
        nas >> media
        nas >> photos


def create_network_diagram():
    """Create network topology diagram."""

    with Diagram(
        "Network Topology - VLANs",
        filename="homelab_network",
        show=False,
        direction="LR",
        graph_attr=graph_attr,
        node_attr=node_attr,
        edge_attr=edge_attr
    ):

        internet = Internet("Internet")

        with Cluster("Edge"):
            isp = Router("ISP\n192.168.100.1")
            gateway = Router("ER605\n192.168.0.1")

        with Cluster("Core Network"):
            core = Switch("SG3210\n192.168.90.2")

            with Cluster("VLAN 10 - Internal\n192.168.10.0/24"):
                workstations = User("Workstations")

            with Cluster("VLAN 20 - Homelab\n192.168.20.0/24"):
                proxmox = Server("Proxmox Cluster")
                k8s = Server("Kubernetes")
                ansible_ctrl = Server("Ansible")

            with Cluster("VLAN 40 - Services\n192.168.40.0/24"):
                docker_hosts = Docker("Docker Hosts")
                traefik_vm = Nginx("Traefik")
                apps = Server("Applications")

            with Cluster("VLAN 90 - Management\n192.168.90.0/24"):
                switches = Switch("Switches")
                aps = Server("Access Points")
                pihole = Server("Pi-hole DNS")

            with Cluster("VLAN 91 - Firewall\n192.168.91.0/24"):
                opnsense = Firewall("OPNsense")

        internet >> isp >> gateway >> core
        core >> workstations
        core >> proxmox
        core >> docker_hosts
        core >> switches
        core >> opnsense

        proxmox - k8s
        proxmox - ansible_ctrl
        docker_hosts - traefik_vm
        docker_hosts - apps
        switches - aps
        switches - pihole


def create_services_diagram():
    """Create services and containers diagram."""

    with Diagram(
        "Services Architecture",
        filename="homelab_services",
        show=False,
        direction="TB",
        graph_attr=graph_attr,
        node_attr=node_attr,
        edge_attr=edge_attr
    ):

        user = User("Users")

        with Cluster("Reverse Proxy Layer"):
            traefik = Nginx("Traefik\n192.168.40.20")
            authentik = Vault("Authentik SSO\n192.168.40.21")

        with Cluster("docker-media (192.168.40.11)"):
            with Cluster("Media Stack"):
                jellyfin = Server("Jellyfin")
                radarr = Server("Radarr")
                sonarr = Server("Sonarr")
                lidarr = Server("Lidarr")
                prowlarr = Server("Prowlarr")
                bazarr = Server("Bazarr")

            with Cluster("Request Management"):
                overseerr = Server("Overseerr")
                jellyseerr = Server("Jellyseerr")

            with Cluster("Downloads"):
                deluge = Server("Deluge")
                sabnzbd = Server("SABnzbd")
                tdarr = Server("Tdarr")
                autobrr = Server("Autobrr")

            with Cluster("Bots"):
                mnemosyne = Server("Mnemosyne Bot")

        with Cluster("docker-core-utils (192.168.40.13)"):
            with Cluster("Monitoring"):
                grafana = Grafana("Grafana")
                prometheus = Prometheus("Prometheus")
                uptime = Server("Uptime Kuma")
                cadvisor = Server("cAdvisor")

            with Cluster("Observability"):
                jaeger = Server("Jaeger")
                speedtest = Server("Speedtest")

            with Cluster("Automation"):
                n8n = Server("n8n")

        with Cluster("LXC 200 - Glance (192.168.40.12)"):
            glance = Server("Glance Dashboard")
            media_api = Server("Media Stats API")
            reddit_mgr = Server("Reddit Manager")
            nba_api = Server("NBA Stats API")
            pihole_api = Server("Pi-hole Stats API")

        with Cluster("LXC 201 - Discord Bots (192.168.40.14)"):
            argus = Server("Argus Bot")
            chronos = Server("Chronos Bot")

        with Cluster("node02 Services"):
            immich = Server("Immich Photos\n192.168.40.22")
            gitlab = Server("GitLab\n192.168.40.23")
            runner = Server("GitLab Runner\n192.168.40.24")

        with Cluster("DNS"):
            pihole = Server("Pi-hole + Unbound\n192.168.90.53")

        # Connections
        user >> traefik
        traefik >> authentik

        traefik >> jellyfin
        traefik >> grafana
        traefik >> glance
        traefik >> immich
        traefik >> gitlab

        authentik >> jellyfin
        authentik >> grafana
        authentik >> glance

        prometheus >> grafana
        prometheus >> cadvisor

        gitlab >> runner


def create_storage_diagram():
    """Create storage architecture diagram."""

    with Diagram(
        "Storage Architecture",
        filename="homelab_storage",
        show=False,
        direction="TB",
        graph_attr=graph_attr,
        node_attr=node_attr,
        edge_attr=edge_attr
    ):

        with Cluster("Synology DS920+ - 192.168.20.31"):
            nas = Storage("NAS Controller")

            with Cluster("Hard Drives"):
                hdd1 = Storage("8TB\nST8000VN004")
                hdd2 = Storage("4TB\nST4000VN006")
                hdd3 = Storage("12TB\nST12000VN0008")
                hdd4 = Storage("10TB\nST10000VN000")

            with Cluster("M.2 NVMe"):
                ssd1 = Storage("1TB\nKingston")
                ssd2 = Storage("1TB\nCrucial")

            nas >> hdd1
            nas >> hdd2
            nas >> hdd3
            nas >> hdd4
            nas >> ssd1
            nas >> ssd2

        with Cluster("NFS Exports"):
            with Cluster("Proxmox-Managed"):
                vmdisks = Storage("VMDisks\n/volume2/ProxmoxCluster-VMDisks")
                isos = Storage("ISOs\n/volume2/ProxmoxCluster-ISOs")

            with Cluster("Manual Mounts"):
                media = Storage("Media\n/volume2/Proxmox-Media")
                lxcs = Storage("LXC Configs\n/volume2/Proxmox-LXCs")
                photos = Storage("Photos\n/volume2/ProxmoxData")

        with Cluster("Proxmox Nodes"):
            node01 = Server("node01")
            node02 = Server("node02")

        with Cluster("Docker Hosts"):
            docker_media = Docker("docker-media\n/mnt/media")
            immich_vm = Server("Immich\n/mnt/appdata")

        nas >> vmdisks
        nas >> isos
        nas >> media
        nas >> lxcs
        nas >> photos

        vmdisks >> node01
        vmdisks >> node02
        isos >> node01
        isos >> node02
        media >> docker_media
        photos >> immich_vm


def main():
    """Generate all diagrams."""
    print("Generating homelab infrastructure diagrams...")
    print()

    print("1. Creating complete infrastructure diagram...")
    create_complete_diagram()
    print("   -> homelab_complete.png")

    print("2. Creating network topology diagram...")
    create_network_diagram()
    print("   -> homelab_network.png")

    print("3. Creating services architecture diagram...")
    create_services_diagram()
    print("   -> homelab_services.png")

    print("4. Creating storage architecture diagram...")
    create_storage_diagram()
    print("   -> homelab_storage.png")

    print()
    print("Done! All diagrams generated successfully.")
    print()
    print("Files created:")
    print("  - homelab_complete.png")
    print("  - homelab_network.png")
    print("  - homelab_services.png")
    print("  - homelab_storage.png")


if __name__ == "__main__":
    main()
