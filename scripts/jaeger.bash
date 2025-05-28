#!/bin/bash

set -e

echo "Installing Jaeger Operator..."
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.65.0/jaeger-operator.yaml

echo "Waiting for Jaeger Operator to be ready..."
kubectl rollout status deployment jaeger-operator -n observability

# echo "Applying your manifests..."
# kubectl apply -f your-k8s-manifests/

echo "Done."
