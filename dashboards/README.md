# Grafana Dashboard Definitions

This directory contains Grafana dashboard JSON files used by the homelab monitoring stack.

## Dashboards

| Dashboard | Description | Ansible Playbook |
|-----------|-------------|------------------|
| `container-status.json` | Container status and health monitoring | `monitoring/deploy-container-status-dashboard.yml` |
| `omada-network.json` | TP-Link Omada network overview | `monitoring/deploy-omada-full-dashboard.yml` |
| `synology-nas.json` | Synology NAS storage metrics | `monitoring/deploy-synology-nas-dashboard.yml` |

## Deployment

Dashboards are deployed via Ansible playbooks located in `ansible-playbooks/monitoring/`.

```bash
# From Ansible controller
cd ~/ansible
ansible-playbook monitoring/deploy-container-status-dashboard.yml
```

## Glance Integration

These dashboards are embedded in Glance dashboard pages via iframes. See `docs/GLANCE.md` for configuration details.
