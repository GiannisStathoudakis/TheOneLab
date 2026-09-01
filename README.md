> 🚧 **Status:** Under Construction

*Originally evolving from a series of older, local homelab iterations, this project was ultimately dubbed **TheOneLab**—reference to "The One Ring" (One Lab to rule them all!).*

The lab utilizes a custom fork ([springboot-kafka-streams-microservices-demo](https://github.com/GiannisStathoudakis/springboot-kafka-streams-microservices-demo)) of [ZaTribune's Spring Boot Kafka Streams Demo](https://github.com/ZaTribune/springboot-kafka-streams-microservices-demo), which has been heavily modified and adapted to be natively compatible with this GitOps infrastructure project. 

It acts as a comprehensive e-commerce microservices application featuring multiple Java Spring Boot services, MySQL database integration (utilizing Vault's dynamic credentials), and real-time event-driven streams powered by Redpanda.

---

## Current Infrastructure Stack

| Component | Role |
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
| **NodeLocal DNSCache** | Caches DNS queries on worker nodes to prevent CoreDNS overload |

### Data & Messaging Middleware

| Component | Role |
| :--- | :--- |
| **Redpanda** | High-performance, C++ Kafka-compatible event streaming platform / message broker |
| **MySQL** | Relational database storage layer for microservice state and order persistence |

### Observability Stack

| Component | Role |
| :--- | :--- |
| **Grafana** | Central dashboard visualization |
| **Loki** | Log aggregation and querying |
| **VictoriaMetrics** | High-performance time-series metrics storage |
| **Tempo** | Distributed tracing backend |
| **Alloy** | Telemetry data collector and processing pipeline |
| **Node Exporter** | Hardware and OS metric collection |

---

## CI/CD & Supply Chain Security

To ensure secure, automated, and reproducible delivery, the microservices utilize a strict **DevSecOps** pipeline powered by **GitHub Actions** and **Helm**:

*   **Pre-Build Security Scans:** Source code is actively scanned for hardcoded secrets using **GitLeaks** and statically analyzed for vulnerabilities (SAST) using **Semgrep**.
*   **Build & Containerize:** Java applications are built via Maven and packaged into minimal Docker images using Docker Buildx.
*   **Post-Build Vulnerability Scanning:** Before distribution, **Trivy** scans the built container images for OS and library-level CVEs.
*   **Image Signing & Provenance:** Built images are cryptographically signed using **Cosign** (with a private key matching the Kyverno admission policies in the cluster) and pushed to the GitHub Container Registry (GHCR) alongside their Software Bill of Materials (SBOMs).
*   **Helm Chart Delivery:** The application workloads are packaged into custom **Helm Charts**, allowing standardized, reproducible GitOps deployments that seamlessly integrate with ArgoCD and Kargo.