#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

gcloud container clusters get-credentials cluster-old --region "$REGION" --project "$PROJECT_ID"
gcloud container clusters get-credentials cluster-new --region "$REGION" --project "$PROJECT_ID"
