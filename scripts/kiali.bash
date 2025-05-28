#!/bin/bash

# === CONFIGURATION ===
NAMESPACE="istio-system"
DOMAIN="kiali.internal.czcx.cc"  # <-- Change this to your actual domain
INGRESS_CLASS="nginx"
OUTPUT_DIR="kiali"

# === PREPARE DIRECTORY ===
cd ..
mkdir -p $OUTPUT_DIR

# === Kiali CR YAML ===
cat <<EOF > "${OUTPUT_DIR}/kiali-cr.yaml"
apiVersion: kiali.io/v1alpha1
kind: Kiali
metadata:
  name: kiali
  namespace: ${NAMESPACE}
spec:
  auth:
    strategy: anonymous
  deployment:
    accessible_namespaces: ["**"]
EOF

# === Kiali Ingress YAML ===
cat <<EOF > "${OUTPUT_DIR}/kiali-ingress.yaml"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kiali-ingress
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/ingress.class: "${INGRESS_CLASS}"
spec:
  rules:
  - host: ${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kiali
            port:
              number: 20001
EOF

# === Kiali Operator Install ===
echo "🧩 Installing Kiali Operator..."
kubectl apply -f https://kiali.io/operator/latest/operator.yaml

# === Wait for CRD ===
echo "⏳ Waiting for Kiali CRD to be available..."
until kubectl get crd kialis.kiali.io >/dev/null 2>&1; do sleep 2; done

# === Deploy CR ===
echo "📦 Applying Kiali Custom Resource..."
kubectl apply -f "${OUTPUT_DIR}/kiali-cr.yaml"

# === Wait for Service ===
echo "⏳ Waiting for Kiali service to appear..."
until kubectl get svc kiali -n ${NAMESPACE} >/dev/null 2>&1; do sleep 2; done

# === Apply Ingress ===
echo "🌐 Applying Ingress to expose Kiali..."
kubectl apply -f "${OUTPUT_DIR}/kiali-ingress.yaml"

# === Done ===
echo ""
echo "✅ Kiali is installed!"
echo "📂 Files saved to: $OUTPUT_DIR"
echo "🌍 Access at: http://${DOMAIN}"
