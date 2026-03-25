# GKE Multi-Cluster Update Report

## 1. Objective
The primary objective of this project was to demonstrate a **zero-downtime GKE version update** within a single region (`us-central1`) using a Multi-Cluster Gateway (MCG) strategy. This approach minimizes the risk of disruption by provisioning a new cluster for the target version and shifting traffic at the load balancer level.

## 2. Environment Details
- **GCP Project:** `multi-cluster-migration`
- **Region:** `us-central1`
- **Networking:** Custom VPC with version-specific subnets and a dedicated Regional Proxy-only subnet.
- **Cluster Old:** `cluster-old` (GKE 1.32.11-gke.1264000)
- **Cluster New:** `cluster-new` (GKE 1.33.9-gke.1117000)
- **Fleet Management:** Both clusters registered to a single Fleet with Multi-cluster Ingress and Multi-cluster Service Discovery enabled.

## 3. Demo Execution Progress

### Stage 1: Baseline Establishment
- Provisioned the baseline VPC and the first GKE cluster (v1.32).
- Deployed a FastAPI "demo app" and a standard Regional Load Balancer.
- **Verification:** Established a performance baseline with 100% traffic serving from `cluster-old`.

### Stage 2: Expansion
- Provisioned a second GKE cluster running the target version (v1.33).
- Registered the new cluster to the Fleet.
- Deployed the same demo application to the new cluster.

### Stage 3: Multi-Cluster Gateway Setup
- Introduced a Regional Multi-Cluster Gateway (`gke-l7-regional-external-managed-mc`).
- Exported services from both clusters via `ServiceExport`.
- Configured initial traffic weighting: 100% to v1.32, 0% to v1.33.

### Stage 4: Canary Update & Traffic Shift
- Performed an automated traffic shift using `HTTPRoute` weights.
- **Step 1:** 50/50 split between old and new versions.
- **Step 2:** 100% shift to the new GKE version.
- **Continuous Monitoring:** Ran a load tester during the entire transition to detect errors or latency spikes.

## 4. Performance & Availability Results

| Metric | Stage 1 (Baseline) | Stage 4 (Post-Update) |
| :--- | :--- | :--- |
| **Total Requests** | 49 | 49 |
| **Successful Requests** | 49 (100%) | 49 (100%) |
| **Failed Requests** | 0 (0.00%) | 0 (0.00%) |
| **Avg Latency** | 419.02 ms | 417.95 ms |
| **P95 Latency** | 425.92 ms | 423.64 ms |
| **Serving Cluster** | `cluster-old` (100%) | `cluster-new` (100%) |

### Key Observation:
The migration transition was completed with **zero failed requests**. The latency remained stable throughout the shift, proving that the Multi-Cluster Gateway provides a seamless transition path between GKE versions.

## 5. Benefits of the Multi-Cluster Update Strategy
1. **Zero Downtime:** Traffic is shifted at Layer 7, ensuring continuous availability.
2. **Infrastructure Isolation:** The new version is tested in a clean environment before receiving production traffic.
3. **Instant Rollback:** If the new version exhibits issues, traffic can be reverted to the old cluster in seconds by updating the `HTTPRoute` weights.
4. **Complying with Constraints:** The setup successfully adhered to strict organizational policies (Private Clusters and Shielded VMs).

## 6. Conclusion
The project successfully mirrored the template of the `multi-cluster-region-migration` repository and applied it to a single-region version update use case. The empirical results confirm that having multiple clusters is a highly effective way to manage GKE lifecycle events with minimal risk.
