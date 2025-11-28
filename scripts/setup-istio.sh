#!/bin/bash
# =============================================================================
# Script de instalación de Istio Service Mesh
# =============================================================================
# Este script instala Istio en Minikube y configura el namespace finance-app
# para usar el service mesh.
#
# Requisitos:
#   - Minikube ejecutándose
#   - kubectl configurado
#   - Conexión a internet (para descargar Istio)
#
# Uso:
#   chmod +x scripts/setup-istio.sh
#   ./scripts/setup-istio.sh
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Versión de Istio a instalar
ISTIO_VERSION="1.28.0"

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   Instalación de Istio Service Mesh${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# Paso 1: Verificar prerrequisitos
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/8] Verificando prerrequisitos...${NC}"

# Verificar Minikube
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Error: Minikube no está instalado${NC}"
    exit 1
fi

# Verificar que Minikube está corriendo
if ! minikube status | grep -q "Running"; then
    echo -e "${RED}Error: Minikube no está ejecutándose${NC}"
    echo "Ejecuta: minikube start --memory=8192 --cpus=4"
    exit 1
fi

# Verificar kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl no está instalado${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerrequisitos verificados${NC}"

# -----------------------------------------------------------------------------
# Paso 2: Descargar Istio desde GitHub
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[2/8] Descargando Istio ${ISTIO_VERSION}...${NC}"

# Detectar sistema operativo
OS=$(uname -s)
case "${OS}" in
    Linux*)
        ISTIO_OS="linux"
        ;;
    Darwin*)
        ISTIO_OS="osx"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        ISTIO_OS="win"
        ;;
    *)
        echo -e "${RED}Sistema operativo no soportado: ${OS}${NC}"
        exit 1
        ;;
esac

# Detectar arquitectura
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64|amd64)
        ISTIO_ARCH="amd64"
        ;;
    aarch64|arm64)
        ISTIO_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}Arquitectura no soportada: ${ARCH}${NC}"
        exit 1
        ;;
esac

echo "Sistema detectado: ${ISTIO_OS} (${ISTIO_ARCH})"

ISTIO_DIR="/tmp/istio-${ISTIO_VERSION}"

if [ -d "$ISTIO_DIR" ]; then
    echo "Istio ya está descargado en $ISTIO_DIR"
else
    cd /tmp
    
    # Construir URL de descarga según el SO
    if [ "$ISTIO_OS" = "win" ]; then
        DOWNLOAD_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${ISTIO_OS}.zip"
        FILENAME="istio-${ISTIO_VERSION}.zip"
    else
        DOWNLOAD_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${ISTIO_OS}-${ISTIO_ARCH}.tar.gz"
        FILENAME="istio-${ISTIO_VERSION}.tar.gz"
    fi
    
    echo "Descargando desde: $DOWNLOAD_URL"
    
    curl -L "$DOWNLOAD_URL" -o "$FILENAME"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al descargar Istio${NC}"
        exit 1
    fi
    
    # Extraer según el formato
    if [ "$ISTIO_OS" = "win" ]; then
        unzip -q "$FILENAME"
    else
        tar -xzf "$FILENAME"
    fi
    
    rm "$FILENAME"
fi

# Agregar istioctl al PATH
if [ "$ISTIO_OS" = "win" ]; then
    export PATH="$ISTIO_DIR/bin:$PATH"
    ISTIOCTL_CMD="$ISTIO_DIR/bin/istioctl.exe"
else
    export PATH="$ISTIO_DIR/bin:$PATH"
    ISTIOCTL_CMD="istioctl"
fi

echo -e "${GREEN}✓ Istio ${ISTIO_VERSION} descargado (${ISTIO_OS}/${ISTIO_ARCH})${NC}"

# -----------------------------------------------------------------------------
# Paso 3: Verificar el clúster
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[3/8] Verificando compatibilidad del clúster...${NC}"

$ISTIOCTL_CMD x precheck

echo -e "${GREEN}✓ Clúster compatible${NC}"

# -----------------------------------------------------------------------------
# Paso 4: Instalar Istio con perfil demo
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[4/8] Instalando Istio (perfil demo)...${NC}"

# El perfil demo incluye todos los componentes para desarrollo
# Para producción, usar: istioctl install --set profile=default
$ISTIOCTL_CMD install --set profile=demo -y

echo -e "${GREEN}✓ Istio instalado${NC}"

# -----------------------------------------------------------------------------
# Paso 5: Verificar la instalación
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[5/8] Verificando instalación...${NC}"

kubectl get pods -n istio-system

# Esperar a que los pods estén listos
echo "Esperando a que los pods de Istio estén listos..."
kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=istio-ingressgateway -n istio-system --timeout=300s

echo -e "${GREEN}✓ Todos los componentes de Istio están listos${NC}"

# -----------------------------------------------------------------------------
# Paso 6: Instalar addons (Kiali, Prometheus, Grafana, Jaeger)
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[6/8] Instalando addons de observabilidad...${NC}"

# Instalar addons desde el directorio de Istio
kubectl apply -f ${ISTIO_DIR}/samples/addons/prometheus.yaml
kubectl apply -f ${ISTIO_DIR}/samples/addons/grafana.yaml
kubectl apply -f ${ISTIO_DIR}/samples/addons/jaeger.yaml
kubectl apply -f ${ISTIO_DIR}/samples/addons/kiali.yaml

# Esperar a que Kiali esté listo
echo "Esperando a que Kiali esté listo..."
kubectl wait --for=condition=ready pod -l app=kiali -n istio-system --timeout=300s

echo -e "${GREEN}✓ Addons instalados (Kiali, Prometheus, Grafana, Jaeger)${NC}"

# -----------------------------------------------------------------------------
# Paso 7: Habilitar inyección de sidecar en finance-app
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[7/8] Configurando namespace finance-app...${NC}"

# Crear namespace si no existe
kubectl create namespace finance-app --dry-run=client -o yaml | kubectl apply -f -

# Habilitar inyección automática de sidecar
kubectl label namespace finance-app istio-injection=enabled --overwrite

echo -e "${GREEN}✓ Namespace finance-app configurado para Istio${NC}"

# -----------------------------------------------------------------------------
# Paso 8: Aplicar configuraciones de Istio
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[8/8] Aplicando configuraciones de Istio...${NC}"

# Obtener el directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Aplicar configuraciones de Istio si existen
if [ -d "$PROJECT_DIR/infrastructure/kubernetes/istio" ]; then
    kubectl apply -k $PROJECT_DIR/infrastructure/kubernetes/istio/
    echo -e "${GREEN}✓ Configuraciones de Istio aplicadas${NC}"
else
    echo -e "${YELLOW}⚠ No se encontraron configuraciones de Istio en infrastructure/kubernetes/istio/${NC}"
fi

# -----------------------------------------------------------------------------
# Resumen
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}   ¡Istio instalado exitosamente!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "${BLUE}Componentes instalados:${NC}"
echo "  • Istio Control Plane (istiod)"
echo "  • Istio Ingress Gateway"
echo "  • Kiali (dashboard de service mesh)"
echo "  • Prometheus (métricas)"
echo "  • Grafana (visualización)"
echo "  • Jaeger (tracing distribuido)"
echo ""
echo -e "${BLUE}Comandos útiles:${NC}"
echo ""
echo "  # Ver dashboard de Kiali:"
echo "  istioctl dashboard kiali"
echo ""
echo "  # Ver dashboard de Grafana:"
echo "  istioctl dashboard grafana"
echo ""
echo "  # Ver trazas en Jaeger:"
echo "  istioctl dashboard jaeger"
echo ""
echo "  # Verificar estado del mesh:"
echo "  istioctl analyze -n finance-app"
echo ""
echo "  # Ver configuración de un pod:"
echo "  istioctl proxy-status"
echo ""
echo -e "${YELLOW}IMPORTANTE:${NC}"
echo "  Si la aplicación ya estaba desplegada, reinicia los pods para"
echo "  inyectar el sidecar de Istio:"
echo ""
echo "  kubectl rollout restart deployment -n finance-app"
echo ""

# Guardar la ubicación de istioctl
echo ""
echo -e "${BLUE}Para usar istioctl, agrega esto a tu PATH:${NC}"
echo "  export PATH=\"$ISTIO_DIR/bin:\$PATH\""
echo ""
echo "  O copia istioctl a /usr/local/bin:"
echo "  sudo cp $ISTIO_DIR/bin/istioctl /usr/local/bin/"