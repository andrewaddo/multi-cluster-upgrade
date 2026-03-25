#!/bin/bash
set -e

CONFIG_CLUSTER=$1
REGION=$2

if [ -z "$CONFIG_CLUSTER" ] || [ -z "$REGION" ]; then
    echo "Usage: ./enable_features.sh <config-cluster> <region>"
    exit 1
fi

echo "--> Enabling Multi-cluster Ingress and Service Discovery Features"

gcloud container fleet ingress enable \
    --config-membership="$CONFIG_CLUSTER" \
    --project "$(gcloud config get-value project)" \
    --quiet

gcloud container fleet multi-cluster-services enable \
    --project "$(gcloud config get-value project)" \
    --quiet

echo "Fleet features enabled."
