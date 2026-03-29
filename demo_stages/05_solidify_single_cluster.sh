#!/bin/bash
# Stage 5: Solidify on Single Cluster (Revert MCG to L4 LB)
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NEW="cluster-new"
CLUSTER_OLD="cluster-old"

echo "=== STAGE 5: Solidifying on Single Cluster (v1.33) ==="

echo "--> Step 1: Provisioning standard L4 Load Balancer on $CLUSTER_NEW"
kubectl config use-context "gke_${PROJECT_ID}_${REGION}_${CLUSTER_NEW}"
kubectl apply -f k8s/app/service-lb.yaml

echo "Waiting for External IP to be allocated (approx. 30s)..."
NEW_LB_IP=""
while [ -z "$NEW_LB_IP" ]; do
    NEW_LB_IP=$(kubectl get svc gke-demo-svc-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    [ -z "$NEW_LB_IP" ] && sleep 5
done

echo "New Single-Cluster IP: $NEW_LB_IP"

echo "--> Step 2: Switching DNS to New Single-Cluster IP"
# Get the current Gateway IP from DNS to remove it
GATEWAY_IP=$(gcloud dns record-sets list --zone=gke-demo-zone --name="app.demo.gke." --type=A --format="value(rrdatas[0])")

echo "Current Gateway IP: $GATEWAY_IP"
echo "Switching DNS: app.demo.gke -> $NEW_LB_IP"

gcloud dns record-sets transaction start --zone=gke-demo-zone
gcloud dns record-sets transaction remove "$GATEWAY_IP" --name="app.demo.gke." --ttl=60 --type=A --zone=gke-demo-zone
gcloud dns record-sets transaction add "$NEW_LB_IP" --name="app.demo.gke." --ttl=60 --type=A --zone=gke-demo-zone
gcloud dns record-sets transaction execute --zone=gke-demo-zone

echo "Waiting 60s for DNS TTL to expire..."
sleep 60

echo "--> Step 3: Cleaning up Multi-Cluster Gateway Resources"

# Remove Gateway and HTTPRoute from Config Cluster (cluster-old)
echo "Removing Gateway and HTTPRoute from $CLUSTER_OLD..."
kubectl config use-context "gke_${PROJECT_ID}_${REGION}_${CLUSTER_OLD}"
kubectl delete -f k8s/gateway/httproute.yaml --ignore-not-found
kubectl delete -f k8s/gateway/gateway.yaml --ignore-not-found
kubectl delete -f k8s/gateway/service-v132.yaml --ignore-not-found

# Remove ServiceExport from New Cluster
echo "Removing ServiceExport from $CLUSTER_NEW..."
kubectl config use-context "gke_${PROJECT_ID}_${REGION}_${CLUSTER_NEW}"
kubectl delete -f k8s/gateway/service-v133.yaml --ignore-not-found

echo "--------------------------------------------------"
echo "STAGE 5 COMPLETE"
echo "The upgrade is now 'solidified' on $CLUSTER_NEW (v1.33) using a simple L4 Load Balancer."
echo "The Multi-Cluster Gateway has been decommissioned."
echo "--------------------------------------------------"
