---
sidebar_position: 1
slug: /
---

# Finance Cloud Stack

Arquitectura de despliegue para una aplicación financiera de tres capas utilizando .NET, PostgreSQL y Kubernetes.

## 🎯 Visión General

Este proyecto implementa una solución completa de infraestructura cloud-native para una organización financiera que está modernizando su stack tecnológico. La arquitectura incluye:

- **Backend API**: .NET 9 con endpoints de salud y conectividad a base de datos
- **Base de Datos**: PostgreSQL 16 con persistencia de datos
- **Frontend**: Swagger UI integrado como interfaz de usuario
- **Orquestación**: Kubernetes (Minikube para desarrollo, AKS para producción)
- **GitOps**: ArgoCD para despliegue continuo
- **IaC**: Terraform para infraestructura en Azure

## 📋 Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                         INGRESS                                  │
│                    (app.local / api.local)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     FINANCE API (.NET 9)                         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   /health    │  │  /health/db  │  │  /api/transactions   │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                  │
│                     Swagger UI (Frontend)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     POSTGRESQL 16                                │
│                                                                  │
│           PersistentVolumeClaim (5Gi)                           │
│           Servicio ClusterIP (Solo Interno)                      │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Inicio Rápido

```bash
# Clonar el repositorio
git clone <url-del-repositorio>
cd dotnet-cloud-stack

# Desplegar en Minikube
chmod +x scripts/deploy-minikube.sh
./scripts/deploy-minikube.sh

# Instalar ArgoCD (opcional)
chmod +x scripts/setup-argocd.sh
./scripts/setup-argocd.sh
```

## 📚 Documentación

| Sección | Descripción |
|---------|-------------|
| [Arquitectura](./architecture/overview) | Diseño y decisiones técnicas |
| [Infraestructura](./infrastructure/kubernetes) | Configuración de Kubernetes y Terraform |
| [Despliegue](./deployment/minikube) | Guías paso a paso |
| [GitOps](./deployment/argocd) | Configuración de ArgoCD |

## 🏗️ Estructura del Proyecto

```
dotnet-cloud-stack/
├── docs/                    # Documentación para Docusaurus
├── src/
│   └── backend/            # API .NET 9
├── infrastructure/
│   ├── terraform/          # IaC para Azure
│   └── kubernetes/         # Manifiestos K8s
├── helm/                   # Charts de Helm
├── argocd/                 # Configuración GitOps
└── scripts/                # Scripts de automatización
```

## ✅ Requisitos Previos

- Docker Desktop o Docker Engine
- Minikube v1.32+
- kubectl v1.29+
- Helm v3.14+ (opcional)
- Terraform v1.5+ (para Azure)
