# ==============================================================================
# Windows Data Collection Rule (DCR) for On-Premises Arc VMs
# ==============================================================================
# Collects Windows Event Logs from Arc-enabled Windows servers via VPN
#
# Target VMs (all on-prem Windows VMs):
#   - DC01, DC02 (Domain Controllers)
#   - FS01, FS02 (File Servers)
#   - SQL01, SQL-FABRIC (SQL Servers)
#   - AADCON01, AADPP01, AADPP02 (Identity)
#   - IIS01, IIS02 (Web Servers)
#   - CLIENT01, CLIENT02 (Workstations)

# ------------------------------------------------------------------------------
# Data Collection Endpoint (DCE) for Windows
# ------------------------------------------------------------------------------

resource "azurerm_monitor_data_collection_endpoint" "windows" {
  name                          = "dce-homelab-windows"
  resource_group_name           = data.azurerm_resource_group.sentinel.name
  location                      = var.location
  kind                          = "Windows"
  public_network_access_enabled = true  # Can be disabled if using private endpoints
  description                   = "Data Collection Endpoint for homelab Windows VMs via VPN"

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Data Collection Rule (DCR) for Windows Security Events
# ------------------------------------------------------------------------------

resource "azurerm_monitor_data_collection_rule" "windows_security" {
  name                        = "dcr-homelab-windows-security"
  resource_group_name         = data.azurerm_resource_group.sentinel.name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.windows.id
  description                 = "Collects Windows Security events from on-prem Arc VMs"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.sentinel.id
      name                  = "sentinel-windows-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-SecurityEvent"]
    destinations = ["sentinel-windows-destination"]
  }

  data_sources {
    windows_event_log {
      streams = ["Microsoft-SecurityEvent"]
      x_path_queries = [
        # Authentication Events
        "Security!*[System[(EventID=4624)]]",  # Successful logon
        "Security!*[System[(EventID=4625)]]",  # Failed logon
        "Security!*[System[(EventID=4648)]]",  # Explicit credential logon
        "Security!*[System[(EventID=4634)]]",  # Logoff
        "Security!*[System[(EventID=4647)]]",  # User-initiated logoff

        # Account Management
        "Security!*[System[(EventID=4720)]]",  # User account created
        "Security!*[System[(EventID=4722)]]",  # User account enabled
        "Security!*[System[(EventID=4724)]]",  # Password reset attempt
        "Security!*[System[(EventID=4726)]]",  # User account deleted
        "Security!*[System[(EventID=4728)]]",  # Member added to security group
        "Security!*[System[(EventID=4732)]]",  # Member added to local group
        "Security!*[System[(EventID=4756)]]",  # Member added to universal group

        # Privileged Operations
        "Security!*[System[(EventID=4672)]]",  # Special privileges assigned
        "Security!*[System[(EventID=4673)]]",  # Privileged service called
        "Security!*[System[(EventID=4674)]]",  # Privileged operation attempted

        # AD DS Changes
        "Security!*[System[(EventID=5136)]]",  # Directory object modified
        "Security!*[System[(EventID=5137)]]",  # Directory object created
        "Security!*[System[(EventID=5141)]]",  # Directory object deleted

        # Policy Changes
        "Security!*[System[(EventID=4713)]]",  # Kerberos policy changed
        "Security!*[System[(EventID=4719)]]",  # System audit policy changed
        "Security!*[System[(EventID=4739)]]",  # Domain policy changed
      ]
      name = "windowsSecurityEvents"
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Data Collection Rule (DCR) for Windows System/Application Events
# ------------------------------------------------------------------------------

resource "azurerm_monitor_data_collection_rule" "windows_events" {
  name                        = "dcr-homelab-windows-events"
  resource_group_name         = data.azurerm_resource_group.sentinel.name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.windows.id
  description                 = "Collects Windows System and Application events from on-prem Arc VMs"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.sentinel.id
      name                  = "sentinel-events-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Event"]
    destinations = ["sentinel-events-destination"]
  }

  data_sources {
    windows_event_log {
      streams = ["Microsoft-Event"]
      x_path_queries = [
        # System Events - Errors and Warnings
        "System!*[System[(Level=1 or Level=2 or Level=3)]]",

        # Application Events - Errors and Warnings
        "Application!*[System[(Level=1 or Level=2 or Level=3)]]",

        # Active Directory Web Services
        "Microsoft-Windows-ADWS/Debug!*[System[(Level=1 or Level=2 or Level=3)]]",

        # Directory Service
        "Directory Service!*[System[(Level=1 or Level=2 or Level=3)]]",

        # DNS Server
        "DNS Server!*[System[(Level=1 or Level=2 or Level=3)]]",

        # Windows Firewall
        "Microsoft-Windows-Windows Firewall With Advanced Security/Firewall!*[System[(Level=1 or Level=2 or Level=3)]]",
      ]
      name = "windowsSystemEvents"
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# DCR for Active Directory Domain Controller Specific Events
# ------------------------------------------------------------------------------

resource "azurerm_monitor_data_collection_rule" "windows_dc" {
  name                        = "dcr-homelab-windows-dc"
  resource_group_name         = data.azurerm_resource_group.sentinel.name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.windows.id
  description                 = "Collects Domain Controller specific events from DC01, DC02, and Azure DCs"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.sentinel.id
      name                  = "sentinel-dc-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-SecurityEvent"]
    destinations = ["sentinel-dc-destination"]
  }

  data_sources {
    windows_event_log {
      streams = ["Microsoft-SecurityEvent"]
      x_path_queries = [
        # Kerberos
        "Security!*[System[(EventID=4768)]]",  # Kerberos TGT request
        "Security!*[System[(EventID=4769)]]",  # Kerberos service ticket request
        "Security!*[System[(EventID=4771)]]",  # Kerberos pre-auth failed

        # NTLM
        "Security!*[System[(EventID=4776)]]",  # NTLM authentication

        # Group Policy
        "Microsoft-Windows-GroupPolicy/Operational!*[System[(Level=1 or Level=2 or Level=3)]]",

        # AD Replication
        "DFS Replication!*[System[(Level=1 or Level=2 or Level=3)]]",

        # DNS
        "DNS Server!*[System[(EventID=150 or EventID=408 or EventID=409)]]",
      ]
      name = "domainControllerEvents"
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Sentinel Alert Rules for Windows Events
# ------------------------------------------------------------------------------

# Multiple Failed Logons Detection
resource "azurerm_sentinel_alert_rule_scheduled" "windows_brute_force" {
  name                       = "windows-brute-force-detection"
  display_name               = "Potential Brute Force Attack (Windows)"
  description                = "Detects multiple failed logon attempts on Windows servers"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  severity                   = "Medium"
  enabled                    = true

  query = <<-QUERY
    SecurityEvent
    | where EventID == 4625
    | summarize FailedAttempts = count() by TargetAccount, Computer, IpAddress, bin(TimeGenerated, 5m)
    | where FailedAttempts > 5
  QUERY

  query_frequency = "PT5M"
  query_period    = "PT5M"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  suppression_enabled  = true
  suppression_duration = "PT1H"

  tactics = ["CredentialAccess", "InitialAccess"]

  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT5H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
}

# New Admin User Created
resource "azurerm_sentinel_alert_rule_scheduled" "new_admin_user" {
  name                       = "new-admin-user-created"
  display_name               = "New Administrator Account Created"
  description                = "Detects when a new user is added to privileged groups"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  severity                   = "High"
  enabled                    = true

  query = <<-QUERY
    SecurityEvent
    | where EventID in (4728, 4732, 4756)
    | where TargetUserName contains "Admin" or TargetUserName contains "Domain Admins" or TargetUserName contains "Enterprise Admins"
    | project TimeGenerated, Computer, Account, TargetUserName, MemberName, Activity
  QUERY

  query_frequency = "PT5M"
  query_period    = "PT5M"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  suppression_enabled  = false
  suppression_duration = "PT1H"

  tactics = ["Persistence", "PrivilegeEscalation"]

  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT1H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
}

# Privileged Logon Detection
resource "azurerm_sentinel_alert_rule_scheduled" "privileged_logon" {
  name                       = "privileged-logon-detection"
  display_name               = "Privileged Account Logon"
  description                = "Tracks logons by privileged accounts for auditing"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  severity                   = "Informational"
  enabled                    = true

  query = <<-QUERY
    SecurityEvent
    | where EventID == 4672
    | summarize count() by Account, Computer, bin(TimeGenerated, 1h)
    | where count_ > 0
  QUERY

  query_frequency = "PT1H"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 5

  suppression_enabled  = true
  suppression_duration = "PT6H"

  tactics = ["PrivilegeEscalation"]

  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT24H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "windows_dce_id" {
  description = "Windows Data Collection Endpoint ID"
  value       = azurerm_monitor_data_collection_endpoint.windows.id
}

output "windows_security_dcr_id" {
  description = "Windows Security DCR ID"
  value       = azurerm_monitor_data_collection_rule.windows_security.id
}

output "windows_events_dcr_id" {
  description = "Windows Events DCR ID"
  value       = azurerm_monitor_data_collection_rule.windows_events.id
}

output "windows_dc_dcr_id" {
  description = "Domain Controller DCR ID"
  value       = azurerm_monitor_data_collection_rule.windows_dc.id
}
