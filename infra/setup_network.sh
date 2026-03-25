#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
NETWORK_NAME="gke-multi-cluster-vpc"
REGION="us-central1"

echo "--> Creating VPC Network: $NETWORK_NAME"
gcloud compute networks create "$NETWORK_NAME" --subnet-mode=custom || true

echo "--> Creating Subnet for Cluster Old"
gcloud compute networks subnets create gke-subnet-old \
    --network="$NETWORK_NAME" \
    --range=10.0.0.0/24 \
    --region="$REGION" \
    --secondary-range=pods=10.10.0.0/16,services=10.20.0.0/20 || true

echo "--> Creating Subnet for Cluster New"
gcloud compute networks subnets create gke-subnet-new \
    --network="$NETWORK_NAME" \
    --range=10.1.0.0/24 \
    --region="$REGION" \
    --secondary-range=pods=10.11.0.0/16,services=10.21.0.0/20 || true

echo "--> Creating Proxy-only Subnet for Gateway"
gcloud compute networks subnets create gke-proxy-only-subnet \
    --purpose=REGIONAL_MANAGED_PROXY \
    --role=ACTIVE \
    --network="$NETWORK_NAME" \
    --range=10.2.0.0/23 \
    --region="$REGION" || true

echo "--> Creating Cloud DNS Managed Zone for app.demo.gke"
gcloud dns managed-zones create gke-demo-zone \
    --dns-name="demo.gke." \
    --description="Demo Zone for Multi-Cluster Gateway" \
    --visibility=public || true
