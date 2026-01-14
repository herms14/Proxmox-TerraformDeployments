---
banner: "[[999 Attachments/pixel-banner-images/cybersecurity.jpg]]"
---
# Homelab Infrastructure Index

> **Internal Documentation** - Contains credentials and sensitive information. DO NOT publish to GitHub.

## Quick Links

### Infrastructure
- [[01 - Network Architecture]] - VLANs, physical topology, switch configs
- [[02 - Proxmox Cluster]] - Nodes, VM/LXC standards, templates
- [[03 - Storage Architecture]] - NFS, Synology, storage pools
- [[04 - Kubernetes Cluster]] - K8s deployment, nodes, CNI

### Deployment
- [[05 - Terraform Configuration]] - IaC modules and deployment
- [[06 - Ansible Automation]] - Playbooks, inventory, Discord notifications

### Services
- [[07 - Deployed Services]] - All Docker services with ports
- [[08 - Arr Media Stack]] - Jellyfin, Radarr, Sonarr, etc.
- [[09 - Traefik Reverse Proxy]] - SSL, routing, configuration
- [[45 - Docker Services Reference]] - Complete documentation for all Docker containers

### Reference
- [[10 - IP Address Map]] - Complete IP allocation
- [[11 - Credentials]] - All passwords, API keys, tokens
- [[12 - Troubleshooting]] - Common issues and resolutions
- [[13 - Service Configuration Guide]] - Detailed service setup with command explanations
- [[14 - Authentik Google SSO Setup]] - Google SSO configuration for all services
- [[15 - New Service Onboarding Guide]] - Complete workflow for adding new services
- [[16 - SSH Configuration]] - SSH keys, config file, host aliases

### Monitoring & Automation
- [[17 - Monitoring Stack]] - Uptime Kuma, Prometheus, Grafana
- [[18 - Observability Stack]] - OpenTelemetry, Jaeger, distributed tracing
- [[19 - Watchtower Updates]] - Interactive container updates via Discord
- [[20 - GitLab CI-CD Automation]] - Automated service onboarding pipeline
- [[21 - Application Configurations]] - Detailed app setup with command explanations
- [[22 - Service Onboarding Workflow]] - Automated onboarding status checker via Discord
- [[23 - Glance Dashboard]] - Dashboard, Media Stats widget, custom API
- [[24 - Discord Bots]] - Argus, Mnemosyne, Chronos automation bots

### Cloud & Hybrid
- [[36 - Azure Environment]] - Azure Sentinel SIEM, deployment VMs, VPN connectivity
- [[37 - Azure Hybrid Lab]] - Active Directory forest, domain controllers, enterprise tiering

### Tutorials
- [[26 - Tutorials Index]] - Complete list of all tutorials
- [[27 - Discord Bot Deployment Tutorial]] - Creating and deploying Discord bots
- [[28 - Athena Bot Tutorial]] - Claude Code task queue integration
- [[29 - Immich Authentik SSO Tutorial]] - OAuth/SSO for Immich
- [[30 - LXC Migration Tutorial]] - Migrating services from VM to LXC
- [[31 - Kubernetes Glance Tutorial]] - Deploying Glance on K8s
- [[39 - PBS Deployment Tutorial]] - Proxmox Backup Server LXC deployment
- [[40 - PBS Disaster Recovery]] - Complete PBS recovery when drives fail
- [[42 - Immich Backup and Restore]] - Immich database backup and disaster recovery
- [[43 - GitOps Complete Tutorial]] - GitOps theory, design patterns, and implementation
- [[44 - Glance GitOps Onboarding Tutorial]] - Hands-on GitOps migration with Glance

### Active TODOs
- [[TODO - Cloudflare Tunnel Setup]] - Expose Jellyfin/Jellyseerr to internet
- [[TODO - Resume Homelab Experience]] - Showcase homelab on resume
- [[TODO - Homelab Blog Series]] - Document and share homelab journey

### Publications & References
- [[25 - Homelab Master Wiki]] - Complete technical wiki/encyclopedia (authoritative reference)
- [[38 - Homelab Technical Manual]] - Comprehensive technical manual with personal story prologue
- [[Book - The Complete Homelab Guide]] - Step-by-step tutorial from trip photos to production infrastructure

---

## Infrastructure Summary

| Metric | Value |
|--------|-------|
| Proxmox Nodes | 2 |
| Virtual Machines | 18 |
| LXC Containers | 3 |
| Docker Containers | 33+ |
| Kubernetes Nodes | 9 |
| Total vCPUs | 44 |
| Total RAM | 145 GB |
| Storage | 426 GB (NFS) |
| Observability | Full stack (OTEL, Jaeger, Prometheus) |
| Azure VMs | 6 (ubuntu-deploy, ans-tf-vm01, 4 DCs) |
| Azure SIEM | Sentinel (law-homelab-sentinel) |
| Azure AD | hrmsmrflrii.xyz (4 Domain Controllers) |

## Service URLs

| Service | Internal URL | External URL |
|---------|--------------|--------------|
| Proxmox | https://192.168.20.21:8006 | https://proxmox.hrmsmrflrii.xyz |
| PBS | https://192.168.20.50:8007 | https://pbs.hrmsmrflrii.xyz |
| Traefik | http://192.168.40.20:8080 | https://traefik.hrmsmrflrii.xyz |
| Authentik | http://192.168.40.21:9000 | https://auth.hrmsmrflrii.xyz |
| Immich | http://192.168.40.22:2283 | https://photos.hrmsmrflrii.xyz |
| GitLab | http://192.168.40.23:80 | https://gitlab.hrmsmrflrii.xyz |
| Jellyfin | http://192.168.40.11:8096 | https://jellyfin.hrmsmrflrii.xyz |
| Deluge | http://192.168.40.11:8112 | https://deluge.hrmsmrflrii.xyz |
| SABnzbd | http://192.168.40.11:8081 | https://sabnzbd.hrmsmrflrii.xyz |
| Glance | http://192.168.40.12:8080 | https://glance.hrmsmrflrii.xyz |
| Uptime Kuma | http://192.168.40.13:3001 | https://uptime.hrmsmrflrii.xyz |
| Prometheus | http://192.168.40.13:9090 | https://prometheus.hrmsmrflrii.xyz |
| Grafana | http://192.168.40.13:3030 | https://grafana.hrmsmrflrii.xyz |
| Jaeger | http://192.168.40.13:16686 | https://jaeger.hrmsmrflrii.xyz |

See [[07 - Deployed Services]] for complete list.

---

## Related External Docs

- [GitHub Repository](https://github.com/herms14/Proxmox-TerraformDeployments) - Public sanitized docs
- [GitHub Wiki](https://github.com/herms14/Proxmox-TerraformDeployments/wiki) - Beginner-friendly guides

---

*Last updated: January 14, 2026*
