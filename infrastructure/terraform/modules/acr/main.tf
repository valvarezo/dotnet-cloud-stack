# =============================================================================
# Azure Container Registry Module
# Creates ACR with security best practices
# =============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique)"
  type        = string
}

variable "sku" {
  description = "SKU for the ACR (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

variable "admin_enabled" {
  description = "Enable admin user for ACR"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  # Enable content trust for image signing (Premium only)
  dynamic "trust_policy" {
    for_each = var.sku == "Premium" ? [1] : []
    content {
      enabled = true
    }
  }

  # Enable retention policy (Premium only)
  dynamic "retention_policy" {
    for_each = var.sku == "Premium" ? [1] : []
    content {
      days    = 30
      enabled = true
    }
  }

  tags = merge(var.tags, {
    Environment = var.environment
    Component   = "container-registry"
  })
}

# Diagnostic settings (if Log Analytics is available)
# resource "azurerm_monitor_diagnostic_setting" "acr" {
#   name                       = "diag-${var.acr_name}"
#   target_resource_id         = azurerm_container_registry.main.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   log {
#     category = "ContainerRegistryRepositoryEvents"
#     enabled  = true
#   }
#
#   log {
#     category = "ContainerRegistryLoginEvents"
#     enabled  = true
#   }
#
#   metric {
#     category = "AllMetrics"
#     enabled  = true
#   }
# }

# Outputs
output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = azurerm_container_registry.main.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Login server URL for the ACR"
  value       = azurerm_container_registry.main.login_server
}

output "acr_admin_username" {
  description = "Admin username (if enabled)"
  value       = var.admin_enabled ? azurerm_container_registry.main.admin_username : null
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password (if enabled)"
  value       = var.admin_enabled ? azurerm_container_registry.main.admin_password : null
  sensitive   = true
}
