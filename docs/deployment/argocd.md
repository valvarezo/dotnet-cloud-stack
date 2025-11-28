---
sidebar_position: 2
---

# GitOps con ArgoCD

ArgoCD implementa GitOps para sincronización declarativa de Kubernetes con repositorios Git.

## ¿Por qué ArgoCD?

| Característica | Beneficio |
|---------------|-----------|
| **GitOps** | Git como fuente de verdad |
| **Sincronización Automática** | Detecta y aplica cambios |
| **Rollback** | Revertir a cualquier commit |
| **Multi-clúster** | Gestionar múltiples clústeres |
| **Interfaz Visual** | Interfaz para visualizar estado |
| **RBAC** | Control de acceso granular |

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Repositorio Git                                │
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │
│  │ infrastructure/ │  │    argocd/      │  │      src/               │ │
│  │ kubernetes/     │  │    apps/        │  │      backend/           │ │
│  └────────┬────────┘  └────────┬────────┘  └───────────────────────┘ │
│           │                    │                                        │
└───────────┼────────────────────┼────────────────────────────────────────┘
            │                    │
            ▼                    ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                         ArgoCD (namespace: argocd)                         │
│                                                                            │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────────┐  │
│  │  Controlador de  │  │   Servidor de    │  │   Servidor de         │  │
│  │  Aplicaciones    │  │   Repositorios   │  │   Aplicaciones (UI)   │  │
│  │                  │  │                  │  │                       │  │
│  │  Monitorea Git   │◀─│  Clona repos     │──│   Panel de Control    │  │
│  │  Sincroniza      │  │  Renderiza       │  │   API REST            │  │
│  └──────────────────┘  └──────────────────┘  └───────────────────────┘  │
│           │                                                               │
│           ▼                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐│
│  │                    Clúster de Kubernetes                              ││
│  │                                                                       ││
│  │  ┌─────────────────────────────────────────────────────────────────┐ ││
│  │  │                    namespace finance-app                         │ ││
│  │  │                                                                  │ ││
│  │  │   Deployment    Service    Ingress    ConfigMap    Secret       │ ││
│  │  └─────────────────────────────────────────────────────────────────┘ ││
│  └──────────────────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────────────┘
```

## Instalación

### Método 1: Script Automatizado

```bash
chmod +x scripts/setup-argocd.sh
./scripts/setup-argocd.sh
```

### Método 2: Manual

```bash
# Crear namespace
kubectl create namespace argocd

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Esperar a que esté listo
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Exponer servicio (NodePort para Minikube)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
```

### Obtener Credenciales

```bash
# Contraseña inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Usuario: admin
```

### Acceder a ArgoCD

```bash
# Opción 1: NodePort
ARGOCD_PORT=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo "https://$(minikube ip):$ARGOCD_PORT"

# Opción 2: Port Forward
kubectl port-forward svc/argocd-server -n argocd 8443:443
# Acceder a https://localhost:8443
```

## Configuración

### Proyecto de ArgoCD

El proyecto define los límites de lo que las aplicaciones pueden hacer:

```yaml
# argocd/projects/finance-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: finance-app
  namespace: argocd
spec:
  description: Proyecto de Aplicación Financiera
  
  sourceRepos:
    - '*'  # Repositorios permitidos
  
  destinations:
    - namespace: finance-app
      server: https://kubernetes.default.svc
  
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
```

```bash
# Aplicar proyecto
kubectl apply -f argocd/projects/finance-project.yaml
```

### Aplicación de ArgoCD

Define qué desplegar y cómo:

```yaml
# argocd/apps/finance-app-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: finance-app-dev
  namespace: argocd
spec:
  project: finance-app
  
  source:
    repoURL: https://github.com/tu-organizacion/dotnet-cloud-stack.git
    targetRevision: HEAD
    path: infrastructure/kubernetes/overlays/dev
  
  destination:
    server: https://kubernetes.default.svc
    namespace: finance-app
  
  syncPolicy:
    automated:
      prune: true      # Eliminar recursos huérfanos
      selfHeal: true   # Auto-corregir desviaciones
```

## Flujo de Trabajo GitOps

```
Desarrollador         Repositorio Git           ArgoCD                 Kubernetes
    │                          │                        │                        │
    │  1. Push cambios         │                        │                        │
    │─────────────────────────▶│                        │                        │
    │                          │                        │                        │
    │                          │  2. Detecta cambios    │                        │
    │                          │◀───────────────────────│                        │
    │                          │                        │                        │
    │                          │  3. Obtiene manifiestos│                        │
    │                          │───────────────────────▶│                        │
    │                          │                        │                        │
    │                          │                        │  4. Aplica al clúster  │
    │                          │                        │───────────────────────▶│
    │                          │                        │                        │
    │                          │                        │  5. Reporta estado     │
    │                          │                        │◀───────────────────────│
    │                          │                        │                        │
    │  6. Ver en interfaz      │                        │                        │
    │◀─────────────────────────────────────────────────│                        │
```

## Comandos CLI de ArgoCD

### Instalación del CLI

```bash
# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# macOS
brew install argocd
```

### Iniciar Sesión

```bash
argocd login localhost:8443 --username admin --password <contraseña> --insecure
```

### Gestión de Aplicaciones

```bash
# Listar aplicaciones
argocd app list

# Ver estado de una aplicación
argocd app get finance-app-dev

# Sincronizar manualmente
argocd app sync finance-app-dev

# Ver diferencias
argocd app diff finance-app-dev

# Rollback a revisión anterior
argocd app rollback finance-app-dev 1

# Ver historial
argocd app history finance-app-dev
```

## Configuración para Producción

### Política de Sincronización para Producción

```yaml
# argocd/apps/finance-app-prod.yaml
spec:
  syncPolicy:
    # Sincronización manual para producción
    automated: null
    
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true  # Solo aplicar cambios
    
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 1m
```

### Notificaciones (Slack)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  
  template.app-deployed: |
    message: |
      La aplicación {{.app.metadata.name}} está ejecutando una nueva versión.
  
  trigger.on-deployed: |
    - when: app.status.sync.status == 'Synced'
      send: [app-deployed]
```

## Mejores Prácticas

### 1. Estructura de Repositorios

```
# Opción A: Monorepo
repo/
├── apps/           # Código de aplicación
├── infrastructure/ # Manifiestos K8s
└── argocd/        # Configuración ArgoCD

# Opción B: Repos separados
app-repo/          # Código de aplicación
config-repo/       # Manifiestos K8s + ArgoCD
```

### 2. Estrategia de Ramas

| Rama | Ambiente | Política de Sincronización |
|--------|----------|-------------|
| `develop` | Desarrollo | Automática |
| `staging` | Staging | Automática |
| `main` | Producción | Manual |

### 3. Secretos

Nunca almacenar secretos en Git. Usar:
- **Sealed Secrets**
- **External Secrets Operator**
- **Azure Key Vault**
- **HashiCorp Vault**

## Solución de Problemas

### Aplicación Fuera de Sincronización

```bash
# Ver diferencias
argocd app diff finance-app-dev

# Forzar sincronización
argocd app sync finance-app-dev --force
```

### Error de Permisos

```bash
# Verificar RBAC
kubectl auth can-i create deployments -n finance-app --as system:serviceaccount:argocd:argocd-application-controller
```

### Repositorio no Accesible

```bash
# Verificar conexión al repo
argocd repo list

# Agregar repositorio privado
argocd repo add https://github.com/org/repo.git --username <usuario> --password <token>
```
