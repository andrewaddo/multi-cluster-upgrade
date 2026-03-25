# GKE Version Update with Multi-Cluster Gateway

This project demonstrates a zero-downtime, low-risk GKE version update within a single region (`us-central1`) by using multiple clusters and a Regional Multi-Cluster Gateway (MCG). It follows the template from `multi-cluster-region-migration`.

## Objective
The objective is to show that having multiple clusters allows the update to be done with minimal downtime and minimal risk of disruption.
1.  **Stage 1: Baseline (v1.32)**: Primary cluster running the old version.
2.  **Stage 2: Expansion (v1.33)**: Secondary cluster running the new version.
3.  **Stage 3: Gateway Setup**: Introduce Multi-Cluster Gateway for traffic management.
4.  **Stage 4: Canary Update**: Shift traffic from v1.32 to v1.33.
5.  **Stage 5: Post-Migration Cleanup**: Settle on the new version and decommission the old.

## Architecture
- **Two GKE Standard Clusters**: Both in `us-central1`.
- **Regional Multi-Cluster Gateway**: A regional L7 load balancer (`gke-l7-regional-external-managed-mc`).
- **GKE Fleet**: Both clusters are registered to the same Fleet.
- **Canary Rollout**: Traffic weighting via `HTTPRoute`.

### Design Decision: DNS-based Routing
This project uses **DNS as the primary router** to ensure zero downtime during the transition between a single-cluster Load Balancer and a Multi-cluster Gateway.

**The Constraint:**
In Google Cloud, a single Regional Static IP address cannot be shared simultaneously between an L4 Load Balancer (used in the baseline) and an L7 Multi-cluster Gateway. Attempting to move the IP would require deleting the first Load Balancer before the second can use it, causing minutes of downtime.

**The Solution:**
1.  **Baseline**: The single-cluster Load Balancer is provisioned with its own IP. DNS (e.g., `app.demo.gke`) is pointed to this IP.
2.  **Overlap**: The Multi-cluster Gateway is provisioned with a *different* IP. At this stage, both endpoints are live and functional.
3.  **The Switch**: DNS is updated to point to the Gateway IP. Because both endpoints are serving the same application, the transition is transparent to users, even as DNS caches propagate.
4.  **Cleanup**: The old Load Balancer is decommissioned only after the DNS switch is complete.

## Project Structure
- `app/`: Simple FastAPI application reporting cluster and version.
- `infra/`: Modular `gcloud` infrastructure scripts.
- `k8s/`: Kubernetes manifests for Gateway, HTTPRoute, and App.
- `demo_stages/`: Sequential scripts for the demonstration.
- `scripts/`: Utility scripts including `performance_test.py`.

## Performance & Load Testing
The project includes a custom `performance_test.py` script to verify **zero downtime** and monitor traffic distribution.
- **RPS Control**: Test with a constant request rate (e.g., 5 Requests Per Second).
- **Metric Collection**: Latency, status codes, and traffic distribution by cluster/version.
- **CSV Reporting**: Generates reports for each stage to prove the seamless transition.

## How to Run the Demo

### 1. Setup Baseline
Provisions VPC and the first GKE cluster (v1.32).
```bash
./demo_stages/01_setup_baseline.sh
```

### 2. Expand with New Version
Provisions the second GKE cluster (v1.33) and registers to the Fleet.
```bash
./demo_stages/02_expand_new_version.sh
```

### 3. Setup Multi-Cluster Gateway
Introduces the MCG and prepares for traffic shifting using version-specific services.
```bash
./demo_stages/03_setup_gateway.sh
```

### 4. Perform Canary Update
Execute the traffic shift while running the load tester in another terminal.
```bash
# Terminal 1: Load Tester
python3 scripts/performance_test.py http://app.demo.gke/status --resolve app.demo.gke:<GATEWAY_IP> --rps 5 --duration 0 --output migration_transition.csv

# Terminal 2: Operator
./demo_stages/04_canary_update.sh
```

### 5. Cleanup
```bash
./demo_stages/05_cleanup.sh
```

## Benefits of this Approach
- **Zero Downtime**: Traffic is shifted at the load balancer level.
- **Risk Mitigation**: The old cluster remains untouched during the update.
- **Instant Rollback**: If issues are detected, traffic can be shifted back immediately.
- **Isolation**: New version features can be tested in isolation before any traffic shift.
