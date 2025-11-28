---
sidebar_position: 1
---

# Service Mesh con Istio

## ¿Qué es un Service Mesh?

Un Service Mesh es una capa de infraestructura dedicada que maneja la comunicación entre servicios. En lugar de que cada aplicación implemente su propia lógica de red (reintentos, timeouts, cifrado), el mesh lo hace de forma transparente.

```
┌─────────────────────────────────────────────────────────────────┐
│                    SIN SERVICE MESH                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   finance-api ──────── HTTP plano ────────► postgres            │
│       │                                                         │
│       ├── Implementar reintentos (código)                       │
│       ├── Implementar métricas (código)                         │
│       ├── Implementar TLS (certificados manuales)               │
│       └── Implementar circuit breaker (código)                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    CON SERVICE MESH (ISTIO)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   finance-api ◄──► [envoy] ══ mTLS ══ [envoy] ◄──► postgres     │
│                       │                   │                     │
│                       └───────────────────┘                     │
│                               │                                 │
│                    Istio maneja TODO:                           │
│                    ✓ Cifrado automático (mTLS)                  │
│                    ✓ Reintentos configurables                   │
│                    ✓ Métricas sin código                        │
│                    ✓ Circuit breakers                           │
│                    ✓ Canary deployments                         │
│                    ✓ Trazabilidad distribuida                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## ¿Por qué Istio?

Elegimos Istio para este proyecto por las siguientes razones:

| Característica | Beneficio |
|----------------|-----------|
| **mTLS automático** | Todo el tráfico interno está cifrado sin cambiar código |
| **Observabilidad** | Métricas, logs y trazas sin instrumentación manual |
| **Control de tráfico** | Canary deployments, traffic splitting, timeouts |
| **Resiliencia** | Circuit breakers, retries, fault injection |
| **Seguridad** | Authorization policies, rate limiting |
| **Madurez** | Proyecto CNCF graduado, usado en producción por miles de empresas |

## Arquitectura de Istio

```
┌─────────────────────────────────────────────────────────────────┐
│                      ISTIO CONTROL PLANE                        │
│                                                                 │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │
│   │   Pilot     │   │   Citadel   │   │   Galley    │          │
│   │  (config)   │   │   (certs)   │   │  (config)   │          │
│   └─────────────┘   └─────────────┘   └─────────────┘          │
│                            │                                    │
│                      ┌─────┴─────┐                              │
│                      │  istiod   │                              │
│                      └───────────┘                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                    Configuración y certificados
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       DATA PLANE                                │
│                                                                 │
│  ┌─────────────────────┐      ┌─────────────────────┐          │
│  │   Pod: finance-api  │      │   Pod: postgres     │          │
│  │  ┌───────────────┐  │      │  ┌───────────────┐  │          │
│  │  │  Container    │  │      │  │  Container    │  │          │
│  │  │  finance-api  │  │      │  │  postgres     │  │          │
│  │  └───────┬───────┘  │      │  └───────┬───────┘  │          │
│  │          │          │      │          │          │          │
│  │  ┌───────┴───────┐  │      │  ┌───────┴───────┐  │          │
│  │  │ Envoy Sidecar │◄─┼──────┼─►│ Envoy Sidecar │  │          │
│  │  │   (proxy)     │  │ mTLS │  │   (proxy)     │  │          │
│  │  └───────────────┘  │      │  └───────────────┘  │          │
│  └─────────────────────┘      └─────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Componentes Instalados

### Control Plane

- **istiod**: El cerebro de Istio. Maneja configuración, certificados y service discovery.

### Data Plane

- **Envoy Proxy**: Sidecar inyectado en cada pod que intercepta todo el tráfico.

### Addons de Observabilidad

| Addon | Propósito | Puerto |
|-------|-----------|--------|
| **Kiali** | Dashboard visual del service mesh | 20001 |
| **Prometheus** | Recolección de métricas | 9090 |
| **Grafana** | Visualización de métricas | 3000 |
| **Jaeger** | Trazabilidad distribuida | 16686 |

## Instalación

### Prerrequisitos

- Minikube con al menos **8GB de RAM** y **4 CPUs**
- kubectl configurado

```bash
# Iniciar Minikube con recursos suficientes
minikube start --memory=8192 --cpus=4 --driver=docker
```

### Instalación Automática

```bash
# Ejecutar script de instalación
chmod +x scripts/setup-istio.sh
./scripts/setup-istio.sh
```

### Instalación Manual

```bash
# 1. Descargar Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.2 sh -
cd istio-1.20.2
export PATH=$PWD/bin:$PATH

# 2. Verificar compatibilidad
istioctl x precheck

# 3. Instalar Istio (perfil demo para desarrollo)
istioctl install --set profile=demo -y

# 4. Verificar instalación
kubectl get pods -n istio-system

# 5. Instalar addons
kubectl apply -f samples/addons/

# 6. Habilitar inyección en namespace
kubectl label namespace finance-app istio-injection=enabled

# 7. Reiniciar pods para inyectar sidecar
kubectl rollout restart deployment -n finance-app
```

## Verificación

### Verificar que Istio está corriendo

```bash
kubectl get pods -n istio-system
```

Salida esperada:
```
NAME                                    READY   STATUS    RESTARTS   AGE
grafana-5f9b8c6c5d-xxxxx               1/1     Running   0          5m
istio-ingressgateway-7b4c8d7b6-xxxxx   1/1     Running   0          5m
istiod-6c86784695-xxxxx                1/1     Running   0          5m
jaeger-76cd7c7566-xxxxx                1/1     Running   0          5m
kiali-6d6f9b8c5d-xxxxx                 1/1     Running   0          5m
prometheus-5d5d6d6d6d-xxxxx            2/2     Running   0          5m
```

### Verificar inyección de sidecar

```bash
kubectl get pods -n finance-app -o jsonpath='{.items[*].spec.containers[*].name}' | tr ' ' '\n' | sort | uniq
```

Deberías ver `istio-proxy` junto con tus contenedores.

### Analizar configuración

```bash
istioctl analyze -n finance-app
```

## Dashboards

### Kiali (Service Mesh Dashboard)

```bash
istioctl dashboard kiali
```

Kiali muestra:
- Topología de servicios en tiempo real
- Tráfico entre servicios
- Estado de salud de cada servicio
- Configuraciones de Istio aplicadas

### Grafana (Métricas)

```bash
istioctl dashboard grafana
```

Dashboards incluidos:
- Istio Mesh Dashboard
- Istio Service Dashboard
- Istio Workload Dashboard

### Jaeger (Trazabilidad)

```bash
istioctl dashboard jaeger
```

Permite ver trazas distribuidas de requests a través de múltiples servicios.

## Configuraciones Aplicadas

### PeerAuthentication (mTLS)

Ubicación: `infrastructure/kubernetes/istio/peer-authentication.yaml`

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: finance-app
spec:
  mtls:
    mode: STRICT  # Todo el tráfico DEBE usar mTLS
```

### DestinationRule (Políticas de Tráfico)

Ubicación: `infrastructure/kubernetes/istio/destination-rules.yaml`

Configura:
- Connection pooling
- Circuit breakers
- Load balancing

### VirtualService (Enrutamiento)

Ubicación: `infrastructure/kubernetes/istio/virtual-service.yaml`

Configura:
- Timeouts
- Reintentos automáticos
- Traffic splitting (para canary)

### AuthorizationPolicy (Control de Acceso)

Ubicación: `infrastructure/kubernetes/istio/authorization-policy.yaml`

Implementa Zero Trust:
- Denegar todo por defecto
- Permitir solo tráfico explícitamente autorizado

## Troubleshooting

### Los pods no inician después de habilitar Istio

```bash
# Verificar eventos del pod
kubectl describe pod <pod-name> -n finance-app

# Verificar logs del sidecar
kubectl logs <pod-name> -n finance-app -c istio-proxy
```

### El tráfico no funciona con mTLS STRICT

```bash
# Verificar que ambos pods tienen sidecar
kubectl get pods -n finance-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Verificar políticas aplicadas
istioctl analyze -n finance-app
```

### Ver configuración de Envoy

```bash
# Ver configuración del proxy
istioctl proxy-config all <pod-name> -n finance-app

# Ver clusters configurados
istioctl proxy-config clusters <pod-name> -n finance-app

# Ver rutas
istioctl proxy-config routes <pod-name> -n finance-app
```

## Recursos Adicionales

- [Documentación oficial de Istio](https://istio.io/latest/docs/)
- [Istio by Example](https://istiobyexample.dev/)
- [Kiali Documentation](https://kiali.io/docs/)
