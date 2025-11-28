#!/bin/bash
# =============================================================================
# Finance App - Despliegue GitOps con ArgoCD
# =============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[ÉXITO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=============================================="
echo "  Despliegue GitOps con ArgoCD"
echo "=============================================="
echo ""

# Verificar si minikube está ejecutándose
if ! minikube status | grep -q "Running"; then
    log_error "Minikube no está ejecutándose. Por favor ejecuta deploy-minikube.sh primero."
    exit 1
fi

# Paso 1: Instalar ArgoCD
log_info "Instalando ArgoCD..."

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log_info "Esperando que ArgoCD esté listo..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

log_success "ArgoCD instalado"

# Paso 2: Configurar ArgoCD server para NodePort
log_info "Configurando acceso a ArgoCD..."

kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Paso 3: Obtener credenciales
log_info "Obteniendo credenciales de ArgoCD..."

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
ARGOCD_PORT=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
MINIKUBE_IP=$(minikube ip)

# Paso 4: Aplicar proyecto de ArgoCD
log_info "Creando proyecto de ArgoCD..."

kubectl apply -f "${PROJECT_ROOT}/argocd/projects/finance-project.yaml"

log_success "Proyecto de ArgoCD creado"

# Paso 5: Mostrar información
echo ""
echo "=============================================="
echo "  🎉 ¡ArgoCD Instalado Exitosamente!"
echo "=============================================="
echo ""
echo "Acceso a ArgoCD:"
echo "  URL:      https://${MINIKUBE_IP}:${ARGOCD_PORT}"
echo "  Usuario:  admin"
echo "  Contraseña: ${ARGOCD_PASSWORD}"
echo ""
echo "Alternativa (port-forward):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo "  Luego accede a: https://localhost:8443"
echo ""
echo "Iniciar sesión con CLI de ArgoCD:"
echo "  argocd login ${MINIKUBE_IP}:${ARGOCD_PORT} --username admin --password '${ARGOCD_PASSWORD}' --insecure"
echo ""
echo "Siguientes Pasos:"
echo "  1. Sube este repositorio a GitHub/GitLab"
echo "  2. Actualiza el repoURL en argocd/apps/*.yaml"
echo "  3. Aplica la aplicación: kubectl apply -f argocd/apps/finance-app-dev.yaml"
echo ""

# Paso 6: Para desarrollo local, aplicar app con ruta local
log_warning "Para desarrollo local sin repositorio Git:"
echo ""
echo "  # Crear el namespace y desplegar directamente"
echo "  kubectl apply -k infrastructure/kubernetes/overlays/dev"
echo ""
echo "  # Luego monitorea en ArgoCD (la aplicación estará fuera de sincronización)"
echo ""
