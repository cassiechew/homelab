#!/bin/bash
set -e

NAMESPACES=(homer monitoring observability)

echo "🔮 Applying oauth2-proxy templates..."
for ns in "${NAMESPACES[@]}"; do
  echo "✨ Deploying to $ns"
  sudo kubectl apply -f oauth2-proxy/60-templates.yaml -n $ns
done
echo "👑 Done!"

