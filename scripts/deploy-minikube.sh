#!/bin/bash
# =============================================================================
# Finance App - Script de Despliegue Completo para Minikube
# =============================================================================

set -e

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin Color

# Configuración
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-4096}
MINIKUBE_CPUS=${MINIKUBE_CPUS:-2}
NAMESPACE="finance-app"
IMAGE_NAME="finance-api"
IMAGE_TAG="latest"

# Funciones
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[ÉXITO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Encabezado
echo "=============================================="
echo "  Finance App - Despliegue en Minikube"
echo "=============================================="
echo ""

# Paso 1: Verificar prerequisitos
log_info "Verificando prerequisitos..."

command -v minikube >/dev/null 2>&1 || { log_error "minikube es requerido pero no está instalado."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { log_error "kubectl es requerido pero no está instalado."; exit 1; }
command -v docker >/dev/null 2>&1 || { log_error "docker es requerido pero no está instalado."; exit 1; }

log_success "Todos los prerequisitos están instalados"

# Paso 2: Iniciar Minikube
log_info "Iniciando clúster de Minikube..."

if minikube status | grep -q "Running"; then
    log_warning "Minikube ya está ejecutándose"
else
    minikube start --memory=${MINIKUBE_MEMORY} --cpus=${MINIKUBE_CPUS} --driver=docker
fi

log_success "El clúster de Minikube está ejecutándose"

# Paso 3: Habilitar addons requeridos
log_info "Habilitando addons de Minikube..."

minikube addons enable ingress
minikube addons enable storage-provisioner
minikube addons enable metrics-server

log_success "Addons habilitados"

# Paso 4: Configurar entorno Docker
log_info "Configurando Docker para usar el registro de Minikube..."

eval $(minikube docker-env)

log_success "Entorno Docker configurado"

# Paso 5: Construir la imagen Docker
log_info "Construyendo imagen Docker..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "${PROJECT_ROOT}/src/backend"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

log_success "Imagen Docker construida: ${IMAGE_NAME}:${IMAGE_TAG}"

# Paso 6: Desplegar con Kustomize
log_info "Desplegando aplicación con Kustomize..."

cd "${PROJECT_ROOT}/infrastructure/kubernetes"

# Aplicar el overlay de desarrollo
kubectl apply -k overlays/dev

log_success "Aplicación desplegada"

# Paso 7: Esperar que los pods estén listos
log_info "Esperando que los pods estén listos..."

kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=finance-api -n ${NAMESPACE} --timeout=120s || true

log_success "Los pods están listos"

# Paso 8: Configurar /etc/hosts
log_info "Configurando DNS local..."

MINIKUBE_IP=$(minikube ip)

echo ""
log_warning "Agrega la siguiente línea a tu archivo /etc/hosts:"
echo "  ${MINIKUBE_IP}  app.local api.local argocd.local"
echo ""
echo "  sudo sh -c 'echo \"${MINIKUBE_IP}  app.local api.local argocd.local\" >> /etc/hosts'"
echo ""

# Paso 9: Mostrar estado
log_info "Estado del Despliegue:"
echo ""

echo "📦 Pods:"
kubectl get pods -n ${NAMESPACE}
echo ""

echo "🌐 Servicios:"
kubectl get svc -n ${NAMESPACE}
echo ""

echo "🔗 Ingress:"
kubectl get ingress -n ${NAMESPACE}
echo ""

# Paso 10: Probar el despliegue
log_info "Probando el despliegue..."

# Esperar un poco para que el ingress esté listo
sleep 5

# Habilitar túnel de ingress en segundo plano
log_info "Iniciando túnel de Minikube (puede requerir sudo)..."
echo "Ejecuta en una terminal separada: minikube tunnel"
echo ""

# Mostrar URLs de acceso
echo "=============================================="
echo "  🎉 ¡Despliegue Completado!"
echo "=============================================="
echo ""
echo "URLs de Acceso (después de agregar entrada en hosts y ejecutar 'minikube tunnel'):"
echo "  📱 Frontend/Swagger UI: http://app.local"
echo "  🔧 Endpoint del API:    http://api.local"
echo "  ❤️  Health Check:        http://api.local/health"
echo "  🗄️  Salud de BD:         http://api.local/health/db"
echo ""
echo "Alternativa (port-forward):"
echo "  kubectl port-forward svc/finance-api -n ${NAMESPACE} 8080:80"
echo "  Luego accede a: http://localhost:8080"
echo ""
echo "Ver logs:"
echo "  kubectl logs -f deployment/finance-api -n ${NAMESPACE}"
echo "  kubectl logs -f deployment/postgres -n ${NAMESPACE}"
echo ""
