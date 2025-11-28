---
sidebar_position: 1
---

# Despliegue en Minikube

Guía paso a paso para desplegar la aplicación Finance en un clúster de Minikube local.

## Requisitos Previos

### Software Necesario

```bash
# Verificar Docker
docker --version
# Docker version 24.0.0 o superior

# Verificar Minikube
minikube version
# minikube version: v1.32.0 o superior

# Verificar kubectl
kubectl version --client
# Client Version: v1.29.0 o superior
```

### Recursos del Sistema

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| RAM | 4 GB | 8 GB |
| CPU | 2 núcleos | 4 núcleos |
| Disco | 20 GB | 40 GB |

## Paso 1: Iniciar Minikube

```bash
# Iniciar clúster con recursos adecuados
minikube start --memory=4096 --cpus=2 --driver=docker

# Verificar estado
minikube status
```

**Salida esperada:**
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

## Paso 2: Habilitar Addons

```bash
# Controlador de Ingress (NGINX)
minikube addons enable ingress

# Aprovisionador de Almacenamiento (para PVCs)
minikube addons enable storage-provisioner

# Servidor de Métricas (opcional, para HPA)
minikube addons enable metrics-server

# Verificar addons habilitados
minikube addons list | grep enabled
```

## Paso 3: Configurar Docker

```bash
# Usar el daemon de Docker de Minikube
eval $(minikube docker-env)

# Verificar que apunta a Minikube
docker info | grep "Name:"
# Debería mostrar "minikube"
```

## Paso 4: Construir la Imagen Docker

```bash
# Navegar al directorio del backend
cd src/backend

# Construir la imagen
docker build -t finance-api:latest .

# Verificar la imagen
docker images | grep finance-api
```

**Salida esperada:**
```
REPOSITORY    TAG       IMAGE ID       CREATED          SIZE
finance-api   latest    abc123def456   10 seconds ago   52MB
```

## Paso 5: Desplegar con Kustomize

```bash
# Navegar al directorio de kubernetes
cd ../../infrastructure/kubernetes

# Aplicar el overlay de desarrollo
kubectl apply -k overlays/dev

# Verificar recursos creados
kubectl get all -n finance-app
```

**Salida esperada:**
```
NAME                               READY   STATUS    RESTARTS   AGE
pod/finance-api-xxx-yyy            1/1     Running   0          30s
pod/postgres-xxx-yyy               1/1     Running   0          30s

NAME                  TYPE        CLUSTER-IP       PORT(S)
service/finance-api   ClusterIP   10.96.xxx.xxx    80/TCP
service/postgres      ClusterIP   10.96.xxx.xxx    5432/TCP

NAME                          READY   UP-TO-DATE   AVAILABLE
deployment.apps/finance-api   1/1     1            1
deployment.apps/postgres      1/1     1            1
```

## Paso 6: Esperar que los Pods estén Listos

```bash
# Esperar por PostgreSQL
kubectl wait --for=condition=ready pod -l app=postgres -n finance-app --timeout=120s

# Esperar por Finance API
kubectl wait --for=condition=ready pod -l app=finance-api -n finance-app --timeout=120s
```

## Paso 7: Configurar DNS Local

```bash
# Obtener IP de Minikube
MINIKUBE_IP=$(minikube ip)
echo $MINIKUBE_IP

# Agregar entrada a /etc/hosts
sudo sh -c "echo '$MINIKUBE_IP  app.local api.local' >> /etc/hosts"

# Verificar
cat /etc/hosts | grep app.local
```

## Paso 8: Iniciar Túnel de Minikube

En una **terminal separada**:

```bash
# Este comando requiere sudo y debe mantenerse ejecutando
minikube tunnel
```

## Paso 9: Verificar el Despliegue

### Verificación de Salud del API

```bash
# Usando curl
curl http://app.local/health

# Respuesta esperada:
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "service": "finance-api",
  "version": "1.0.0"
}
```

### Verificar Conexión a Base de Datos

```bash
curl http://app.local/health/db

# Respuesta esperada:
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2024-01-15T10:30:00Z",
  "message": "Database connection successful"
}
```

### Acceder a Swagger UI

Abrir en el navegador: **http://app.local**

## Paso 10: Probar la API

### Crear una Transacción

```bash
curl -X POST http://app.local/api/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Transacción de prueba",
    "amount": 100.50,
    "type": "credit"
  }'
```

### Listar Transacciones

```bash
curl http://app.local/api/transactions
```

## Alternativa: Port Forward

Si el túnel no funciona, usar port-forward:

```bash
# En una terminal separada
kubectl port-forward svc/finance-api -n finance-app 8080:80

# Acceder vía localhost
curl http://localhost:8080/health
```

## Verificar Logs

```bash
# Logs del API
kubectl logs -f deployment/finance-api -n finance-app

# Logs de PostgreSQL
kubectl logs -f deployment/postgres -n finance-app
```

## Verificar Persistencia de Datos

```bash
# Crear datos
curl -X POST http://app.local/api/transactions \
  -H "Content-Type: application/json" \
  -d '{"description": "Prueba de persistencia", "amount": 50.00, "type": "debit"}'

# Reiniciar el pod de PostgreSQL
kubectl rollout restart deployment/postgres -n finance-app

# Esperar que esté listo
kubectl wait --for=condition=ready pod -l app=postgres -n finance-app --timeout=120s

# Verificar que los datos persisten
curl http://app.local/api/transactions
# Debería mostrar la transacción creada anteriormente
```

## Script Automatizado

Todo el proceso está automatizado en:

```bash
chmod +x scripts/deploy-minikube.sh
./scripts/deploy-minikube.sh
```

## Solución de Problemas

### Pod en estado CrashLoopBackOff

```bash
# Ver logs del pod
kubectl logs pod/finance-api-xxx -n finance-app

# Describir el pod
kubectl describe pod/finance-api-xxx -n finance-app
```

### Ingress no responde

```bash
# Verificar controlador de ingress
kubectl get pods -n ingress-nginx

# Verificar configuración del ingress
kubectl describe ingress finance-app-ingress -n finance-app
```

### PVC en estado Pending

```bash
# Verificar storage class
kubectl get storageclass

# Si no hay storage class, usar:
minikube addons enable storage-provisioner
```

### API no conecta a PostgreSQL

```bash
# Verificar que postgres está corriendo
kubectl get pods -l app=postgres -n finance-app

# Verificar el servicio
kubectl get svc postgres -n finance-app

# Probar conexión desde dentro del clúster
kubectl run -it --rm debug --image=postgres:16-alpine --restart=Never -n finance-app -- \
  psql -h postgres -U postgres -d financedb -c "SELECT 1"
```

## Limpieza

```bash
# Eliminar recursos de la aplicación
kubectl delete -k infrastructure/kubernetes/overlays/dev

# Detener Minikube
minikube stop

# Eliminar clúster completamente
minikube delete
```
