---
sidebar_position: 1
---

# Infraestructura Kubernetes

## Estructura de Manifiestos

El proyecto utiliza **Kustomize** para organizar los manifiestos de Kubernetes:

```
infrastructure/kubernetes/
├── base/                    # Recursos base compartidos
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── postgres-pvc.yaml
│   ├── postgres-deployment.yaml
│   ├── postgres-service.yaml
│   ├── api-deployment.yaml
│   ├── api-service.yaml
│   └── ingress.yaml
└── overlays/
    ├── dev/                 # Overlay para Minikube
    │   └── kustomization.yaml
    └── prod/                # Overlay para AKS
        ├── kustomization.yaml
        ├── hpa.yaml
        └── network-policy.yaml
```

## Recursos Base

### Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: finance-app
  labels:
    app.kubernetes.io/name: finance-app
    app.kubernetes.io/managed-by: argocd
```

### ConfigMap

Variables de configuración no sensibles:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: finance-api-config
data:
  ASPNETCORE_ENVIRONMENT: "Production"
  DB_HOST: "postgres"
  DB_PORT: "5432"
  DB_NAME: "financedb"
```

### Secret

Credenciales sensibles (en producción usar Azure Key Vault o Sealed Secrets):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
stringData:
  POSTGRES_USER: "postgres"
  POSTGRES_PASSWORD: "P@ssw0rd2024Secure!"
  CONNECTION_STRING: "Host=postgres;Database=financedb;..."
```

## Deployments

### PostgreSQL

Características clave:
- **Estrategia Recreate**: Necesaria para bases de datos con PVC
- **Volumen Persistente**: 5Gi para desarrollo, 20Gi para producción
- **Verificaciones de Salud**: `pg_isready` para liveness/readiness
- **Recursos limitados**: Evita saturación del nodo

```yaml
spec:
  strategy:
    type: Recreate
  template:
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            exec:
              command: ["pg_isready", "-U", "postgres"]
```

### Finance API

Características clave:
- **Rolling Update**: Despliegues sin tiempo de inactividad
- **Contexto de Seguridad**: Non-root, sistema de archivos de solo lectura
- **Verificaciones de Salud**: Endpoints HTTP `/health`
- **Variables de Entorno**: Inyectadas desde ConfigMap y Secret

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      containers:
        - name: finance-api
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            readOnlyRootFilesystem: true
```

## Servicios

### Servicio PostgreSQL

**Tipo ClusterIP** - Solo accesible dentro del clúster:

```yaml
spec:
  type: ClusterIP  # NO expuesto externamente
  selector:
    app: postgres
  ports:
    - port: 5432
```

### Servicio Finance API

```yaml
spec:
  type: ClusterIP
  selector:
    app: finance-api
  ports:
    - port: 80
      targetPort: 8080
```

## Ingress

Configuración para el Controlador de Ingress NGINX:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: finance-app-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - host: app.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: finance-api
                port:
                  number: 80
```

## Overlays

### Desarrollo (Minikube)

Ajustes para ambiente local:

```yaml
# Reducir réplicas
patches:
  - target:
      kind: Deployment
      name: finance-api
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
```

### Producción (AKS)

Incluye recursos adicionales:
- **HorizontalPodAutoscaler**: Escala de 3 a 10 pods
- **NetworkPolicy**: Aislamiento de red
- **Recursos aumentados**: Más memoria y CPU

## Políticas de Red

En producción, se aplican políticas de red estrictas:

```
┌────────────────────────────────────────────────────────────┐
│                     namespace finance-app                   │
│                                                             │
│  ┌──────────┐         ┌──────────┐         ┌──────────┐   │
│  │ Ingress  │────────▶│   API    │────────▶│ Postgres │   │
│  │ (nginx)  │ Permitir│          │ Permitir│          │   │
│  └──────────┘         └──────────┘         └──────────┘   │
│        │                                          ▲         │
│        │              ┌──────────┐                │         │
│        └─────────────▶│  Otros   │───────────────┘         │
│           Denegar     │  Pods    │     Denegar             │
│                       └──────────┘                         │
└────────────────────────────────────────────────────────────┘
```

## Comandos Útiles

```bash
# Ver todos los recursos del namespace
kubectl get all -n finance-app

# Ver logs del API
kubectl logs -f deployment/finance-api -n finance-app

# Ver logs de PostgreSQL
kubectl logs -f deployment/postgres -n finance-app

# Ejecutar shell en PostgreSQL
kubectl exec -it deployment/postgres -n finance-app -- psql -U postgres -d financedb

# Port-forward para acceso local
kubectl port-forward svc/finance-api -n finance-app 8080:80

# Verificar ingress
kubectl get ingress -n finance-app
kubectl describe ingress finance-app-ingress -n finance-app

# Aplicar cambios con Kustomize
kubectl apply -k infrastructure/kubernetes/overlays/dev
```
