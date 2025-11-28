# 🏦 Finance Cloud Stack

Arquitectura de despliegue cloud-native para una aplicación financiera de tres capas con Service Mesh.

[![.NET](https://img.shields.io/badge/.NET-9.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![Istio](https://img.shields.io/badge/Istio-1.28-466BB0?logo=istio)](https://istio.io/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-7B42BC?logo=terraform)](https://www.terraform.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?logo=argo)](https://argoproj.github.io/cd/)

## 📋 Tabla de Contenidos

- [Visión General](#-visión-general)
- [Arquitectura](#-arquitectura)
- [Inicio Rápido](#-inicio-rápido)
- [Service Mesh (Istio)](#-service-mesh-istio)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Documentación](#-documentación)
- [Desarrollo](#-desarrollo)
- [Decisiones Técnicas](#-decisiones-técnicas)

## 🎯 Visión General

Este proyecto implementa una solución completa de infraestructura para una organización financiera que moderniza su stack tecnológico:

| Componente | Tecnología | Propósito |
|------------|------------|-----------|
| **Backend** | .NET 9 API | Lógica de negocio y endpoints REST |
| **Base de Datos** | PostgreSQL 16 | Persistencia de transacciones |
| **Frontend** | Swagger UI | Interfaz de usuario integrada |
| **Orquestación** | Kubernetes | Contenedores y escalabilidad |
| **Service Mesh** | Istio 1.28 | mTLS, observabilidad, control de tráfico |
| **GitOps** | ArgoCD | Despliegue continuo declarativo |
| **IaC** | Terraform | Infraestructura en Azure |

## 🏗 Arquitectura

![Arquitectura de Solución](docs/architecture/images/finance-cloud-stack-arquitectura-solucion.png)

### Componentes principales

| Componente | Descripción |
|------------|-------------|
| **NGINX Ingress** | Punto de entrada HTTP/HTTPS (app.local) |
| **Istio Service Mesh** | mTLS automático, observabilidad, control de tráfico |
| **Finance API (.NET 9)** | API REST con endpoints /health, /health/db, /api/transactions |
| **PostgreSQL 16** | Base de datos con persistencia (PVC 5Gi) |
| **ArgoCD** | GitOps para despliegue continuo |
| **Terraform** | Infrastructure as Code para Azure |

### Flujo de tráfico

```
Usuario → HTTPS → NGINX Ingress → Envoy Sidecar → .NET 9 API → Envoy Sidecar → PostgreSQL
                                        ↑                            ↑
                                        └────────── mTLS ────────────┘
```

### Endpoints de la API

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/health` | Verificación de salud del servicio |
| `GET` | `/health/db` | Verificación de conectividad con BD |
| `GET` | `/api/transactions` | Listar transacciones |
| `POST` | `/api/transactions` | Crear nueva transacción |
| `GET` | `/swagger` | Interfaz Swagger UI |

## 🚀 Inicio Rápido

### Requisitos Previos

- Docker Desktop o Docker Engine
- Minikube v1.32+ (con mínimo 8GB RAM para Istio)
- kubectl v1.29+
- Git Bash (Windows) o Terminal (macOS/Linux)

### Despliegue en Minikube

```bash
# 1. Clonar el repositorio
git clone https://github.com/tu-organizacion/dotnet-cloud-stack.git
cd dotnet-cloud-stack

# 2. Iniciar Minikube con recursos suficientes para Istio
minikube start --memory=8192 --cpus=4 --driver=docker

# 3. Ejecutar script de despliegue
chmod +x scripts/deploy-minikube.sh
./scripts/deploy-minikube.sh

# 4. Instalar Istio Service Mesh (opcional pero recomendado)
chmod +x scripts/setup-istio.sh
./scripts/setup-istio.sh

# 5. Agregar entrada a /etc/hosts
echo "$(minikube ip)  app.local api.local" | sudo tee -a /etc/hosts

# 6. En otra terminal, iniciar túnel
minikube tunnel

# 7. Acceder a la aplicación
open http://app.local
```

### Verificar el despliegue

```bash
# Ver pods (deben mostrar 2/2 con Istio)
kubectl get pods -n finance-app

# Probar endpoints
kubectl port-forward svc/finance-api 8080:80 -n finance-app

# En otra terminal
curl http://localhost:8080/health
curl http://localhost:8080/health/db
```

### Despliegue con ArgoCD

```bash
# Instalar ArgoCD
chmod +x scripts/setup-argocd.sh
./scripts/setup-argocd.sh

# Acceder a la interfaz de ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8443:443
# https://localhost:8443
```

## 🕸 Service Mesh (Istio)

### Características habilitadas

| Característica | Descripción |
|----------------|-------------|
| **mTLS Strict** | Todo el tráfico entre servicios está cifrado automáticamente |
| **Authorization Policies** | Control de acceso entre servicios (Zero Trust) |
| **Circuit Breaker** | Protección contra cascada de fallos |
| **Retries automáticos** | Reintentos configurados para resiliencia |
| **Observabilidad** | Métricas, trazas y logs centralizados |

### Dashboards de observabilidad

```bash
# Kiali - Visualización del Service Mesh
istioctl dashboard kiali

# Grafana - Métricas y dashboards
istioctl dashboard grafana

# Jaeger - Trazas distribuidas
istioctl dashboard jaeger

# Prometheus - Queries de métricas
istioctl dashboard prometheus
```

### Verificar Istio

```bash
# Analizar configuración
istioctl analyze -n finance-app

# Ver estado de los proxies
istioctl proxy-status

# Ver configuración de un pod
istioctl proxy-config clusters <pod-name> -n finance-app
```

### Archivos de configuración de Istio

| Archivo | Propósito |
|---------|-----------|
| `peer-authentication.yaml` | Configuración de mTLS (STRICT) |
| `authorization-policy.yaml` | Control de acceso entre servicios |
| `destination-rules.yaml` | Circuit breaker, connection pooling |
| `virtual-service.yaml` | Timeouts, retries, traffic splitting |
| `gateway.yaml` | Punto de entrada para tráfico externo |

## 📁 Estructura del Proyecto

```
dotnet-cloud-stack/
├── 📂 docs/                          # Documentación para Docusaurus
│   ├── intro.md
│   ├── architecture/
│   │   └── overview.md
│   ├── infrastructure/
│   │   ├── kubernetes.md
│   │   └── terraform.md
│   ├── deployment/
│   │   ├── minikube.md
│   │   └── argocd.md
│   └── service-mesh/                 
│       ├── istio.md
│       └── configuracion-avanzada.md
├── 📂 src/
│   └── backend/                      # API .NET 9
│       ├── Program.cs
│       ├── FinanceApi.csproj
│       ├── Dockerfile
│       └── appsettings.json
├── 📂 infrastructure/
│   ├── terraform/                    # IaC para Azure
│   │   ├── modules/
│   │   │   ├── aks/
│   │   │   ├── acr/
│   │   │   └── networking/
│   │   └── environments/
│   │       └── prod/
│   └── kubernetes/                   # Manifiestos K8s
│       ├── base/
│       │   ├── namespace.yaml
│       │   ├── configmap.yaml
│       │   ├── secret.yaml
│       │   ├── api-deployment.yaml
│       │   ├── api-service.yaml
│       │   ├── postgres-deployment.yaml
│       │   ├── postgres-service.yaml
│       │   ├── postgres-pvc.yaml
│       │   └── ingress.yaml
│       ├── overlays/
│       │   ├── dev/
│       │   └── prod/
│       └── istio/                    # Configuraciones de Istio
│           ├── kustomization.yaml
│           ├── namespace-injection.yaml
│           ├── service-accounts.yaml
│           ├── peer-authentication.yaml
│           ├── authorization-policy.yaml
│           ├── destination-rules.yaml
│           ├── virtual-service.yaml
│           └── gateway.yaml
├── 📂 helm/                          # Charts de Helm
│   └── dotnet-app/
├── 📂 argocd/                        # Configuración GitOps
│   ├── apps/
│   └── projects/
└── 📂 scripts/                       # Scripts de automatización
    ├── deploy-minikube.sh
    ├── setup-argocd.sh
    └── setup-istio.sh                # Instalación de Istio
```

## 📚 Documentación

| Documento | Descripción |
|-----------|-------------|
| [Arquitectura](docs/architecture/overview.md) | Diseño y decisiones técnicas |
| [Kubernetes](docs/infrastructure/kubernetes.md) | Manifiestos y configuración |
| [Terraform](docs/infrastructure/terraform.md) | Infraestructura en Azure |
| [Minikube](docs/deployment/minikube.md) | Guía de despliegue local |
| [ArgoCD](docs/deployment/argocd.md) | Configuración GitOps |
| [Istio](docs/service-mesh/istio.md) | Service Mesh y mTLS |
| [Configuración Avanzada](docs/service-mesh/configuracion-avanzada.md) | Canary, Circuit Breaker |

## 🛠 Desarrollo

### Construir imagen Docker

```bash
cd src/backend
docker build -t finance-api:v2 .

# Cargar en Minikube
minikube image load finance-api:v2
```

### Ejecutar localmente

```bash
cd src/backend
dotnet run
# API disponible en http://localhost:5000
```

### Aplicar cambios a Kubernetes

```bash
# Usando Kustomize (recomendado)
kubectl apply -k infrastructure/kubernetes/overlays/dev

# Aplicar configuraciones de Istio
kubectl apply -k infrastructure/kubernetes/istio

# Reiniciar pods para inyectar sidecars
kubectl rollout restart deployment -n finance-app

# Usando Helm
helm upgrade --install finance-app helm/dotnet-app -n finance-app
```

## 🔧 Decisiones Técnicas

### ¿Por qué PostgreSQL?

| Razón | Descripción |
|-------|-------------|
| **Open Source** | Sin costos de licencia |
| **Kubernetes** | Excelente soporte con operadores y Helm charts |
| **ACID** | Cumplimiento completo para transacciones financieras |
| **Azure** | Soporte nativo (Azure Database for PostgreSQL) |

### ¿Por qué Istio?

| Razón | Descripción |
|-------|-------------|
| **mTLS automático** | Cifrado sin cambios de código |
| **Observabilidad** | Métricas y trazas sin instrumentación |
| **Resiliencia** | Circuit breakers y retries automáticos |
| **Seguridad** | Authorization policies (Zero Trust) |
| **Madurez** | Proyecto CNCF graduado, usado en producción |

### ¿Por qué NO Alpine para .NET?

| Razón | Descripción |
|-------|-------------|
| **Compatibilidad** | Entity Framework tiene problemas con musl libc |
| **PublishTrimmed** | Rompe reflexión de EF Core y System.Text.Json |
| **Estabilidad** | Prioridad sobre tamaño mínimo en entorno financiero |
| **Imagen final** | ~220-250 MB con imagen estándar de Debian |

### ¿Por qué Kustomize sobre Helm?

| Razón | Descripción |
|-------|-------------|
| **Transparencia** | Manifiestos YAML legibles directamente |
| **Overlays** | Configuración clara por ambiente (dev/prod) |
| **Simplicidad** | Sin plantillas Go complejas |
| **GitOps** | Mejor integración con ArgoCD |

## 🔐 Seguridad

### Configuraciones implementadas

- ✅ **mTLS Strict** - Todo el tráfico interno cifrado
- ✅ **Authorization Policies** - Control de acceso entre servicios
- ✅ **Secrets de Kubernetes** - Credenciales no en código
- ✅ **ClusterIP** - Base de datos no expuesta externamente
- ✅ **Non-root containers** - Contenedores sin privilegios
- ✅ **Network Policies** - Segmentación de red (producción)

### Para producción adicional

```bash
# Habilitar Azure Key Vault
# Ver docs/infrastructure/terraform.md

# Configurar RBAC de Azure AD
# Ver docs/deployment/argocd.md
```

## 📊 Monitoreo

### Métricas disponibles con Istio

```promql
# Requests por segundo
rate(istio_requests_total{destination_service="finance-api.finance-app.svc.cluster.local"}[5m])

# Latencia p99
histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le))

# Tasa de errores
sum(rate(istio_requests_total{response_code=~"5.."}[5m])) / sum(rate(istio_requests_total[5m]))
```
---

**Desarrollado para TiendaPago Cloud Stack Test**