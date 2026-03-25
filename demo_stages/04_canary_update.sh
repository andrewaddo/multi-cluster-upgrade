#!/bin/bash
# Stage 4: Canary Rollout to New GKE Version
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
kubectl config use-context "gke_${PROJECT_ID}_${REGION}_cluster-old"

echo "=== STAGE 4: Shifting Traffic to New GKE Version ==="

echo "--> Current Status: 100% Old Cluster (v1.32), 0% New Cluster (v1.33)"
echo "--> Step 1: 50/50 Traffic Split"
cat <<EOF | kubectl apply -f -
kind: HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: gke-demo-route
  namespace: default
spec:
  parentRefs:
  - name: external-http
    namespace: default
  rules:
  - backendRefs:
    - group: net.gke.io
      kind: ServiceImport
      name: gke-demo-svc-v129
      port: 80
      weight: 50
    - group: net.gke.io
      kind: ServiceImport
      name: gke-demo-svc-v130
      port: 80
      weight: 50
EOF

echo "Wait for traffic shift to take effect (approx. 60s)..."
sleep 45

echo "--> Step 2: 100% New Cluster"
cat <<EOF | kubectl apply -f -
kind: HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: gke-demo-route
  namespace: default
spec:
  parentRefs:
  - name: external-http
    namespace: default
  rules:
  - backendRefs:
    - group: net.gke.io
      kind: ServiceImport
      name: gke-demo-svc-v129
      port: 80
      weight: 0
    - group: net.gke.io
      kind: ServiceImport
      name: gke-demo-svc-v130
      port: 80
      weight: 100
EOF

echo "--------------------------------------------------"
echo "STAGE 4 COMPLETE"
echo "Next Steps:"
echo "1. Verify 100% traffic is on cluster-new."
echo "2. Run final performance report: python3 scripts/performance_test.py http://35.209.116.46/status --output stage4_post_update.csv"
echo "--------------------------------------------------"
