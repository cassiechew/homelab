#!/bin/bash

set -e

KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
VELERO_VERSION="v1.17.2"
GARAGE_IP="100.90.119.128"
GARAGE_PORT="3900"
BUCKET="velero-backups"

echo "🔍 Using kubeconfig at $KUBECONFIG"

# ── 1. Install Velero CLI ──────────────────────────────────────────────────
WORK_DIR=$(mktemp -d -p "$HOME")
echo "📦 Installing Velero CLI $VELERO_VERSION..."
curl -L https://github.com/vmware-tanzu/velero/releases/download/$VELERO_VERSION/velero-$VELERO_VERSION-linux-amd64.tar.gz -o "$WORK_DIR/velero.tar.gz"
tar -xzf "$WORK_DIR/velero.tar.gz" -C "$WORK_DIR"
sudo mv "$WORK_DIR/velero-$VELERO_VERSION-linux-amd64/velero" /usr/local/bin/velero
rm -rf "$WORK_DIR"
echo "✅ Velero CLI installed: $(velero version --client-only)"

# ── 2. Create credentials file ────────────────────────────────────────────
echo "🔑 Creating credentials file..."
if [ -z "$GARAGE_ACCESS_KEY" ] || [ -z "$GARAGE_SECRET_KEY" ]; then
  echo "❌ GARAGE_ACCESS_KEY and GARAGE_SECRET_KEY must be set as environment variables"
  echo "   Example: GARAGE_ACCESS_KEY=GKxxx GARAGE_SECRET_KEY=xxx ./velero.bash"
  exit 1
fi

CREDS_FILE=$(mktemp -p "$HOME")
cat > "$CREDS_FILE" << CREDS
[default]
aws_access_key_id=$GARAGE_ACCESS_KEY
aws_secret_access_key=$GARAGE_SECRET_KEY
CREDS

# ── 3. Install Velero into cluster ────────────────────────────────────────
echo "🚀 Installing Velero into cluster..."
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.11.0 \
  --bucket $BUCKET \
  --secret-file "$CREDS_FILE" \
  --use-node-agent \
  --default-volumes-to-fs-backup \
  --backup-location-config region=garage,s3ForcePathStyle=true,s3Url=http://$GARAGE_IP:$GARAGE_PORT \
  --kubeconfig "$KUBECONFIG"

rm -f "$CREDS_FILE"
echo "✅ Credentials file cleaned up"

# ── 4. Wait for Velero to be ready ───────────────────────────────────────
echo "⏳ Waiting for Velero to be ready..."
kubectl rollout status deployment velero -n velero --kubeconfig "$KUBECONFIG"
kubectl rollout status daemonset node-agent -n velero --kubeconfig "$KUBECONFIG"

# ── 5. Verify backup location ────────────────────────────────────────────
echo "🔍 Verifying backup location..."
velero backup-location get --kubeconfig "$KUBECONFIG"

# ── 6. Apply backup schedule ─────────────────────────────────────────────
echo "📅 Applying backup schedule..."
kubectl apply -f "$(dirname "$0")/../15-schedule.yaml" --kubeconfig "$KUBECONFIG"

echo ""
echo "✅ Velero installed and configured!"
echo "📋 Backup schedule: daily at 3am, retained for 30 days"
echo "🔍 Check status: velero backup-location get"
echo "💾 Manual backup: velero backup create my-backup --include-namespaces pocket-id,monica,affine"
