> 🚧 **Status:** Under Construction

## Current Infrastructure Stack

| Component | Role in the Cluster |
| :--- | :--- |
| **Cilium** | CNI, Load Balancer, Hubble Observability, East-West routing (Kube-Proxy replacement) |
| **Envoy Gateway** | North-South Traffic Management (Kubernetes Gateway API) |
| **ArgoCD** | GitOps Continuous Delivery (CD) |
| **Vault** | Centralized Secret Management |
| **External Secrets (ESO)** | Syncs Vault secrets directly into Kubernetes native secrets |
| **Cert-Manager & Let's Encrypt** | Automated public TLS/SSL certificate provisioning |
| **Authentik** | Centralized Identity Provider (OIDC / SSO) |
| **Kyverno** | Policy Engine & Supply Chain Security (Policies applied alongside apps) |
| **Renovate** | Automated dependency and Helm chart version updates |
| **Longhorn** | Distributed Block Storage (CSI) |
| **Garage** | Lightweight, S3-compatible object storage |
| **Technitium DNS** | Custom Local DNS (Avoids manual CoreDNS edits) |
| **NodeLocal DNSCache** | Caches DNS queries on nodes to prevent CoreDNS spam/overload |

### Observability Stack
*   **Grafana:** Central dashboard visualization (Logs, Metrics, Traces)
*   **Loki:** Log aggregation
*   **VictoriaMetrics:** High-performance metrics storage
*   **Tempo:** Distributed tracing
*   **Alloy:** Telemetry data collector / pipeline
*   **Node Exporter:** Hardware and OS metric collection