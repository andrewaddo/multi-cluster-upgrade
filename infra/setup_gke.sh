#!/bin/bash
set -e

CLUSTER_NAME=$1
REGION=$2
NETWORK=$3
SUBNET=$4
CLUSTER_VERSION=$5
MASTER_CIDR=$6

if [ -z "$CLUSTER_NAME" ] || [ -z "$REGION" ] || [ -z "$NETWORK" ] || [ -z "$SUBNET" ] || [ -z "$CLUSTER_VERSION" ] || [ -z "$MASTER_CIDR" ]; then
    echo "Usage: ./setup_gke.sh <cluster-name> <region> <network> <subnet> <version> <master-cidr>"
    exit 1
fi

echo "--> Creating Cluster: $CLUSTER_NAME (v$CLUSTER_VERSION)"
gcloud container clusters create "$CLUSTER_NAME" \
    --region "$REGION" \
    --cluster-version "$CLUSTER_VERSION" \
    --network "$NETWORK" \
    --subnetwork "$SUBNET" \
    --enable-ip-alias \
    --cluster-secondary-range-name "pods" \
    --services-secondary-range-name "services" \
    --num-nodes 2 \
    --machine-type "e2-medium" \
    --enable-private-nodes \
    --master-ipv4-cidr "$MASTER_CIDR" \
    --enable-shielded-nodes \
    --shielded-secure-boot \
    --shielded-integrity-monitoring \
    --workload-pool "$(gcloud config get-value project).svc.id.goog" \
    --gateway-api=standard \
    --quiet || echo "Cluster $CLUSTER_NAME already exists or failed to create."

echo "--> Registering $CLUSTER_NAME to Fleet"
gcloud container fleet memberships register "$CLUSTER_NAME" \
    --gke-cluster="$REGION/$CLUSTER_NAME" \
    --enable-workload-identity \
    --quiet || echo "Membership $CLUSTER_NAME already exists or failed to register."
