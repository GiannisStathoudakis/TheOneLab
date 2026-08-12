> 🚧 **Status:** Under Construction

*Originally evolving from a series of older, local homelab iterations, this project was ultimately dubbed **TheOneLab**—reference to "The One Ring".*

The lab utilizes a custom fork ([springboot-kafka-streams-microservices-demo](https://github.com/GiannisStathoudakis/springboot-kafka-streams-microservices-demo)) of [ZaTribune's Spring Boot Kafka Streams Demo](https://github.com/ZaTribune/springboot-kafka-streams-microservices-demo), which has been heavily modified and adapted to be natively compatible with this GitOps infrastructure project. 

It acts as a comprehensive e-commerce microservices application featuring multiple Java Spring Boot services, MySQL database integration (utilizing Vault's dynamic credentials), and real-time event-driven streams powered by Redpanda.

---

## Current Infrastructure Stack

| Component | Role in the Cluster |
| :--- | :--- |
| **Cilium** | CNI, Load Balancer, Hubble Observability, East-West routing (eBPF Kube-Proxy replacement) |
| **Envoy Gateway** | North-South Traffic Management (Kubernetes Gateway API) |
| **ArgoCD** | GitOps Continuous Delivery (CD) engine |
| **Kargo** | Automated Continuous Promotion & Staging Lifecycle Manager |
| **Vault** | Centralized Secret & PKI Management (Configured to generate dynamic, ephemeral database credentials) |
| **External Secrets (ESO)** | Syncs Vault secrets directly into Kubernetes-native secrets |
| **Cert-Manager & Let's Encrypt** | Automated public TLS/SSL certificate provisioning |
| **Authentik** | Centralized Identity Provider (OIDC / SSO) |
| **Kyverno** | Policy Engine & Supply Chain Security (Cosign signature validation, tag policies) |
| **Network Policies & PSA** | Zero-Trust ingress/egress firewalls and Pod Security Admission enforcement |
| **Renovate** | Automated dependency and Helm chart version updates |
| **Longhorn** | Distributed Block Storage (CSI) |
| **Garage** | Lightweight, S3-compatible object storage |
| **Technitium DNS** | Custom Local DNS (Avoids manual CoreDNS edits) |
| **NodeLocal DNSCache** | Caches DNS queries on worker nodes to prevent CoreDNS overload |

### Data & Messaging Middleware
*   **Redpanda:** High-performance, C++ Kafka-compatible event streaming platform / message broker.
*   **MySQL:** Relational database storage layer for microservice state and order persistence.

### Observability Stack
*   **Grafana:** Central dashboard visualization (Logs, Metrics, Traces)
*   **Loki:** Log aggregation and querying
*   **VictoriaMetrics:** High-performance time-series metrics storage
*   **Tempo:** Distributed tracing backend
*   **Alloy:** Telemetry data collector and processing pipeline
*   **Node Exporter:** Hardware and OS metric collection