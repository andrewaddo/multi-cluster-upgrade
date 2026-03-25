#!/bin/bash
# Stage 2: Expand with New GKE Version
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NEW="cluster-new"
VERSION_NEW="1.33.9-gke.1117000"
NETWORK="gke-multi-cluster-vpc"

echo "=== STAGE 2: Provisioning Updated GKE Cluster (v1.33) ==="

# Setup GKE New
./infra/setup_gke.sh "$CLUSTER_NEW" "$REGION" "$NETWORK" "gke-subnet-new" "$VERSION_NEW" "172.16.0.16/28"

# Enable Multi-Cluster Features (Config cluster is cluster-old)
./infra/enable_features.sh "cluster-old" "$REGION"

echo "--> Getting credentials for $CLUSTER_NEW..."
gcloud container clusters get-credentials "$CLUSTER_NEW" --region "$REGION" --project "$PROJECT_ID"

echo "--> Deploying application to $CLUSTER_NEW..."
sed "s/PROJECT_ID/$PROJECT_ID/g; s/CLUSTER_NAME_VAL/$CLUSTER_NEW/g" k8s/app/deployment.yaml > k8s/rendered/deploy-new.yaml
kubectl apply -f k8s/rendered/deploy-new.yaml
kubectl apply -f k8s/app/service.yaml

echo "--------------------------------------------------"
echo "STAGE 2 COMPLETE"
echo "Next Steps:"
echo "1. Verify both clusters are in the Fleet: gcloud container fleet memberships list"
echo "2. Proceed to Stage 3 to introduce the Multi-Cluster Gateway."
echo "--------------------------------------------------"
