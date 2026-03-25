#!/bin/bash
# Stage 1: Initial Setup - Old GKE Version (Baseline)
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_OLD="cluster-old"
VERSION_OLD="1.32.11-gke.1264000"
NETWORK="gke-multi-cluster-vpc"

echo "=== STAGE 1: Provisioning GKE Baseline (v1.32) ==="

echo "--> Enabling APIs..."
gcloud services enable \
    container.googleapis.com \
    gkehub.googleapis.com \
    multiclusteringress.googleapis.com \
    multiclusterservicediscovery.googleapis.com \
    compute.googleapis.com \
    trafficdirector.googleapis.com \
    networkservices.googleapis.com \
    cloudbuild.googleapis.com \
    --quiet

# Setup Network
./infra/setup_network.sh

# Setup GKE Old
./infra/setup_gke.sh "$CLUSTER_OLD" "$REGION" "$NETWORK" "gke-subnet-old" "$VERSION_OLD" "172.16.0.0/28"

echo "--> Getting credentials for $CLUSTER_OLD..."
gcloud container clusters get-credentials "$CLUSTER_OLD" --region "$REGION" --project "$PROJECT_ID"

echo "--> Building and pushing container image..."
IMAGE="gcr.io/$PROJECT_ID/gke-demo-app:v1"
gcloud builds submit app/ --tag "$IMAGE"

echo "--> Deploying application to $CLUSTER_OLD..."
mkdir -p k8s/rendered
sed "s/PROJECT_ID/$PROJECT_ID/g; s/CLUSTER_NAME_VAL/$CLUSTER_OLD/g" k8s/app/deployment.yaml > k8s/rendered/deploy-old.yaml
kubectl apply -f k8s/rendered/deploy-old.yaml
kubectl apply -f k8s/app/service.yaml
kubectl apply -f k8s/app/service-lb.yaml

echo "--------------------------------------------------"
echo "STAGE 1 COMPLETE"
echo "Next Steps:"
echo "1. Wait for External IP: kubectl get svc gke-demo-svc-lb"
echo "2. Run baseline test: python3 scripts/performance_test.py http://<EXTERNAL_IP>/status --output stage1_baseline.csv"
echo "--------------------------------------------------"
