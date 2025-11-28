---
sidebar_position: 2
---

# Infraestructura Azure con Terraform

## Estructura del Proyecto

```
infrastructure/terraform/
├── modules/
│   ├── networking/     # VNet, Subredes, NSGs
│   ├── acr/           # Azure Container Registry
│   └── aks/           # Azure Kubernetes Service
└── environments/
    └── prod/          # Configuración de producción
        ├── main.tf
        └── terraform.tfvars
```

## Módulos

### 1. Módulo de Networking

Crea la infraestructura de red base:

| Recurso | Descripción |
|---------|-------------|
| VNet | Red virtual con espacio de direcciones 10.0.0.0/16 |
| Subred AKS | Subred para nodos de AKS (10.0.1.0/24) |
| NSG | Grupo de Seguridad de Red con reglas para HTTP/HTTPS |

```hcl
module "networking" {
  source = "../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  vnet_address_space  = ["10.0.0.0/16"]
  aks_subnet_prefix   = "10.0.1.0/24"
}
```

### 2. Módulo ACR

Azure Container Registry para almacenar imágenes Docker:

| Configuración | Valor |
|---------------|-------|
| SKU | Standard |
| Admin Habilitado | false (usar identidad administrada) |
| Política de Retención | 30 días (Premium) |

```hcl
module "acr" {
  source = "../modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  acr_name            = "acrfinanceprod${random_string.suffix.result}"
  sku                 = "Standard"
}
```

### 3. Módulo AKS

Clúster de Kubernetes administrado:

| Configuración | Valor |
|---------------|-------|
| Versión de Kubernetes | 1.29 |
| Plugin de Red | Azure CNI |
| Política de Red | Azure |
| Pools de Nodos | Sistema (2-5 nodos) + Cargas de trabajo (1-10 nodos) |

```hcl
module "aks" {
  source = "../modules/aks"

  cluster_name       = "aks-finance-prod"
  kubernetes_version = "1.29"
  
  default_node_pool = {
    name                = "system"
    vm_size             = "Standard_D2s_v3"
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 5
  }
}
```

## Diagrama de Recursos Azure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 Grupo de Recursos: rg-finance-prod                       │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                Red Virtual: vnet-finance-prod                        ││
│  │                  Espacio de Direcciones: 10.0.0.0/16                 ││
│  │                                                                      ││
│  │  ┌─────────────────────────────────────────────────────────────────┐││
│  │  │            Subred: snet-aks-prod (10.0.1.0/24)                  │││
│  │  │                                                                  │││
│  │  │  ┌───────────────────────────────────────────────────────────┐ │││
│  │  │  │            Clúster AKS: aks-finance-prod                   │ │││
│  │  │  │                                                            │ │││
│  │  │  │  ┌─────────────────┐      ┌─────────────────────────────┐│ │││
│  │  │  │  │  Pool Sistema   │      │    Pool Cargas de Trabajo   ││ │││
│  │  │  │  │   Standard_D2s  │      │       Standard_D4s          ││ │││
│  │  │  │  │   2-5 nodos     │      │       1-10 nodos            ││ │││
│  │  │  │  └─────────────────┘      └─────────────────────────────┘│ │││
│  │  │  │                                                            │ │││
│  │  │  │  ┌─────────────────────────────────────────────────────┐ │ │││
│  │  │  │  │        Identidad Administrada (Kubelet)              │ │ │││
│  │  │  │  │              Rol: AcrPull                            │ │ │││
│  │  │  │  └─────────────────────────────────────────────────────┘ │ │││
│  │  │  └───────────────────────────────────────────────────────────┘ │││
│  │  │                                                                  │││
│  │  │  ┌─────────────────────────────────────────────────────────────┐│││
│  │  │  │ Grupo de Seguridad de Red: nsg-aks-prod                     ││││
│  │  │  │     Reglas: Permitir HTTP (80), HTTPS (443)                 ││││
│  │  │  └─────────────────────────────────────────────────────────────┘│││
│  │  └─────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│  ┌─────────────────────────┐    ┌─────────────────────────────────────┐│
│  │  Azure Container        │    │  Espacio de Trabajo Log Analytics   ││
│  │  Registry               │    │     log-aks-finance-prod            ││
│  │  acrfinanceprodxxxx     │    │     Retención: 30 días              ││
│  │  SKU: Standard          │    │                                     ││
│  └─────────────────────────┘    └─────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

## Despliegue

### Requisitos Previos

```bash
# Instalar Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Iniciar sesión en Azure
az login

# Seleccionar suscripción
az account set --subscription "TU_ID_DE_SUSCRIPCION"
```

### Comandos de Terraform

```bash
# Navegar al directorio de producción
cd infrastructure/terraform/environments/prod

# Inicializar Terraform
terraform init

# Validar configuración
terraform validate

# Ver plan de cambios
terraform plan -out=tfplan

# Aplicar cambios
terraform apply tfplan

# Ver outputs
terraform output
```

### Conectar a AKS

```bash
# Obtener credenciales de AKS
az aks get-credentials \
  --resource-group rg-finance-prod \
  --name aks-finance-prod

# Verificar conexión
kubectl get nodes
```

### Subir imagen a ACR

```bash
# Iniciar sesión en ACR
az acr login --name acrfinanceprodxxxx

# Etiquetar la imagen
docker tag finance-api:latest acrfinanceprodxxxx.azurecr.io/finance-api:v1.0.0

# Subir imagen
docker push acrfinanceprodxxxx.azurecr.io/finance-api:v1.0.0
```

## Backend de Estado (Producción)

Para producción, configurar backend remoto:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "finance-app/prod/terraform.tfstate"
  }
}
```

Crear cuenta de almacenamiento:

```bash
# Crear grupo de recursos para el estado
az group create -n rg-terraform-state -l eastus2

# Crear cuenta de almacenamiento
az storage account create \
  -n stterraformstate \
  -g rg-terraform-state \
  -l eastus2 \
  --sku Standard_LRS

# Crear contenedor
az storage container create \
  -n tfstate \
  --account-name stterraformstate
```

## Outputs

| Output | Descripción |
|--------|-------------|
| `resource_group_name` | Nombre del grupo de recursos |
| `aks_cluster_name` | Nombre del clúster AKS |
| `aks_cluster_fqdn` | FQDN del clúster |
| `acr_login_server` | URL del ACR |
| `get_credentials_command` | Comando para obtener kubeconfig |

## Costos Estimados

| Recurso | SKU | Costo Mensual Estimado |
|---------|-----|------------------------|
| AKS (Pool Sistema) | D2s_v3 x2 | ~$140 USD |
| AKS (Pool Cargas) | D4s_v3 x2 | ~$280 USD |
| ACR | Standard | ~$20 USD |
| Log Analytics | Por GB | ~$30 USD |
| **Total** | | **~$470 USD/mes** |

*Precios aproximados para la región East US 2. Usar la Calculadora de Precios de Azure para estimaciones precisas.*
