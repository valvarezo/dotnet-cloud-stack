# =============================================================================
# Azure Kubernetes Service Module
# Creates AKS cluster with security and monitoring best practices
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

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for AKS nodes"
  type        = string
}

variable "acr_id" {
  description = "ID of the Azure Container Registry"
  type        = string
}

variable "default_node_pool" {
  description = "Configuration for the default node pool"
  type = object({
    name                = string
    node_count          = number
    vm_size             = string
    os_disk_size_gb     = number
    max_pods            = number
    enable_auto_scaling = bool
    min_count           = number
    max_count           = number
  })
  default = {
    name                = "system"
    node_count          = 2
    vm_size             = "Standard_D2s_v3"
    os_disk_size_gb     = 100
    max_pods            = 110
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 5
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  # Default system node pool
  default_node_pool {
    name                = var.default_node_pool.name
    node_count          = var.default_node_pool.enable_auto_scaling ? null : var.default_node_pool.node_count
    vm_size             = var.default_node_pool.vm_size
    os_disk_size_gb     = var.default_node_pool.os_disk_size_gb
    max_pods            = var.default_node_pool.max_pods
    vnet_subnet_id      = var.subnet_id
    enable_auto_scaling = var.default_node_pool.enable_auto_scaling
    min_count           = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.min_count : null
    max_count           = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.max_count : null

    upgrade_settings {
      max_surge = "33%"
    }
  }

  # Managed identity
  identity {
    type = "SystemAssigned"
  }

  # Network configuration
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.1.0.0/16"
    dns_service_ip    = "10.1.0.10"
  }

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
  }

  # Monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Security
  api_server_access_profile {
    authorized_ip_ranges = ["0.0.0.0/0"]  # Restrict in production
  }

  # Auto-upgrade
  automatic_channel_upgrade = "patch"

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [0, 1, 2, 3, 4]
    }
  }

  tags = merge(var.tags, {
    Environment = var.environment
    Component   = "kubernetes"
  })

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = merge(var.tags, {
    Environment = var.environment
    Component   = "monitoring"
  })
}

# Attach ACR to AKS
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = var.acr_id
  skip_service_principal_aad_check = true
}

# User node pool for workloads
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D4s_v3"
  os_disk_size_gb       = 100
  max_pods              = 110
  vnet_subnet_id        = var.subnet_id
  enable_auto_scaling   = true
  min_count             = 1
  max_count             = 10
  mode                  = "User"

  node_labels = {
    "workload" = "app"
  }

  node_taints = []

  upgrade_settings {
    max_surge = "33%"
  }

  tags = merge(var.tags, {
    Environment = var.environment
    Component   = "kubernetes"
    NodePool    = "workload"
  })
}

# Outputs
output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "kubelet_identity" {
  description = "Kubelet managed identity"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0]
}

output "node_resource_group" {
  description = "Name of the node resource group"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}
