# Azure Sentinel Learning Infrastructure
# Deploy from ubuntu-deploy-vm (10.90.10.5)
# terraform init && terraform plan && terraform apply

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }
}

provider "azurerm" {
  features {
    log_analytics_workspace {
      permanently_delete_on_destroy = false
    }
  }
  # Use Azure CLI authentication (works on any machine with 'az login')
  # For Azure VMs with managed identity, set use_msi = true
  subscription_id = var.subscription_id
}

# ============================================================================
# DATA SOURCES - Reference existing resources
# ============================================================================

data "azurerm_log_analytics_workspace" "sentinel" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
}

data "azurerm_resource_group" "sentinel" {
  name = var.resource_group_name
}

# ============================================================================
# DATA COLLECTION ENDPOINT - Windows
# ============================================================================

resource "azurerm_monitor_data_collection_endpoint" "windows" {
  name                          = "dce-homelab-windows"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "Windows"
  public_network_access_enabled = true

  tags = {
    Environment = "Learning"
    Purpose     = "Sentinel-WindowsEvents"
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# DATA COLLECTION RULE - Windows Security Events
# ============================================================================

resource "azurerm_monitor_data_collection_rule" "windows_security" {
  name                        = "dcr-windows-security-events"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.windows.id

  destinations {
    log_analytics {
      workspace_resource_id = data.azurerm_log_analytics_workspace.sentinel.id
      name                  = "la-sentinel"
    }
  }

  data_flow {
    streams      = ["Microsoft-SecurityEvent"]
    destinations = ["la-sentinel"]
  }

  data_flow {
    streams      = ["Microsoft-WindowsEvent"]
    destinations = ["la-sentinel"]
  }

  # Security Events - Authentication
  data_sources {
    windows_event_log {
      streams = ["Microsoft-SecurityEvent"]
      name    = "security-auth"
      x_path_queries = [
        "Security!*[System[(EventID=4624)]]",
        "Security!*[System[(EventID=4625)]]",
        "Security!*[System[(EventID=4626)]]",
        "Security!*[System[(EventID=4634)]]",
        "Security!*[System[(EventID=4647)]]",
        "Security!*[System[(EventID=4648)]]",
        "Security!*[System[(EventID=4672)]]",
        "Security!*[System[(EventID=4740)]]",
      ]
    }

    windows_event_log {
      streams = ["Microsoft-SecurityEvent"]
      name    = "security-account-mgmt"
      x_path_queries = [
        "Security!*[System[(EventID=4720)]]",
        "Security!*[System[(EventID=4722)]]",
        "Security!*[System[(EventID=4723)]]",
        "Security!*[System[(EventID=4724)]]",
        "Security!*[System[(EventID=4725)]]",
        "Security!*[System[(EventID=4726)]]",
        "Security!*[System[(EventID=4738)]]",
      ]
    }

    windows_event_log {
      streams = ["Microsoft-SecurityEvent"]
      name    = "security-group-mgmt"
      x_path_queries = [
        "Security!*[System[(EventID=4727)]]",
        "Security!*[System[(EventID=4728)]]",
        "Security!*[System[(EventID=4729)]]",
        "Security!*[System[(EventID=4730)]]",
        "Security!*[System[(EventID=4731)]]",
        "Security!*[System[(EventID=4732)]]",
        "Security!*[System[(EventID=4733)]]",
        "Security!*[System[(EventID=4734)]]",
        "Security!*[System[(EventID=4756)]]",
        "Security!*[System[(EventID=4757)]]",
      ]
    }

    windows_event_log {
      streams = ["Microsoft-SecurityEvent"]
      name    = "security-kerberos"
      x_path_queries = [
        "Security!*[System[(EventID=4768)]]",
        "Security!*[System[(EventID=4769)]]",
        "Security!*[System[(EventID=4771)]]",
        "Security!*[System[(EventID=4776)]]",
      ]
    }

    windows_event_log {
      streams = ["Microsoft-SecurityEvent"]
      name    = "security-directory"
      x_path_queries = [
        "Security!*[System[(EventID=4662)]]",
        "Security!*[System[(EventID=5136)]]",
        "Security!*[System[(EventID=5137)]]",
        "Security!*[System[(EventID=5141)]]",
      ]
    }

    windows_event_log {
      streams = ["Microsoft-SecurityEvent"]
      name    = "security-audit"
      x_path_queries = [
        "Security!*[System[(EventID=1102)]]",
        "Security!*[System[(EventID=4688)]]",
        "Security!*[System[(EventID=4697)]]",
        "Security!*[System[(EventID=4698)]]",
        "Security!*[System[(EventID=4719)]]",
      ]
    }

    windows_event_log {
      streams = ["Microsoft-WindowsEvent"]
      name    = "system-events"
      x_path_queries = [
        "System!*[System[(Level=1 or Level=2 or Level=3)]]",
        "Application!*[System[(Level=1 or Level=2)]]",
      ]
    }
  }

  description = "Collects Windows Security and System events from domain controllers"

  tags = {
    Environment = "Learning"
    DataSource  = "DomainControllers"
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# DATA COLLECTION RULE - Active Directory Events
# ============================================================================

resource "azurerm_monitor_data_collection_rule" "ad_directory_service" {
  name                        = "dcr-activedirectory-events"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.windows.id

  destinations {
    log_analytics {
      workspace_resource_id = data.azurerm_log_analytics_workspace.sentinel.id
      name                  = "la-sentinel"
    }
  }

  data_flow {
    streams      = ["Microsoft-WindowsEvent"]
    destinations = ["la-sentinel"]
  }

  data_sources {
    windows_event_log {
      streams = ["Microsoft-WindowsEvent"]
      name    = "ad-services"
      x_path_queries = [
        "Directory Service!*[System[(Level=1 or Level=2 or Level=3 or Level=4)]]",
        "DNS Server!*[System[(Level=1 or Level=2 or Level=3)]]",
        "DFS Replication!*[System[(Level=1 or Level=2 or Level=3)]]",
      ]
    }
  }

  description = "Collects Active Directory Directory Service, DNS, and DFS events"

  tags = {
    Environment = "Learning"
    DataSource  = "ActiveDirectory"
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# DATA COLLECTION RULE - Extended Syslog
# ============================================================================

resource "azurerm_monitor_data_collection_rule" "syslog_extended" {
  name                = "dcr-syslog-extended"
  resource_group_name = var.resource_group_name
  location            = var.location

  destinations {
    log_analytics {
      workspace_resource_id = data.azurerm_log_analytics_workspace.sentinel.id
      name                  = "la-sentinel"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["la-sentinel"]
  }

  data_sources {
    syslog {
      facility_names = [
        "auth", "authpriv", "local0", "local1", "local2", "local3",
        "local4", "local5", "local6", "local7", "daemon", "syslog",
        "user", "kern", "cron"
      ]
      log_levels = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      name       = "syslog-homelab"
      streams    = ["Microsoft-Syslog"]
    }
  }

  description = "Extended syslog collection for homelab (Proxmox, Docker, OPNsense)"

  tags = {
    Environment = "Learning"
    DataSource  = "Syslog"
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# DCR ASSOCIATIONS - Domain Controllers
# ============================================================================

resource "azurerm_monitor_data_collection_rule_association" "dc_security" {
  for_each = var.domain_controllers

  name                    = "${each.value.name}-security-dcr-assoc"
  target_resource_id      = "/subscriptions/${var.subscription_id}/resourceGroups/${each.value.resource_group}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  data_collection_rule_id = azurerm_monitor_data_collection_rule.windows_security.id
  description             = "Association for ${each.value.name} to Windows Security DCR"
}

resource "azurerm_monitor_data_collection_rule_association" "dc_ad" {
  for_each = var.domain_controllers

  name                    = "${each.value.name}-ad-dcr-assoc"
  target_resource_id      = "/subscriptions/${var.subscription_id}/resourceGroups/${each.value.resource_group}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  data_collection_rule_id = azurerm_monitor_data_collection_rule.ad_directory_service.id
  description             = "Association for ${each.value.name} to AD Directory Service DCR"
}

# ============================================================================
# SENTINEL ANALYTICS RULES
# ============================================================================

resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "brute-force-detection"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Brute Force Attack - Multiple Failed Logons"
  description                = "Detects multiple failed logon attempts from a single IP address"
  severity                   = "High"
  enabled                    = true

  query = <<-QUERY
    let threshold = ${var.brute_force_threshold};
    SecurityEvent
    | where TimeGenerated > ago(1h)
    | where EventID == 4625
    | where LogonType in (3, 10)
    | summarize FailedAttempts = count(), TargetAccounts = make_set(TargetUserName, 100) by IpAddress, Computer
    | where FailedAttempts > threshold
    | project TimeGenerated = now(), IpAddress, Computer, FailedAttempts, TargetAccounts
  QUERY

  query_frequency = "PT5M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["CredentialAccess"]
  techniques = ["T1110"]

  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT5H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
      group_by_entities       = ["IP"]
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "IpAddress"
    }
  }

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "sensitive_group_change" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "sensitive-group-modification"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Sensitive Group Membership Changed"
  description                = "Detects changes to high-privilege groups"
  severity                   = "High"
  enabled                    = true

  query = <<-QUERY
    let sensitiveGroups = dynamic(["Domain Admins", "Enterprise Admins", "Schema Admins", "Administrators"]);
    SecurityEvent
    | where TimeGenerated > ago(1h)
    | where EventID in (4728, 4729, 4732, 4733, 4756, 4757)
    | where TargetUserName has_any (sensitiveGroups)
    | extend Action = case(EventID in (4728, 4732, 4756), "Member Added", EventID in (4729, 4733, 4757), "Member Removed", "Unknown")
    | project TimeGenerated, Action, GroupName = TargetUserName, MemberChanged = MemberName, ChangedBy = SubjectUserName, Computer
  QUERY

  query_frequency = "PT5M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["PrivilegeEscalation", "Persistence"]
  techniques = ["T1098"]

  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier  = "Name"
      column_name = "MemberChanged"
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "log_cleared" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "security-log-cleared"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Security Event Log Cleared"
  description                = "Detects when the Security event log is cleared"
  severity                   = "High"
  enabled                    = true

  query = <<-QUERY
    SecurityEvent
    | where TimeGenerated > ago(24h)
    | where EventID == 1102
    | project TimeGenerated, SubjectUserName, SubjectDomainName, Computer
  QUERY

  query_frequency = "PT1H"
  query_period    = "P1D"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["DefenseEvasion"]
  techniques = ["T1070"]

  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier  = "Name"
      column_name = "SubjectUserName"
    }
  }

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "windows_dce_id" {
  description = "Windows Data Collection Endpoint ID"
  value       = azurerm_monitor_data_collection_endpoint.windows.id
}

output "windows_security_dcr_id" {
  description = "Windows Security DCR ID"
  value       = azurerm_monitor_data_collection_rule.windows_security.id
}

output "ad_events_dcr_id" {
  description = "Active Directory Events DCR ID"
  value       = azurerm_monitor_data_collection_rule.ad_directory_service.id
}

output "syslog_dcr_id" {
  description = "Extended Syslog DCR ID"
  value       = azurerm_monitor_data_collection_rule.syslog_extended.id
}

output "workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = data.azurerm_log_analytics_workspace.sentinel.workspace_id
}
