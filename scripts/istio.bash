#!/bin/bash

set -e

echo "🔍 Using kubeconfig at /etc/rancher/k3s/k3s.yaml"

KUBECONFIG="/etc/rancher/k3s/k3s.yaml"

# 1. Uninstall Istio completely
echo "🔥 Uninstalling Istio if present..."
istioctl uninstall --purge --skip-confirmation --kubeconfig "$KUBECONFIG" || true

echo "🧹 Deleting istio-system namespace..."
kubectl delete namespace istio-system --kubeconfig "$KUBECONFIG" --ignore-not-found

# 2. Remove any lingering CNI-related resources
echo "🧼 Cleaning up leftover CNI components..."
kubectl delete daemonset istio-cni-node -n istio-system --kubeconfig "$KUBECONFIG" --ignore-not-found
kubectl delete clusterrole istio-cni --kubeconfig "$KUBECONFIG" --ignore-not-found
kubectl delete clusterrolebinding istio-cni --kubeconfig "$KUBECONFIG" --ignore-not-found
kubectl delete serviceaccount istio-cni-service-account -n istio-system --kubeconfig "$KUBECONFIG" --ignore-not-found
kubectl delete configmap istio-cni-node-config -n istio-system --kubeconfig "$KUBECONFIG" --ignore-not-found

# 3. Delete lingering IstioOperator CRs
echo "🧼 Deleting any IstioOperator custom resources..."
kubectl get istiooperators.install.istio.io -A --kubeconfig "$KUBECONFIG" -o name | xargs -r kubectl delete --kubeconfig "$KUBECONFIG"

# 4. Wait a bit for cleanup
sleep 5

# 5. Reinstall Istio Ambient mode without CNI
echo "🚀 Installing Istio Ambient profile..."
istioctl install \
  --kubeconfig "$KUBECONFIG" \
  --set profile=ambient \
  --set values.cni.cniBinDir=/var/lib/rancher/k3s/data/current/bin \
  --set values.cni.cniConfDir=/var/lib/rancher/k3s/agent/etc/cni/net.d \
  --set values.cni.chained=true \
  --skip-confirmation

echo "✅ Done. Istio Ambient mode installed."
