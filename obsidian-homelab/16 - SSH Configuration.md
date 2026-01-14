# SSH Configuration

> **Internal Documentation** - Contains SSH keys and access credentials.

Related: [[00 - Homelab Index]] | [[02 - Proxmox Cluster]] | [[06 - Ansible Automation]]

---

## SSH Key Setup

### Primary SSH Key (No Passphrase)

**Status**: Deployed December 21, 2025

| Field | Value |
|-------|-------|
| Key File | `~/.ssh/homelab_ed25519` |
| Public Key File | `~/.ssh/homelab_ed25519.pub` |
| Key Type | ed25519 |
| Passphrase | None (for automation) |
| Comment | `hermes@homelab-nopass` |

### Public Key

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINVYlOowJQE4tC4GEo17MptDGdaQfWwMDMRxLdKd/yui hermes@homelab-nopass
```

---

## SSH Config Setup

SSH configuration file created at `~/.ssh/config` with host aliases for convenient access.

### Config File Location

```
~/.ssh/config
```

### Configuration

```ssh-config
# Proxmox Nodes
Host node01
    HostName 192.168.20.20
    User root
    IdentityFile ~/.ssh/homelab_ed25519

Host node02
    HostName 192.168.20.21
    User root
    IdentityFile ~/.ssh/homelab_ed25519

Host node03
    HostName 192.168.20.22
    User root
    IdentityFile ~/.ssh/homelab_ed25519

# Ansible Controller
Host ansible-controller01
    HostName 192.168.20.30
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

# Kubernetes Controllers
Host k8s-controller01
    HostName 192.168.20.32
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-controller02
    HostName 192.168.20.33
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-controller03
    HostName 192.168.20.34
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

# Kubernetes Workers
Host k8s-worker01
    HostName 192.168.20.40
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker02
    HostName 192.168.20.41
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker03
    HostName 192.168.20.42
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker04
    HostName 192.168.20.43
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker05
    HostName 192.168.20.44
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker06
    HostName 192.168.20.45
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

# Service VMs - VLAN 40
Host docker-vm-core-utilities01
    HostName 192.168.40.13
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host docker-vm-media01
    HostName 192.168.40.11
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host traefik-vm01
    HostName 192.168.40.20
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host authentik-vm01
    HostName 192.168.40.21
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host immich-vm01
    HostName 192.168.40.22
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519

Host gitlab-vm01
    HostName 192.168.40.23
    User hermes-admin
    IdentityFile ~/.ssh/homelab_ed25519
```

---

## Usage Examples

### Connect to Hosts by Alias

```bash
# Proxmox nodes
ssh node01
ssh node02
ssh node03

# Ansible controller
ssh ansible-controller01

# Kubernetes nodes
ssh k8s-controller01
ssh k8s-worker01

# Service VMs
ssh traefik-vm01
ssh authentik-vm01
ssh docker-vm-media01
```

### Run Remote Commands

```bash
# Check uptime on all K8s controllers
ssh k8s-controller01 "uptime"
ssh k8s-controller02 "uptime"
ssh k8s-controller03 "uptime"

# Check Docker status on service VMs
ssh docker-vm-media01 "docker ps"
ssh docker-vm-core-utilities01 "docker ps"
```

---

## Key Distribution

The SSH key has been distributed to all infrastructure hosts:

### Proxmox Nodes (root user)
- node01 (192.168.20.20)
- node02 (192.168.20.21)
- node03 (192.168.20.22)

### Ansible Controller (hermes-admin user)
- ansible-controller01 (192.168.20.30)

### Kubernetes Cluster (hermes-admin user)
- k8s-controller01-03 (192.168.20.32-34)
- k8s-worker01-06 (192.168.20.40-45)

### Service VMs (hermes-admin user)
- docker-vm-core-utilities01 (192.168.40.13)
- docker-vm-media01 (192.168.40.11)
- traefik-vm01 (192.168.40.20)
- authentik-vm01 (192.168.40.21)
- immich-vm01 (192.168.40.22)
- gitlab-vm01 (192.168.40.23)

---

## Ansible Controller Update

The Ansible controller has been updated to use the new SSH key:

### Key Location on Ansible Controller

```
/home/hermes-admin/.ssh/homelab_ed25519
/home/hermes-admin/.ssh/homelab_ed25519.pub
```

### Ansible Configuration

The key is automatically used via the SSH config file for all playbook executions.

**Test connectivity**:
```bash
ssh ansible-controller01 "ansible all -m ping"
```

---

## Legacy SSH Keys

### Previous Key (with passphrase)

| Field | Value |
|-------|-------|
| Public Key | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAby7br+5MzyDus2fi2UFjUBZvGucN40Gxa29bgUTbfz hermes@homelab` |
| Comment | `hermes@homelab` |
| Status | Still deployed on hosts, can be removed once new key is verified |

---

## Security Considerations

### No Passphrase Key

The new SSH key (`homelab_ed25519`) has **no passphrase** to enable:
- Automated Ansible playbook execution
- CI/CD pipeline automation
- Unattended SSH operations

### Security Mitigations

1. **File Permissions**: Key file is `chmod 600` (owner read/write only)
2. **Network Isolation**: Keys only work within internal VLANs (20, 40)
3. **Host-based Access**: SSH config restricts key usage to specific hosts
4. **Audit Trail**: All SSH sessions are logged on target hosts
5. **Key Rotation**: Regular key rotation scheduled every 6 months

### Access Control

- **Root Access**: Only on Proxmox nodes (node01-03)
- **User Access**: Standard user `hermes-admin` on all VMs
- **No Public Exposure**: SSH only accessible within homelab network

---

## Key Rotation Plan

### Rotation Schedule

- **Current Key Created**: December 21, 2025
- **Next Rotation**: June 2026 (6 months)

### Rotation Process

1. Generate new ed25519 key pair
2. Add new public key to all hosts (`~/.ssh/authorized_keys`)
3. Update SSH config to use new private key
4. Test connectivity to all hosts
5. Remove old public key from hosts
6. Archive old private key (encrypted backup)

---

## Troubleshooting

### Connection Issues

```bash
# Test SSH connection with verbose output
ssh -v node01

# Verify key is being used
ssh -v node01 2>&1 | grep "Offering public key"

# Check key permissions
ls -la ~/.ssh/homelab_ed25519  # Should be -rw-------
```

### Key Permission Errors

```bash
# Fix private key permissions
chmod 600 ~/.ssh/homelab_ed25519

# Fix SSH config permissions
chmod 644 ~/.ssh/config

# Fix SSH directory permissions
chmod 700 ~/.ssh
```

### Verify Key on Remote Host

```bash
# Check authorized_keys on target host
ssh node01 "cat /root/.ssh/authorized_keys | grep homelab-nopass"
ssh ansible-controller01 "cat ~/.ssh/authorized_keys | grep homelab-nopass"
```

---

## Related Documentation

- [[02 - Proxmox Cluster]] - Proxmox node access
- [[06 - Ansible Automation]] - Ansible playbook execution
- [[04 - Kubernetes Cluster]] - K8s node access
- [[11 - Credentials]] - All access credentials
- [[12 - Troubleshooting]] - Common SSH issues

---

*Last updated: December 21, 2025*
