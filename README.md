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
* **Consolidated CI/CD Platform:** Kargo, GitHub Actions, and GHCR would be replaced by a unified enterprise platform like Azure DevOps. Storing code, artifacts, and container images centrally in Azure DevOps allows leveraging native multi-stage YAML pipelines and manual approval gates, removing the need for an in-cluster GitOps promotion orchestrator like Kargo.
* **Instant Disaster Recovery:** By moving databases, event streaming, identity, secrets, and object storage out of the worker nodes, the Kubernetes clusters become 100% stateless and disposable. In the event of a total cluster failure, you simply re-run your Terraform & Ansible playbooks to provision fresh infrastructure, and ArgoCD automatically bootstraps and syncs the entire application stack from Git in minutes.
* **Zero-Downtime Upgrades (Blue/Green):** A stateless architecture transforms risky, in-place Kubernetes version upgrades into safe, Blue/Green cluster replacements. Instead of upgrading a live cluster, a fresh "Green" cluster is bootstrapped via GitOps. Using weighted DNS or a Global Load Balancer, live traffic is gradually shifted (e.g., 95% old, 5% new) to verify stability before completely decommissioning the old "Blue" infrastructure.
* **Frictionless Node Auto-Provisioning (Karpenter):** By eliminating stateful workloads and persistent volumes from the compute plane, the cluster unlocks highly aggressive, risk-free autoscaling. Tools like Karpenter (or AKS Node Auto-Provisioning) can dynamically spin up perfectly sized, heterogeneous cloud VMs in seconds based on pending pod requirements. During off-hours, the autoscaler can ruthlessly consolidate workloads and terminate underutilized VMs to minimize cloud billing, entirely avoiding the volume-detachment delays and data loss risks associated with stateful pod evictions.
* **Cloud FinOps & Cost Optimization:** The observability and compute layers are engineered with a strict FinOps mindset to minimize future cloud billing. By offloading high-volume telemetry (Mimir metrics, Loki logs, Tempo traces, Pyroscope profiles) exclusively to highly cost-effective S3-compatible Object Storage, the target architecture **would completely avoid** the premium costs of persistent cloud Block Storage (e.g., AWS EBS). Furthermore, aggressive stream-level retention and lifecycle policies (e.g., automatically pruning high-volume 'info' logs after 29 days, and transitioning remaining critical logs to cold S3/Blob storage at the 30-day mark) **would prevent** storage bloat. Combined with predictive right-sizing tools (like Robusta KRR) and dynamic node autoscaling, this infrastructure **would guarantee** that compute and storage costs scale purely on actual utilization, eliminating idle over-provisioning.

---

## Current Infrastructure Stack

### Core Networking & Storage

| Component | Role |
| :--- | :--- |
| **Cilium** | CNI, Load Balancer, Hubble Observability, East-West routing (eBPF Kube-Proxy replacement) |
| **Envoy Gateway** | North-South Traffic Management (Kubernetes Gateway API) |
| **OpenEBS (LVM)** | High-performance local persistent block storage (LVM LocalPV CSI) |
| **Garage** | Lightweight, distributed S3-compatible object storage (Mimir, Loki, Tempo & Pyroscope backend) |
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
| **Grafana** | Unified dashboard visualization, Alerting and APM UI |
| **Grafana Alloy** | Primary telemetry pipeline (logs, metrics, trace ingestion) |
| **Grafana Mimir** | Horizontally scalable, highly available time-series metrics database *(FinOps optimized: S3-backed storage)* |
| **Loki** | Log aggregation and querying *(FinOps optimized: S3-backed storage with dynamic retention stream-selectors)* |
| **Tempo** | Distributed tracing backend with active Metrics-Generator *(FinOps optimized: S3-backed with strict 7-day retention)* |
| **Robusta KRR** | *(Planned)* Kubernetes Resource Recommender for compute right-sizing and minimizing idle over-provisioning |
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