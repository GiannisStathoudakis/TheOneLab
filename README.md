> 🚧 **Status:** Under Construction

*Originally evolving from a series of older, local homelab iterations, this project was ultimately dubbed **TheOneLab**—reference to "The One Ring".*

The lab utilizes a custom fork ([springboot-kafka-streams-microservices-demo](https://github.com/GiannisStathoudakis/springboot-kafka-streams-microservices-demo)) of [ZaTribune's Spring Boot Kafka Streams Demo](https://github.com/ZaTribune/springboot-kafka-streams-microservices-demo), which has been heavily modified and adapted to be natively compatible with this GitOps infrastructure project. 

It acts as a comprehensive e-commerce microservices application featuring multiple Java Spring Boot services, MySQL database integration (utilizing Vault's dynamic credentials), and real-time event-driven streams powered by Redpanda.

## Target Enterprise Architecture (The Vision)

While **TheOneLab** is currently constrained to a self-contained environment (running on 2 local VMs), it is designed with the architectural primitives to transition seamlessly into a highly available, cloud-native enterprise model. 

If given a cloud budget, the target architecture shifts from a "Stateful Monolith Cluster" to a **Stateless Hub-and-Spoke Compute Plane**:

* **Multi-Cluster Fleet:** Utilizing **Cilium Cluster Mesh**, the infrastructure would be split into dedicated clusters (e.g., CI/CD Hub, UAT, and Production) sharing a secure, flat, wireguard-encrypted network.
* **Externalized State (Business-Driven Risk Management):** Decoupling state from the compute plane is driven by a strict risk-vs-reward matrix. While losing an hour of telemetry logs during a cluster crash is an acceptable operational inconvenience, losing customer orders or streaming events is a critical business outage. Therefore, all business-critical state is outsourced to managed services, making the Kubernetes clusters 100% stateless and disposable:
  * **Eliminating in-cluster MySQL, Garage & OpenEBS:** The relational database would be replaced by a managed cloud service (e.g., Azure Database for MySQL, AWS RDS), and local Garage storage would be replaced by managed object storage (e.g., Azure Blob Storage, AWS S3). This shifts the massive maintenance overhead of backups, failovers, and storage corruption recovery entirely to the cloud provider. Consequently, heavy in-cluster block storage orchestrators like **OpenEBS** are no longer required. For temporary buffers (like Mimir/Loki Write-Ahead Logs and caches), the cluster would simply rely on the cloud VM's native ephemeral NVMe storage or standard cloud-provisioned disks (CSI), massively simplifying worker node operations.
  * **Eliminating in-cluster Redpanda:** The self-hosted message brokers would be replaced by a managed service like **Azure Event Hubs** (or AWS MSK). This guarantees enterprise SLAs and zero data loss for critical event streams without the headache of maintaining distributed brokers during cluster upgrades.
  * **Eliminating in-cluster Authentik:** The self-hosted Identity Provider would be replaced by a managed cloud tenant (e.g., Microsoft Entra ID). This completely removes the severe security and downtime risks associated with maintaining a custom Identity Provider breaking during an update.
  * **Eliminating in-cluster HashiCorp Vault:** The self-hosted Vault would be replaced by a managed cloud secrets service (e.g., Azure Key Vault, AWS Secrets Manager) using Workload Identity, completely removing secret persistence and unseal-key management from the cluster state.
* **Consolidated CI/CD (Eliminating Kargo, GitHub Actions & GHCR):** The fragmented in-cluster setup of Kargo, GitHub Actions, and GHCR would be replaced by a unified, highly cost-effective enterprise platform like **Azure DevOps**. This eliminates the maintenance headache of orchestrating standalone tools, consolidating source code, container registries, and YAML-based CI/CD pipelines into a single, fully managed ecosystem.
* **Instant Disaster Recovery:** By moving databases, event streaming, identity, secrets, and object storage out of the worker nodes, the Kubernetes clusters become 100% stateless and disposable. In the event of a total cluster failure, you simply re-run your Terraform & Ansible playbooks to provision fresh infrastructure, and ArgoCD automatically bootstraps and syncs the entire application stack from Git in minutes.
* **Zero-Downtime Upgrades (Blue/Green):** A stateless architecture transforms risky, in-place Kubernetes version upgrades into safe, Blue/Green cluster replacements. Instead of risking production downtime due to deprecated APIs during forced upgrades, a fresh "Green" cluster is bootstrapped via GitOps. Using weighted DNS or a Global Load Balancer, live traffic is gradually shifted (e.g., 5% ➔ 20% ➔ 100%) to the new cluster. This allows for real-time validation that the new environment is completely stable before decommissioning the old "Blue" infrastructure, guaranteeing zero customer impact.
* **Frictionless Node Auto-Provisioning (Karpenter):** By eliminating stateful workloads and persistent volumes from the compute plane, the cluster unlocks highly aggressive, risk-free autoscaling. Tools like Karpenter can dynamically spin up perfectly sized VMs in seconds. During off-hours, the autoscaler can ruthlessly terminate underutilized VMs to minimize cloud billing, avoiding the volume-detachment delays and data loss risks of stateful pod evictions.
* **Cloud FinOps & Cost Optimization:** The observability and compute layers are engineered with a strict FinOps mindset to minimize future cloud billing. By offloading high-volume telemetry exclusively to highly cost-effective S3-compatible Object Storage, the target architecture would completely avoid the premium costs of persistent cloud Block Storage (e.g., AWS EBS). Furthermore, aggressive lifecycle policies (e.g., pruning high-volume 'info' logs after 29 days, and transitioning critical logs to cold S3/Blob storage at the 30-day mark) would prevent storage bloat. Combined with predictive right-sizing tools (like Robusta KRR), this guarantees that infrastructure costs scale purely on actual utilization, eliminating idle over-provisioning.

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