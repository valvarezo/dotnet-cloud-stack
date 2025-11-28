# =============================================================================
# Aplicación Financiera - Infraestructura de Producción
# Despliegue en Azure Cloud con Terraform
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Configuración de backend para gestión de estado
  # Descomentar y configurar para uso en producción
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "stterraformstate"
  #   container_name       = "tfstate"
  #   key                  = "finance-app/prod/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Variables
variable "environment" {
  description = "Nombre del ambiente"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "eastus2"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "finance"
}

# Valores locales
locals {
  resource_group_name = "rg-${var.project_name}-${var.environment}"
  cluster_name        = "aks-${var.project_name}-${var.environment}"
  acr_name            = "acr${var.project_name}${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "equipo-devops"
  }
}

# Sufijo aleatorio para nombres únicos globalmente
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Grupo de Recursos
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Módulo de Networking
module "networking" {
  source = "../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  vnet_address_space  = ["10.0.0.0/16"]
  aks_subnet_prefix   = "10.0.1.0/24"
  tags                = local.common_tags
}

# Módulo de Azure Container Registry
module "acr" {
  source = "../modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  acr_name            = "${local.acr_name}${random_string.suffix.result}"
  sku                 = "Standard"
  admin_enabled       = false
  tags                = local.common_tags
}

# Módulo de AKS
module "aks" {
  source = "../modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  cluster_name        = local.cluster_name
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = "1.29"
  subnet_id           = module.networking.aks_subnet_id
  acr_id              = module.acr.acr_id

  default_node_pool = {
    name                = "system"
    node_count          = 2
    vm_size             = "Standard_D2s_v3"
    os_disk_size_gb     = 100
    max_pods            = 110
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 5
  }

  tags = local.common_tags

  depends_on = [
    module.networking,
    module.acr
  ]
}

# Outputs
output "resource_group_name" {
  description = "Nombre del grupo de recursos"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "Nombre del clúster AKS"
  value       = module.aks.cluster_name
}

output "aks_cluster_fqdn" {
  description = "FQDN del clúster AKS"
  value       = module.aks.cluster_fqdn
}

output "acr_login_server" {
  description = "URL del servidor de inicio de sesión de ACR"
  value       = module.acr.acr_login_server
}

output "vnet_id" {
  description = "ID de la red virtual"
  value       = module.networking.vnet_id
}

output "get_credentials_command" {
  description = "Comando para obtener credenciales de AKS"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks.cluster_name}"
}
