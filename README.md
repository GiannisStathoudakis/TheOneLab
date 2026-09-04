> 🚧 **Status:** Under Construction

*Originally evolving from a series of older, local homelab iterations, this project was ultimately dubbed **TheOneLab**—reference to "The One Ring".*

The lab utilizes a custom fork ([springboot-kafka-streams-microservices-demo](https://github.com/GiannisStathoudakis/springboot-kafka-streams-microservices-demo)) of [ZaTribune's Spring Boot Kafka Streams Demo](https://github.com/ZaTribune/springboot-kafka-streams-microservices-demo), which has been heavily modified and adapted to be natively compatible with this GitOps infrastructure project. 

It acts as a comprehensive e-commerce microservices application featuring multiple Java Spring Boot services, MySQL database integration (utilizing Vault's dynamic credentials), and real-time event-driven streams powered by Redpanda.

## Target Enterprise Architecture (The Vision)

While **TheOneLab** is currently constrained to a self-contained environment (running on 2 local VMs), it is designed with the architectural primitives to transition seamlessly into a highly available, cloud-native enterprise model. 

If given a cloud budget, the target architecture shifts from a "Stateful Monolith Cluster" to a **Stateless Hub-and-Spoke Compute Plane**:

* **Multi-Cluster Fleet:** Utilizing **Cilium Cluster Mesh**, the infrastructure would be split into dedicated clusters (e.g., CI/CD Hub, UAT, and Production) sharing a secure, flat, wireguard-encrypted network.
* **Externalized State (Disposable Clusters):** Decoupling state from the compute plane maximizes cluster reliability and simplifies operations. In an enterprise model, stateful components would be outsourced to managed cloud services to keep the clusters 100% stateless:
  * **Databases & Storage:** The relational database (MySQL) would be replaced by a managed cloud database service (e.g., Azure Database for MySQL, AWS RDS), and local Garage storage would be replaced by managed object storage (e.g., Azure Blob Storage, AWS S3, Cloudflare R2).
  * **Messaging & Event Streaming:** The in-cluster Redpanda brokers would be replaced by a managed Kafka-compatible service such as **Azure Event Hubs** (or AWS MSK). This provides enterprise SLAs out of the box and offloads stream persistence, completely eliminating the need to maintain distributed broker nodes or orchestrate fragile data-mirroring pipelines during Kubernetes version migrations.
  * **Identity Management:** The in-cluster Authentik instance would be replaced by a managed cloud tenant (e.g., Microsoft Entra ID) to avoid maintaining stateful user sessions and tokens inside the cluster.
  * **Secrets Management:** The in-cluster HashiCorp Vault would be replaced by a managed cloud secrets vault (e.g., Azure Key Vault, AWS Secrets Manager) using Workload Identity to completely remove secret persistence from the cluster state.
  * **Observability:** VictoriaMetrics would be replaced by Grafana Mimir. While VictoriaMetrics requires persistent block storage inside the cluster, Mimir natively streams and stores data directly to Object Storage (Azure Blob / S3). This achieves true statelessness without the operational complexity of configuring `vmbackup` and `vmrestore` pipelines to preserve or inspect older metrics during cluster migrations.
* **Consolidated CI/CD Platform:** Kargo, GitHub Actions, and GHCR would be replaced by a unified enterprise platform like Azure DevOps. Storing code, artifacts, and container images centrally in Azure DevOps allows leveraging native multi-stage YAML pipelines and manual approval gates, removing the need for an in-cluster GitOps promotion orchestrator like Kargo.
* **Instant Disaster Recovery:** By moving databases, event streaming, identity, secrets, and object storage out of the worker nodes, the Kubernetes clusters become 100% stateless and disposable. In the event of a total cluster failure, you simply re-run your Terraform & Ansible playbooks to provision fresh infrastructure, and ArgoCD automatically bootstraps and syncs the entire application stack from Git in minutes.
* **Zero-Downtime Upgrades (Blue/Green):** A stateless architecture transforms risky, in-place Kubernetes version upgrades into safe, Blue/Green cluster replacements. Instead of upgrading a live cluster, a fresh "Green" cluster is bootstrapped via GitOps. Using weighted DNS or a Global Load Balancer, live traffic is gradually shifted (e.g., 95% old, 5% new) to verify stability before completely decommissioning the old "Blue" infrastructure.

---

## Current Infrastructure Stack

### Core Networking & Storage

| Component | Role |
| :--- | :--- |
| **Cilium** | CNI, Load Balancer, Hubble Observability, East-West routing (eBPF Kube-Proxy replacement) |
| **Envoy Gateway** | North-South Traffic Management (Kubernetes Gateway API) |
| **OpenEBS (LVM)** | High-performance local persistent block storage (LVM LocalPV CSI) |
| **Garage** | Lightweight, distributed S3-compatible object storage (Loki & Tempo & Pyroscope backends) |
| **NodeLocal DNSCache** | Caches DNS queries locally on worker nodes to eliminate CoreDNS latency |

### GitOps, Management & Security

| Component | Role |
| :--- | :--- |
| **ArgoCD** | GitOps Continuous Delivery (CD) engine |
| **Kargo** | Multi-stage Continuous Promotion & Lifecycle Orchestrator |
| **Rancher** | Centralized Kubernetes management and cluster dashboard |
| **Vault** | Centralized Secret & PKI Management (Dynamic, ephemeral database credentials) |
| **External Secrets (ESO)** | Syncs Vault secrets directly into Kubernetes-native secrets |
| **Cert-Manager & Let's Encrypt** | Automated public TLS/SSL certificate provisioning |
| **Authentik** | Centralized Identity Provider (OIDC / SSO) |
| **Kyverno** | Kubernetes Policy Engine and Admission Controller |
| **Tetragon** | eBPF-based security observability and runtime enforcement |
| **Renovate** | Automated dependency and Helm chart version updates |
| **Network Policies & PSA** | Zero-Trust ingress/egress firewalls and Pod Security Admission enforcement |

### Data & Messaging Middleware

| Component | Role |
| :--- | :--- |
| **Redpanda** | High-performance, C++ Kafka-compatible event streaming platform / message broker |
| **MySQL** | Relational database storage layer for microservice state and order persistence |

### Observability Stack

| Component | Role |
| :--- | :--- |
| **Grafana** | Unified dashboard visualization and APM UI |
| **Grafana Alloy** | Primary telemetry pipeline (logs, metrics, trace ingestion) |
| **VictoriaMetrics** | High-performance time-series metrics database (Prometheus-compatible) |
| **Loki** | Log aggregation and querying |
| **Tempo** | Distributed tracing backend with active Metrics-Generator |
| **OpenTelemetry eBPF (OBI)** | Kernel-level zero-code auto-instrumentation for HTTP/gRPC RED metrics and traces |
| **Pyroscope** | Continuous application profiling backend |
| **Node Exporter** | Host-level hardware and OS metric collector |
| **Hubble** | Network and service communication flow observability (via Cilium) |

---

## CI/CD & DevSecOps Pipeline

To ensure secure, automated, and reproducible delivery, the microservices utilize a streamlined **DevSecOps** pipeline powered by **GitHub Actions** and **Helm**:

* **Pre-Build Security Scans:** Source code is actively scanned for hardcoded secrets using **GitLeaks** and statically analyzed for vulnerabilities (SAST) using **Semgrep**.
* **Build & Containerize:** Java applications are built via Maven and packaged into minimal container images using Docker Buildx.
* **Post-Build Vulnerability Scanning:** Before distribution, **Trivy** scans container images for OS and library-level CVEs.
* **Image Registry & Provenance:** Production-ready container images are pushed to the **GitHub Container Registry (GHCR)** alongside generated Software Bill of Materials (SBOMs).
* **Helm Chart Delivery:** Application workloads are packaged into standardized **Helm Charts**, allowing declarative GitOps deployments seamlessly managed by ArgoCD and promoted by Kargo.