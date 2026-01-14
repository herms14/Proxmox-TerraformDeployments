# Kubernetes Cluster

> **Internal Documentation** - Contains cluster configuration and access details.

Related: [[00 - Homelab Index]] | [[02 - Proxmox Cluster]] | [[06 - Ansible Automation]]

---

## Cluster Overview

| Metric | Value |
|--------|-------|
| Version | v1.28.15 (stable) |
| Control Plane | 3 nodes (HA) |
| Worker Nodes | 6 nodes |
| Total Nodes | 9 |
| Container Runtime | containerd v1.7.28 |
| CNI Plugin | Calico v3.27.0 |
| Pod Network | 10.244.0.0/16 |
| Status | Fully operational (December 2025) |

---

## Control Plane Nodes

| Hostname | IP Address | Role |
|----------|------------|------|
| k8s-controller01 | 192.168.20.32 | Primary |
| k8s-controller02 | 192.168.20.33 | HA |
| k8s-controller03 | 192.168.20.34 | HA |

All control plane nodes are on **node03** (Proxmox).

---

## Worker Nodes

| Hostname | IP Address |
|----------|------------|
| k8s-worker01 | 192.168.20.40 |
| k8s-worker02 | 192.168.20.41 |
| k8s-worker03 | 192.168.20.42 |
| k8s-worker04 | 192.168.20.43 |
| k8s-worker05 | 192.168.20.44 |
| k8s-worker06 | 192.168.20.45 |

All worker nodes are on **node03** (Proxmox).

---

## Node Specifications

| Setting | Value |
|---------|-------|
| Cores | 2 |
| RAM | 4GB |
| Disk | 20GB |
| Network | VLAN 20 |
| Template | tpl-ubuntu-shared-v1 |

---

## Cluster Access

### SSH Access

```bash
# Control plane
ssh hermes-admin@192.168.20.32
ssh hermes-admin@192.168.20.33
ssh hermes-admin@192.168.20.34

# Workers
ssh hermes-admin@192.168.20.40
ssh hermes-admin@192.168.20.41
# ... etc
```

### kubectl Access

From ansible-controller01:
```bash
kubectl get nodes
kubectl get pods -A
```

---

## Configuration Details

### Control Plane

- Stacked etcd (each controller runs etcd)
- HA via kubeadm bootstrap
- API server accessible on each controller

### Container Runtime

- containerd v1.7.28
- systemd cgroup driver

### Networking

- Calico v3.27.0 for pod networking
- Pod CIDR: 10.244.0.0/16
- Service CIDR: 10.96.0.0/12 (default)

---

## Deployment

Deployed via Ansible playbooks from ansible-controller01:

```bash
# Full cluster deployment
ansible-playbook k8s/k8s-deploy-all.yml
```

See [[06 - Ansible Automation]] for playbook details.

---

## Useful Commands

```bash
# Cluster info
kubectl cluster-info

# Node status
kubectl get nodes -o wide

# All pods
kubectl get pods -A

# System pods
kubectl get pods -n kube-system

# Calico status
kubectl get pods -n calico-system
```

---

## Related Documentation

- [[02 - Proxmox Cluster]] - VM hosting
- [[06 - Ansible Automation]] - Deployment playbooks
- [[07 - Deployed Services]] - K8s-hosted services
- [[12 - Troubleshooting]] - Common issues

