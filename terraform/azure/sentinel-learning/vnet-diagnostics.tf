# ==============================================================================
# Azure VNet Diagnostic Settings for Sentinel
# ==============================================================================
# Enables diagnostic logging for VNets and NSGs to send data to Sentinel
#
# Data Sources:
#   - NSG Flow Logs (network traffic analysis)
#   - VNet Diagnostic Logs
#   - Azure Activity Logs
#
# ==============================================================================

# Get existing VNet
data "azurerm_virtual_network" "connectivity" {
  name                = "erd-shared-corp-vnet-sea"
  resource_group_name = "erd-connectivity-sea-rg"
}

# Get existing NSG
data "azurerm_network_security_group" "dc_nsg" {
  name                = "nsg-identity-prod"
  resource_group_name = "erd-connectivity-sea-rg"
}

# Get the subscription for activity logs
data "azurerm_subscription" "current" {}

# ------------------------------------------------------------------------------
# Storage Account for NSG Flow Logs (Optional - blocked by Azure Policy)
# ------------------------------------------------------------------------------

resource "azurerm_storage_account" "nsg_flow_logs" {
  count = var.enable_nsg_flow_logs ? 1 : 0

  name                          = "stnsgflowlogshomelab"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  shared_access_key_enabled     = true
  allow_nested_items_to_be_public = false

  tags = {
    Environment = "Learning"
    Purpose     = "NSG-Flow-Logs"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# Network Watcher (required for NSG Flow Logs)
# ------------------------------------------------------------------------------

# Check if Network Watcher exists - it's usually auto-created by Azure
data "azurerm_network_watcher" "sea" {
  name                = "NetworkWatcher_southeastasia"
  resource_group_name = "NetworkWatcherRG"
}

# ------------------------------------------------------------------------------
# NSG Flow Logs (Optional - blocked by Azure Policy)
# ------------------------------------------------------------------------------

resource "azurerm_network_watcher_flow_log" "dc_nsg" {
  count = var.enable_nsg_flow_logs ? 1 : 0

  network_watcher_name      = data.azurerm_network_watcher.sea.name
  resource_group_name       = data.azurerm_network_watcher.sea.resource_group_name
  name                      = "flowlog-nsg-dc"
  network_security_group_id = data.azurerm_network_security_group.dc_nsg.id
  storage_account_id        = azurerm_storage_account.nsg_flow_logs[0].id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = data.azurerm_log_analytics_workspace.sentinel.workspace_id
    workspace_region      = var.location
    workspace_resource_id = data.azurerm_log_analytics_workspace.sentinel.id
    interval_in_minutes   = 10
  }

  version = 2

  tags = {
    Environment = "Learning"
    Purpose     = "Sentinel-NSGFlowLogs"
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# VNet Diagnostic Settings
# ------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "vnet_diag" {
  name                       = "diag-vnet-sentinel"
  target_resource_id         = data.azurerm_virtual_network.connectivity.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id

  enabled_log {
    category = "VMProtectionAlerts"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ------------------------------------------------------------------------------
# NSG Diagnostic Settings
# ------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "nsg_diag" {
  name                       = "diag-nsg-sentinel"
  target_resource_id         = data.azurerm_network_security_group.dc_nsg.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# ------------------------------------------------------------------------------
# Azure Activity Log to Sentinel
# ------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "diag-activity-sentinel"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "ServiceHealth"
  }

  enabled_log {
    category = "Alert"
  }

  enabled_log {
    category = "Policy"
  }

  enabled_log {
    category = "Autoscale"
  }

  enabled_log {
    category = "ResourceHealth"
  }
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "nsg_flow_log_id" {
  description = "NSG Flow Log resource ID"
  value       = var.enable_nsg_flow_logs ? azurerm_network_watcher_flow_log.dc_nsg[0].id : null
}

output "flow_log_storage_account" {
  description = "Storage account for NSG flow logs"
  value       = var.enable_nsg_flow_logs ? azurerm_storage_account.nsg_flow_logs[0].name : null
}
