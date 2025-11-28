---
sidebar_position: 2
---

# Configuración Avanzada

## Canary Deployments

Un canary deployment permite enviar un porcentaje del tráfico a una nueva versión antes de hacer el rollout completo.

### Paso 1: Desplegar versión canary

```yaml
# api-deployment-canary.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: finance-api-canary
  namespace: finance-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: finance-api
      version: canary
  template:
    metadata:
      labels:
        app: finance-api
        version: canary
    spec:
      containers:
        - name: finance-api
          image: finance-api:v2  # Nueva versión
          ports:
            - containerPort: 8080
```

### Paso 2: Configurar traffic splitting

```yaml
# virtual-service-canary.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: finance-api-canary
  namespace: finance-app
spec:
  hosts:
    - finance-api
  http:
    - route:
        - destination:
            host: finance-api
            subset: stable
          weight: 90
        - destination:
            host: finance-api
            subset: canary
          weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: finance-api-versions
  namespace: finance-app
spec:
  host: finance-api
  subsets:
    - name: stable
      labels:
        version: stable
    - name: canary
      labels:
        version: canary
```

### Paso 3: Incrementar tráfico gradualmente

```bash
# 10% → 25% → 50% → 100%
kubectl patch virtualservice finance-api-canary -n finance-app --type merge -p '
spec:
  http:
  - route:
    - destination:
        host: finance-api
        subset: stable
      weight: 75
    - destination:
        host: finance-api
        subset: canary
      weight: 25
'
```

## Circuit Breaker

Protege el sistema de cascada de fallos desconectando servicios problemáticos.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: finance-api-circuit-breaker
  namespace: finance-app
spec:
  host: finance-api
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    outlierDetection:
      consecutive5xxErrors: 5      # Errores antes de expulsar
      interval: 10s                # Intervalo de análisis
      baseEjectionTime: 30s        # Tiempo de expulsión
      maxEjectionPercent: 50       # Máximo % de pods expulsados
```

### Probar el circuit breaker

```bash
# Instalar fortio para pruebas de carga
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/httpbin/sample-client/fortio-deploy.yaml -n finance-app

# Ejecutar prueba de carga
FORTIO_POD=$(kubectl get pods -n finance-app -l app=fortio -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n finance-app $FORTIO_POD -c fortio -- \
  fortio load -c 50 -qps 100 -t 30s http://finance-api/health
```

## Fault Injection

Inyecta fallos artificiales para probar la resiliencia del sistema.

### Inyectar latencia

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: finance-api-fault
  namespace: finance-app
spec:
  hosts:
    - finance-api
  http:
    - fault:
        delay:
          percentage:
            value: 10  # 10% de requests
          fixedDelay: 5s
      route:
        - destination:
            host: finance-api
```

### Inyectar errores HTTP

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: finance-api-fault
  namespace: finance-app
spec:
  hosts:
    - finance-api
  http:
    - fault:
        abort:
          percentage:
            value: 5  # 5% de requests
          httpStatus: 503
      route:
        - destination:
            host: finance-api
```

## Rate Limiting

Limita el número de requests para proteger servicios.

### Configurar rate limit global

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: finance-api-ratelimit
  namespace: finance-app
spec:
  workloadSelector:
    labels:
      app: finance-api
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: SIDECAR_INBOUND
        listener:
          filterChain:
            filter:
              name: "envoy.filters.network.http_connection_manager"
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.local_ratelimit
          typed_config:
            "@type": type.googleapis.com/udpa.type.v1.TypedStruct
            type_url: type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
            value:
              stat_prefix: http_local_rate_limiter
              token_bucket:
                max_tokens: 100
                tokens_per_fill: 100
                fill_interval: 60s
              filter_enabled:
                runtime_key: local_rate_limit_enabled
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              filter_enforced:
                runtime_key: local_rate_limit_enforced
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              response_headers_to_add:
                - append: false
                  header:
                    key: x-rate-limit
                    value: "100"
```

## Mirroring (Traffic Shadowing)

Envía una copia del tráfico a otro servicio para testing sin afectar a los usuarios.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: finance-api-mirror
  namespace: finance-app
spec:
  hosts:
    - finance-api
  http:
    - route:
        - destination:
            host: finance-api
            subset: stable
      mirror:
        host: finance-api-canary
      mirrorPercentage:
        value: 100.0
```

## Timeout y Retry Policies

### Configuración detallada de reintentos

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: finance-api-retry
  namespace: finance-app
spec:
  hosts:
    - finance-api
  http:
    - route:
        - destination:
            host: finance-api
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: connect-failure,refused-stream,unavailable,cancelled,retriable-4xx,5xx
        retryRemoteLocalities: true
```

## Monitoreo de mTLS

### Verificar estado de mTLS

```bash
# Ver si mTLS está activo entre servicios
istioctl x describe pod <pod-name> -n finance-app

# Ver certificados
istioctl proxy-config secret <pod-name> -n finance-app
```

### Dashboard de seguridad en Kiali

1. Abrir Kiali: `istioctl dashboard kiali`
2. Ir a **Graph** → Seleccionar namespace `finance-app`
3. En **Display** → Habilitar **Security**
4. Las conexiones con candado verde tienen mTLS activo

## Métricas Personalizadas

### Agregar métricas a Prometheus

```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: finance-metrics
  namespace: finance-app
spec:
  metrics:
    - providers:
        - name: prometheus
      overrides:
        - match:
            metric: REQUEST_COUNT
          tagOverrides:
            request_path:
              operation: UPSERT
              value: request.url_path
```

### Query en Prometheus

```promql
# Requests por segundo
rate(istio_requests_total{destination_service="finance-api.finance-app.svc.cluster.local"}[5m])

# Latencia p99
histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket{destination_service="finance-api.finance-app.svc.cluster.local"}[5m])) by (le))

# Tasa de errores
sum(rate(istio_requests_total{destination_service="finance-api.finance-app.svc.cluster.local", response_code=~"5.."}[5m])) / sum(rate(istio_requests_total{destination_service="finance-api.finance-app.svc.cluster.local"}[5m]))
```

## Producción: Consideraciones

### Perfil de producción

```bash
# Usar perfil default en lugar de demo
istioctl install --set profile=default -y
```

### Recursos recomendados

```yaml
# IstioOperator para producción
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 1000m
            memory: 4Gi
    ingressGateways:
      - name: istio-ingressgateway
        k8s:
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 2000m
              memory: 1Gi
          hpaSpec:
            minReplicas: 2
            maxReplicas: 5
```

### Deshabilitar componentes no necesarios

```bash
# Si no necesitas egress gateway
istioctl install --set profile=default --set components.egressGateways[0].enabled=false
```
