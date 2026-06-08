#!/bin/bash

set -e

KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
HOMELAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔍 Using kubeconfig at $KUBECONFIG"
echo "📂 Homelab dir: $HOMELAB_DIR"

apply_dir() {
  local dir="$HOMELAB_DIR/$1"
  if [ -d "$dir" ]; then
    echo "📁 Applying directory: $1"
    find "$dir" -name "*.yaml" | sort | while read -r file; do
      echo "  ✨ ${file#$HOMELAB_DIR/}"
      kubectl apply -f "$file" --kubeconfig "$KUBECONFIG" || true
    done
  else
    echo "⚠️  Skipping $1 (not found)"
  fi
}

# ── 1. INFRASTRUCTURE ─────────────────────────────────────────────────────
echo ""
echo "🏗️  Phase 1: Infrastructure"
apply_dir "metallb"
apply_dir "sealed-secrets"
apply_dir "cert-manager"

# ── 2. NAMESPACES ─────────────────────────────────────────────────────────
echo ""
echo "🏷️  Phase 2: Namespaces"
for ns in tailscale tailscale-proxy whoami lesma homer affine monica jellyfin \
          nas pocket-id monitoring observability postgres redis cloudflared \
          kube-metrics node-exporter searxng; do
  if [ -f "$HOMELAB_DIR/$ns/00-namespace.yaml" ]; then
    echo "  ✨ namespace: $ns"
    kubectl apply -f "$HOMELAB_DIR/$ns/00-namespace.yaml" --kubeconfig "$KUBECONFIG" || true
  fi
done

# ── 3. TAILSCALE ──────────────────────────────────────────────────────────
echo ""
echo "🔐 Phase 3: Tailscale"
apply_dir "tailscale"

# ── 4. ISTIO GATEWAY + CONFIG ─────────────────────────────────────────────
echo ""
echo "🌐 Phase 4: Istio Gateway + Config"
apply_dir "gateway"
apply_dir "istio"

# ── 5. SEALED SECRETS ─────────────────────────────────────────────────────
echo ""
echo "🔒 Phase 5: Sealed Secrets"
for dir in tailscale-proxy pocket-id homer observability \
           postgres kiali searxng cloudflared; do
  secret="$HOMELAB_DIR/$dir/14-sealed-secret.yaml"
  if [ -f "$secret" ]; then
    echo "  ✨ secret: $dir"
    kubectl apply -f "$secret" --kubeconfig "$KUBECONFIG" || true
  fi
done

# ── 6. SERVICES ───────────────────────────────────────────────────────────
echo ""
echo "🚀 Phase 6: Services"
for dir in whoami lesma homer affine monica jellyfin nas pocket-id \
           monitoring observability postgres redis cloudflared \
           kube-metrics node-exporter searxng tailscale-proxy; do
  apply_dir "$dir"
done

# ── 7. OAUTH2 PROXY ───────────────────────────────────────────────────────
echo ""
echo "🔑 Phase 7: OAuth2 Proxy"
apply_dir "oauth2-proxy"

# ── 8. KIALI ──────────────────────────────────────────────────────────────
echo ""
echo "📊 Phase 8: Kiali"
apply_dir "kiali"

# ── 9. BACKUPS ────────────────────────────────────────────────────────────
echo ""
echo "💾 Phase 9: Backups"
apply_dir "backups"

# ── 10. AMBIENT LABELS ────────────────────────────────────────────────────
echo ""
echo "🏷️  Phase 10: Ambient mesh labels"
for ns in whoami lesma observability monitoring monica homer nas jellyfin \
          pocket-id affine searxng; do
  kubectl label namespace $ns istio.io/dataplane-mode=ambient \
    --overwrite --kubeconfig "$KUBECONFIG" 2>/dev/null || true
done

# ── 11. WAYPOINTS ─────────────────────────────────────────────────────────
echo ""
echo "🔮 Phase 11: Waypoints"
for ns in whoami homer monitoring observability monica affine pocket-id; do
  istioctl waypoint apply -n $ns --enroll-namespace \
    --kubeconfig "$KUBECONFIG" --overwrite 2>/dev/null || true
done

echo ""
echo "👑 All manifests applied!"
echo ""
echo "⚠️  Remember manual steps after a fresh install:"
echo "   1. Run scripts/istio.bash first"
echo "   2. Run scripts/velero.bash with GARAGE_ACCESS_KEY and GARAGE_SECRET_KEY"
echo "   3. sudo tailscale set --accept-dns=false"
echo "   4. sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf"
echo "   5. Fix sshd_config on NAS (Match User restic block)"
