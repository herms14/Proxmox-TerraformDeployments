# ==============================================================================
# Sentinel Analytics Rules for Syslog/Linux Events
# ==============================================================================
# Detection rules for homelab Linux systems, network devices, and containers
#
# Data Sources:
#   - Proxmox nodes (auth, kernel, system logs)
#   - Docker hosts (daemon, container logs)
#   - OPNsense firewall (filterlog, ipsec logs)
#   - Omada network controller
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Linux Authentication Rules
# ------------------------------------------------------------------------------

resource "azurerm_sentinel_alert_rule_scheduled" "ssh_brute_force" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "ssh-brute-force-detection"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "SSH Brute Force Attack Detected"
  description                = "Detects multiple failed SSH authentication attempts from a single IP"
  severity                   = "High"
  enabled                    = true

  query = <<-QUERY
    Syslog
    | where TimeGenerated > ago(1h)
    | where Facility in ("auth", "authpriv")
    | where SyslogMessage has "Failed password"
    | parse SyslogMessage with * "Failed password for " TargetUser " from " SourceIP " port" *
    | summarize
        FailedAttempts = count(),
        TargetUsers = make_set(TargetUser, 20),
        UniqueUsers = dcount(TargetUser)
      by SourceIP, Computer
    | where FailedAttempts > 10
    | project
        TimeGenerated = now(),
        SourceIP,
        Computer,
        FailedAttempts,
        UniqueUsers,
        TargetUsers,
        AlertTitle = strcat("SSH Brute Force: ", FailedAttempts, " failed attempts from ", SourceIP)
  QUERY

  query_frequency = "PT5M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["CredentialAccess", "InitialAccess"]
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
      column_name = "SourceIP"
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

resource "azurerm_sentinel_alert_rule_scheduled" "successful_ssh_from_new_ip" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "ssh-success-new-ip"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "SSH Login from New IP Address"
  description                = "Detects successful SSH logins from IP addresses not seen in the last 7 days"
  severity                   = "Medium"
  enabled                    = true

  query = <<-QUERY
    // Get baseline of known IPs from last 7 days
    let knownIPs = Syslog
    | where TimeGenerated between (ago(7d) .. ago(1h))
    | where Facility == "authpriv"
    | where SyslogMessage has "Accepted"
    | parse SyslogMessage with * "from " SourceIP " port" *
    | distinct SourceIP;
    // Find new IPs in the last hour
    Syslog
    | where TimeGenerated > ago(1h)
    | where Facility == "authpriv"
    | where SyslogMessage has "Accepted"
    | parse SyslogMessage with * "Accepted " AuthMethod " for " User " from " SourceIP " port" *
    | where isnotempty(SourceIP)
    | where SourceIP !in (knownIPs)
    | project
        TimeGenerated,
        User,
        SourceIP,
        AuthMethod,
        Computer
  QUERY

  query_frequency = "PT15M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["InitialAccess"]
  techniques = ["T1078"]

  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier  = "Name"
      column_name = "User"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "SourceIP"
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "sudo_to_root" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "sudo-privilege-escalation"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Sudo Command to Root Shell"
  description                = "Detects sudo commands that spawn a root shell"
  severity                   = "Medium"
  enabled                    = true

  query = <<-QUERY
    Syslog
    | where TimeGenerated > ago(1h)
    | where ProcessName == "sudo"
    | where SyslogMessage has_any ("COMMAND=/bin/bash", "COMMAND=/bin/sh", "COMMAND=/usr/bin/su")
    | parse SyslogMessage with User " : TTY=" TTY " ; PWD=" PWD " ; USER=" TargetUser " ; COMMAND=" Command
    | project
        TimeGenerated,
        User,
        TargetUser,
        Command,
        Computer
  QUERY

  query_frequency = "PT5M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["PrivilegeEscalation"]
  techniques = ["T1548"]

  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier  = "Name"
      column_name = "User"
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

# ------------------------------------------------------------------------------
# Proxmox/Infrastructure Rules
# ------------------------------------------------------------------------------

resource "azurerm_sentinel_alert_rule_scheduled" "proxmox_critical_error" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "proxmox-critical-error"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Proxmox Critical Error Detected"
  description                = "Detects critical errors from Proxmox nodes"
  severity                   = "High"
  enabled                    = true

  query = <<-QUERY
    Syslog
    | where TimeGenerated > ago(1h)
    | where Computer has_any ("node01", "node02", "node03", "pve")
    | where SeverityLevel in ("crit", "alert", "emerg")
    | project
        TimeGenerated,
        Computer,
        Facility,
        ProcessName,
        SeverityLevel,
        SyslogMessage
    | order by TimeGenerated desc
  QUERY

  query_frequency = "PT5M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["Impact"]
  techniques = ["T1499"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }
}

# ------------------------------------------------------------------------------
# Network/Firewall Rules (OPNsense)
# ------------------------------------------------------------------------------

resource "azurerm_sentinel_alert_rule_scheduled" "firewall_port_scan" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "firewall-port-scan-detection"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Potential Port Scan Detected"
  description                = "Detects potential port scanning activity from firewall block logs"
  severity                   = "Medium"
  enabled                    = true

  query = <<-QUERY
    Syslog
    | where TimeGenerated > ago(1h)
    | where Facility == "local4" or Computer has "opnsense"
    | where SyslogMessage has "block"
    | parse SyslogMessage with * "SRC=" SourceIP " DST=" DestIP " " * "DPT=" DestPort " " *
    | where isnotempty(SourceIP) and isnotempty(DestPort)
    | summarize
        BlockedConnections = count(),
        UniqueDestPorts = dcount(DestPort),
        DestPorts = make_set(DestPort, 50),
        TargetIPs = make_set(DestIP)
      by SourceIP, bin(TimeGenerated, 5m)
    | where UniqueDestPorts > 10  // Scanning multiple ports
    | project
        TimeGenerated,
        SourceIP,
        BlockedConnections,
        UniqueDestPorts,
        DestPorts,
        TargetIPs
  QUERY

  query_frequency = "PT10M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["Discovery", "Reconnaissance"]
  techniques = ["T1046"]

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "SourceIP"
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "vpn_connection_failure" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "vpn-connection-failure"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "VPN Connection Failure"
  description                = "Detects failed VPN (IPsec/OpenVPN) connection attempts"
  severity                   = "Low"
  enabled                    = true

  query = <<-QUERY
    Syslog
    | where TimeGenerated > ago(24h)
    | where ProcessName has_any ("ipsec", "openvpn", "charon", "strongswan")
    | where SyslogMessage has_any ("failed", "error", "rejected", "timeout")
    | summarize
        FailureCount = count(),
        Messages = make_set(SyslogMessage, 10)
      by Computer, bin(TimeGenerated, 1h)
    | where FailureCount > 5
    | project
        TimeGenerated,
        Computer,
        FailureCount,
        Messages
  QUERY

  query_frequency = "PT1H"
  query_period    = "P1D"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["InitialAccess"]
  techniques = ["T1133"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }
}

# ------------------------------------------------------------------------------
# Network Device Rules (Omada)
# ------------------------------------------------------------------------------

resource "azurerm_sentinel_alert_rule_scheduled" "new_wireless_client" {
  count = var.enable_analytics_rules ? 1 : 0

  name                       = "new-wireless-client"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "New Wireless Client Connected"
  description                = "Detects new devices connecting to the wireless network"
  severity                   = "Informational"
  enabled                    = true

  query = <<-QUERY
    Syslog
    | where TimeGenerated > ago(1h)
    | where Facility == "local0"
    | where SyslogMessage has_any ("associated", "new client", "connected")
    | extend MAC = extract(@"([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}", 0, SyslogMessage)
    | where isnotempty(MAC)
    | summarize
        FirstSeen = min(TimeGenerated),
        ConnectionCount = count()
      by MAC, Computer
    | project
        TimeGenerated = FirstSeen,
        MAC,
        Computer,
        ConnectionCount
  QUERY

  query_frequency = "PT15M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  suppression_enabled  = true
  suppression_duration = "P1D"

  tactics    = ["InitialAccess", "Discovery"]
  techniques = ["T1078"]
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "syslog_analytics_rules" {
  description = "List of deployed syslog analytics rules"
  value = var.enable_analytics_rules ? [
    "ssh-brute-force-detection",
    "ssh-success-new-ip",
    "sudo-privilege-escalation",
    "proxmox-critical-error",
    "firewall-port-scan-detection",
    "vpn-connection-failure",
    "new-wireless-client"
  ] : []
}
