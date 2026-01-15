#!/bin/bash
# ==============================================================================
# Install Azure Monitor Agent on Azure Domain Controllers
# ==============================================================================
# Run this script from ubuntu-deploy-vm (10.90.10.5)
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login --identity)
#   - DCRs deployed via Terraform
#
# Usage:
#   chmod +x install-ama-azure-vms.sh
#   ./install-ama-azure-vms.sh
#
# ==============================================================================

set -e

# Configuration
SUBSCRIPTION_ID="2212d587-1bad-4013-b605-b421b1f83c30"
DC_RESOURCE_GROUP="erd-connectivity-sea-rg"
SENTINEL_RESOURCE_GROUP="rg-homelab-sentinel"

# Domain Controllers
declare -A DCS=(
    ["AZDC01"]="10.10.4.4"
    ["AZDC02"]="10.10.4.5"
    ["AZRODC01"]="10.10.4.6"
    ["AZRODC02"]="10.10.4.7"
)

# DCR IDs (update these after Terraform deploy)
SECURITY_DCR_NAME="dcr-windows-security-events"
AD_DCR_NAME="dcr-activedirectory-events"

echo "================================================"
echo "  Azure Monitor Agent Installation"
echo "================================================"
echo ""

# Check Azure CLI login
echo "[1/4] Checking Azure CLI authentication..."
if ! az account show &>/dev/null; then
    echo "  Not logged in. Attempting managed identity login..."
    az login --identity
fi

az account set --subscription "$SUBSCRIPTION_ID"
echo "  Using subscription: $(az account show --query name -o tsv)"
echo ""

# Get DCR IDs
echo "[2/4] Getting Data Collection Rule IDs..."
SECURITY_DCR_ID=$(az monitor data-collection-rule show \
    --name "$SECURITY_DCR_NAME" \
    --resource-group "$SENTINEL_RESOURCE_GROUP" \
    --query id -o tsv 2>/dev/null || echo "")

AD_DCR_ID=$(az monitor data-collection-rule show \
    --name "$AD_DCR_NAME" \
    --resource-group "$SENTINEL_RESOURCE_GROUP" \
    --query id -o tsv 2>/dev/null || echo "")

if [ -z "$SECURITY_DCR_ID" ]; then
    echo "  [WARNING] Security DCR not found. Run Terraform first!"
    echo "  cd /opt/terraform/sentinel-learning && terraform apply"
    exit 1
fi

echo "  Security DCR: $SECURITY_DCR_NAME"
echo "  AD DCR: $AD_DCR_NAME"
echo ""

# Install AMA on each DC
echo "[3/4] Installing Azure Monitor Agent on Domain Controllers..."

for DC_NAME in "${!DCS[@]}"; do
    DC_IP="${DCS[$DC_NAME]}"
    echo ""
    echo "  Processing $DC_NAME ($DC_IP)..."

    # Check if VM exists
    VM_EXISTS=$(az vm show \
        --name "$DC_NAME" \
        --resource-group "$DC_RESOURCE_GROUP" \
        --query id -o tsv 2>/dev/null || echo "")

    if [ -z "$VM_EXISTS" ]; then
        echo "    [SKIP] VM $DC_NAME not found in $DC_RESOURCE_GROUP"
        continue
    fi

    # Check if AMA is already installed
    AMA_INSTALLED=$(az vm extension list \
        --vm-name "$DC_NAME" \
        --resource-group "$DC_RESOURCE_GROUP" \
        --query "[?name=='AzureMonitorWindowsAgent'].name" -o tsv 2>/dev/null || echo "")

    if [ -n "$AMA_INSTALLED" ]; then
        echo "    [OK] AMA already installed on $DC_NAME"
    else
        echo "    Installing Azure Monitor Agent..."
        az vm extension set \
            --name AzureMonitorWindowsAgent \
            --publisher Microsoft.Azure.Monitor \
            --vm-name "$DC_NAME" \
            --resource-group "$DC_RESOURCE_GROUP" \
            --enable-auto-upgrade true \
            --no-wait

        echo "    [OK] AMA installation initiated (running in background)"
    fi

    # Create DCR associations
    echo "    Creating DCR associations..."

    # Security DCR association
    az monitor data-collection-rule association create \
        --name "${DC_NAME}-security-dcr-assoc" \
        --rule-id "$SECURITY_DCR_ID" \
        --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$DC_RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$DC_NAME" \
        2>/dev/null || echo "    [INFO] Security DCR association already exists"

    # AD DCR association (if available)
    if [ -n "$AD_DCR_ID" ]; then
        az monitor data-collection-rule association create \
            --name "${DC_NAME}-ad-dcr-assoc" \
            --rule-id "$AD_DCR_ID" \
            --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$DC_RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$DC_NAME" \
            2>/dev/null || echo "    [INFO] AD DCR association already exists"
    fi

    echo "    [OK] $DC_NAME configured"
done

# Verify installations
echo ""
echo "[4/4] Verifying installations..."
echo ""

for DC_NAME in "${!DCS[@]}"; do
    STATUS=$(az vm extension list \
        --vm-name "$DC_NAME" \
        --resource-group "$DC_RESOURCE_GROUP" \
        --query "[?name=='AzureMonitorWindowsAgent'].provisioningState" -o tsv 2>/dev/null || echo "NotFound")

    echo "  $DC_NAME: $STATUS"
done

echo ""
echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Wait 5-10 minutes for data to appear"
echo "  2. Verify data in Log Analytics:"
echo "     SecurityEvent | where Computer has 'AZDC' | take 10"
echo "  3. Check Sentinel incidents dashboard"
echo ""
