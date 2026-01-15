#!/bin/bash
# =============================================================================
# Hybrid Lab Deployment Script
# =============================================================================
# This script automates the deployment of the Windows Server hybrid lab
#
# Prerequisites:
#   - VLAN 80 configured on OPNsense
#   - Run from Ansible controller (192.168.20.30)
#   - NAS accessible at 192.168.10.31
#
# Usage:
#   ./deploy-hybrid-lab.sh [phase]
#
# Phases:
#   all       - Run all phases (default)
#   isos      - Upload ISOs only
#   packer    - Build Packer templates only
#   terraform - Deploy VMs only
#   ansible   - Configure AD only
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NAS_IP="192.168.10.31"
NAS_SHARE="Main Volume/ISOs"
NAS_MOUNT="/mnt/nas-isos"
PROXMOX_NODE="192.168.20.22"
ISO_PATH="/var/lib/vz/template/iso"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Phase 1: Upload ISOs
# =============================================================================
upload_isos() {
    log_info "=== Phase 1: Uploading ISOs to Proxmox ==="

    # Mount NAS
    if ! mountpoint -q "$NAS_MOUNT"; then
        log_info "Mounting NAS share..."
        sudo mkdir -p "$NAS_MOUNT"
        sudo mount -t cifs "//${NAS_IP}/${NAS_SHARE}" "$NAS_MOUNT" -o username=hermes-admin,vers=3.0 || {
            log_error "Failed to mount NAS. Please enter password when prompted."
            sudo mount -t cifs "//${NAS_IP}/${NAS_SHARE}" "$NAS_MOUNT" -o username=hermes-admin,vers=3.0
        }
    fi

    # Upload Windows Server 2025
    if ssh root@${PROXMOX_NODE} "test -f ${ISO_PATH}/ws2025-dec2025.iso"; then
        log_info "Windows Server 2025 ISO already exists, skipping..."
    else
        log_info "Uploading Windows Server 2025 ISO..."
        scp "${NAS_MOUNT}/Windows Server 2025/en-us_windows_server_2025_updated_dec_2025_x64_dvd_c54ab58b.iso" \
            root@${PROXMOX_NODE}:${ISO_PATH}/ws2025-dec2025.iso
    fi

    # Upload Windows Server 2022
    if ssh root@${PROXMOX_NODE} "test -f ${ISO_PATH}/ws2022-dec2025.iso"; then
        log_info "Windows Server 2022 ISO already exists, skipping..."
    else
        log_info "Uploading Windows Server 2022 ISO..."
        scp "${NAS_MOUNT}/Windows Server 2022/en-us_windows_server_2022_updated_dec_2025_x64_dvd_84450f64.iso" \
            root@${PROXMOX_NODE}:${ISO_PATH}/ws2022-dec2025.iso
    fi

    # Upload Windows 11
    if ssh root@${PROXMOX_NODE} "test -f ${ISO_PATH}/win11-25h2-dec2025.iso"; then
        log_info "Windows 11 ISO already exists, skipping..."
    else
        log_info "Uploading Windows 11 ISO..."
        scp "${NAS_MOUNT}/Windows 11/en-us_windows_11_consumer_editions_version_25h2_updated_dec_2025_x64_dvd_115b2867.iso" \
            root@${PROXMOX_NODE}:${ISO_PATH}/win11-25h2-dec2025.iso
    fi

    # Upload SQL Server 2022
    if ssh root@${PROXMOX_NODE} "test -f ${ISO_PATH}/sql2022-std.iso"; then
        log_info "SQL Server 2022 ISO already exists, skipping..."
    else
        log_info "Uploading SQL Server 2022 ISO..."
        scp "${NAS_MOUNT}/SQL Server 2022/enu_sql_server_2022_standard_edition_x64_dvd_43079f69.iso" \
            root@${PROXMOX_NODE}:${ISO_PATH}/sql2022-std.iso
    fi

    # Download VirtIO drivers
    if ssh root@${PROXMOX_NODE} "test -f ${ISO_PATH}/virtio-win.iso"; then
        log_info "VirtIO ISO already exists, skipping..."
    else
        log_info "Downloading VirtIO drivers..."
        ssh root@${PROXMOX_NODE} "wget -q -O ${ISO_PATH}/virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
    fi

    log_info "ISO upload complete!"
    ssh root@${PROXMOX_NODE} "ls -lh ${ISO_PATH}/*.iso"
}

# =============================================================================
# Phase 2: Build Packer Templates
# =============================================================================
build_packer_templates() {
    log_info "=== Phase 2: Building Packer Templates ==="

    # Check if Packer is installed
    if ! command -v packer &> /dev/null; then
        log_error "Packer is not installed. Installing..."
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
        sudo apt-get update && sudo apt-get install -y packer
    fi

    # Build Windows Server 2025 template
    log_info "Building Windows Server 2025 template..."
    cd "${PROJECT_DIR}/packer/windows-server-2025-proxmox"

    if [ ! -f "variables.pkrvars.hcl" ]; then
        log_error "variables.pkrvars.hcl not found. Please create it with your Proxmox credentials."
        exit 1
    fi

    packer init .
    packer validate -var-file=variables.pkrvars.hcl windows-server-2025.pkr.hcl
    packer build -var-file=variables.pkrvars.hcl windows-server-2025.pkr.hcl

    # Build Windows 11 template
    log_info "Building Windows 11 template..."
    cd "${PROJECT_DIR}/packer/windows-11-proxmox"

    if [ ! -f "variables.pkrvars.hcl" ]; then
        log_error "variables.pkrvars.hcl not found. Please create it with your Proxmox credentials."
        exit 1
    fi

    packer init .
    packer validate -var-file=variables.pkrvars.hcl windows-11.pkr.hcl
    packer build -var-file=variables.pkrvars.hcl windows-11.pkr.hcl

    log_info "Packer templates built successfully!"
}

# =============================================================================
# Phase 3: Deploy VMs with Terraform
# =============================================================================
deploy_terraform() {
    log_info "=== Phase 3: Deploying VMs with Terraform ==="

    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Installing..."
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
        sudo apt-get update && sudo apt-get install -y terraform
    fi

    cd "${PROJECT_DIR}/terraform/hybrid-lab"

    if [ ! -f "terraform.tfvars" ]; then
        log_error "terraform.tfvars not found. Please create it with your configuration."
        exit 1
    fi

    terraform init
    terraform plan -out=tfplan

    log_warn "Review the plan above. Press Enter to apply or Ctrl+C to cancel."
    read -r

    terraform apply tfplan

    log_info "VMs deployed successfully!"
    terraform output
}

# =============================================================================
# Phase 4: Configure AD with Ansible
# =============================================================================
configure_ansible() {
    log_info "=== Phase 4: Configuring Active Directory ==="

    cd "${PROJECT_DIR}/ansible-playbooks/hybrid-lab"

    # Test connectivity first
    log_info "Testing WinRM connectivity..."
    ansible -i inventory.yml all -m win_ping || {
        log_warn "Some hosts may not be ready yet. Waiting 60 seconds..."
        sleep 60
        ansible -i inventory.yml all -m win_ping
    }

    # Run site playbook
    log_info "Running AD configuration playbooks..."
    ansible-playbook -i inventory.yml site.yml

    log_info "Active Directory configuration complete!"
}

# =============================================================================
# Main
# =============================================================================
main() {
    local phase="${1:-all}"

    echo "=============================================="
    echo "     Hybrid Lab Deployment Script"
    echo "=============================================="
    echo "Project Directory: ${PROJECT_DIR}"
    echo "Phase: ${phase}"
    echo "=============================================="

    case "$phase" in
        isos)
            upload_isos
            ;;
        packer)
            build_packer_templates
            ;;
        terraform)
            deploy_terraform
            ;;
        ansible)
            configure_ansible
            ;;
        all)
            upload_isos
            build_packer_templates
            deploy_terraform
            configure_ansible
            ;;
        *)
            echo "Usage: $0 [all|isos|packer|terraform|ansible]"
            exit 1
            ;;
    esac

    echo ""
    log_info "=============================================="
    log_info "     Deployment Complete!"
    log_info "=============================================="
    echo ""
    echo "Next Steps:"
    echo "  1. Verify VMs in Proxmox: https://proxmox.hrmsmrflrii.xyz"
    echo "  2. Test domain: nslookup dc01.hrmsmrflrii.xyz"
    echo "  3. RDP to DC01: 192.168.80.2"
    echo "  4. Configure Entra Connect wizard on AADCON01"
    echo "  5. Register Password Protection proxy on AADPP01/02"
    echo ""
}

main "$@"
