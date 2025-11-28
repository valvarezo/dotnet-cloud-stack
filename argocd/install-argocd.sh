#!/bin/bash
# =============================================================================
# Script de Instalación de ArgoCD para Minikube
# =============================================================================

set -e

echo "🚀 Instalando ArgoCD..."

# Crear namespace de ArgoCD
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Esperando que los pods de ArgoCD estén listos..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Configurar servidor de ArgoCD para usar LoadBalancer o NodePort para Minikube
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

echo "✅ ¡ArgoCD instalado exitosamente!"

# Obtener contraseña inicial de admin
echo ""
echo "📝 Contraseña Inicial de Administrador de ArgoCD:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# Obtener URL de ArgoCD
ARGOCD_PORT=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
MINIKUBE_IP=$(minikube ip)
echo ""
echo "🌐 URL de ArgoCD: https://${MINIKUBE_IP}:${ARGOCD_PORT}"
echo "   Usuario: admin"
echo ""

echo "💡 O usa port-forward:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo "   Luego accede a: https://localhost:8443"
