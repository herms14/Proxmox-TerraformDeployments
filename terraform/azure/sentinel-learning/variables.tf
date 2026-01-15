# Variables for Azure Sentinel Learning Infrastructure

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = "2212d587-1bad-4013-b605-b421b1f83c30"
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = "b6458a9a-9661-468c-bda3-5f496727d0b0"
}

variable "resource_group_name" {
  description = "Resource group for Sentinel resources"
  type        = string
  default     = "rg-homelab-sentinel"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "southeastasia"
}

variable "workspace_name" {
  description = "Log Analytics Workspace name"
  type        = string
  default     = "law-homelab-sentinel"
}

variable "domain_controllers" {
  description = "Map of domain controllers to monitor"
  type = map(object({
    name           = string
    ip             = string
    resource_group = string
  }))
  default = {
    azdc01 = {
      name           = "AZDC01"
      ip             = "10.10.4.4"
      resource_group = "RG-AZUREHYBRID-IDENTITY-PROD"
    }
    azdc02 = {
      name           = "AZDC02"
      ip             = "10.10.4.5"
      resource_group = "RG-AZUREHYBRID-IDENTITY-PROD"
    }
    azrodc01 = {
      name           = "AZRODC01"
      ip             = "10.10.4.6"
      resource_group = "RG-AZUREHYBRID-IDENTITY-PROD"
    }
    azrodc02 = {
      name           = "AZRODC02"
      ip             = "10.10.4.7"
      resource_group = "RG-AZUREHYBRID-IDENTITY-PROD"
    }
  }
}

variable "enable_analytics_rules" {
  description = "Enable deployment of Sentinel analytics rules"
  type        = bool
  default     = true
}

variable "brute_force_threshold" {
  description = "Threshold for brute force detection (failed logons per IP)"
  type        = number
  default     = 20
}

variable "enable_nsg_flow_logs" {
  description = "Enable NSG Flow Logs (requires storage account with shared key access)"
  type        = bool
  default     = false
}
