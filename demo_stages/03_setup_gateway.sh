#!/bin/bash
# Stage 3: Setup Multi-Cluster Gateway
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

echo "=== STAGE 3: Introducing Multi-Cluster Gateway ==="

# Apply ServiceExport to each cluster with version-specific services
echo "--> Applying Version-Specific Services and ServiceExports..."

# Cluster Old (v1.32)
kubectl config use-context "gke_${PROJECT_ID}_${REGION}_cluster-old"
kubectl apply -f k8s/gateway/service-v132.yaml

# Cluster New (v1.33)
kubectl config use-context "gke_${PROJECT_ID}_${REGION}_cluster-new"
kubectl apply -f k8s/gateway/service-v133.yaml

# Apply Gateway and Route to the Config Cluster (cluster-old)
echo "--> Applying Gateway and HTTPRoute to cluster-old (Config Cluster)..."
kubectl config use-context "gke_${PROJECT_ID}_${REGION}_cluster-old"
kubectl apply -f k8s/gateway/gateway.yaml
kubectl apply -f k8s/gateway/httproute.yaml

echo "--------------------------------------------------"
echo "STAGE 3 COMPLETE"
echo "Next Steps:"
echo "1. Wait for Gateway IP: kubectl get gateway external-http -o jsonpath='{.status.addresses[0].value}'"
echo "2. Run performance test: python3 scripts/performance_test.py http://app.demo.gke/status --resolve app.demo.gke:<GATEWAY_IP> --output stage3_mcg_baseline.csv"
echo "--------------------------------------------------"
