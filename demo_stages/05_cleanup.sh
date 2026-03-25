#!/bin/bash
# Stage 5: Cleanup
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
NETWORK="gke-multi-cluster-vpc"

echo "=== STAGE 5: Cleaning up Infrastructure ==="

echo "--> Deleting GKE Clusters and Fleet Memberships"
for CLUSTER in cluster-old cluster-new; do
    echo "--> Deleting $CLUSTER"
    gcloud container fleet memberships delete "$CLUSTER" --quiet || true
    gcloud container clusters delete "$CLUSTER" --region "$REGION" --quiet || true
done

echo "--> Deleting Subnets"
gcloud compute networks subnets delete gke-subnet-old --region "$REGION" --quiet || true
gcloud compute networks subnets delete gke-subnet-new --region "$REGION" --quiet || true
gcloud compute networks subnets delete gke-proxy-only-subnet --region "$REGION" --quiet || true

echo "--> Deleting VPC Network"
gcloud compute networks delete "$NETWORK" --quiet || true

echo "--> Deleting Cloud DNS Managed Zone"
gcloud dns record-sets transaction start --zone=gke-demo-zone || true
# Get the A record IP to remove
GATEWAY_IP=$(gcloud dns record-sets list --zone=gke-demo-zone --name="app.demo.gke." --type=A --format="value(rrdatas[0])" || true)
if [[ -n "$GATEWAY_IP" ]]; then
    gcloud dns record-sets transaction remove "$GATEWAY_IP" --name="app.demo.gke." --ttl=60 --type=A --zone=gke-demo-zone || true
    gcloud dns record-sets transaction execute --zone=gke-demo-zone || true
fi
gcloud dns managed-zones delete gke-demo-zone --quiet || true

echo "--------------------------------------------------"
echo "STAGE 5 COMPLETE"
echo "Project cleaned up successfully."
echo "--------------------------------------------------"
