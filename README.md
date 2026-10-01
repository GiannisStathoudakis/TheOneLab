> 🚧 **Status:** Under Construction

*Originally evolving from a series of older, local homelab iterations, this project was ultimately dubbed **TheOneLab**—reference to "The One Ring".*

The lab utilizes a custom fork ([springboot-kafka-streams-microservices-demo](https://github.com/GiannisStathoudakis/springboot-kafka-streams-microservices-demo)) of [ZaTribune's Spring Boot Kafka Streams Demo](https://github.com/ZaTribune/springboot-kafka-streams-microservices-demo), which has been heavily modified and adapted to be natively compatible with this GitOps infrastructure project. 

It acts as a comprehensive e-commerce microservices application featuring multiple Java Spring Boot services, MySQL database integration (utilizing Vault's dynamic credentials), and real-time event-driven streams powered by Redpanda.

## Target Enterprise Architecture (The Vision)

While **TheOneLab** is currently constrained to a self-contained non-HA environment (running on just 2 local VMs), it is designed with the architectural primitives to transition seamlessly into a highly available, cloud-native enterprise model. 

If given a cloud budget, the target architecture shifts from a "Stateful Monolith Cluster" to a **Stateless Hub-and-Spoke Compute Plane**:

* **Multi-Cluster Fleet:** Utilizing **Cilium Cluster Mesh**, the infrastructure would be split into dedicated clusters (e.g., CI/CD Hub, UAT, and Production) sharing a secure, flat, wireguard-encrypted network.
* **Externalized State (Business-Driven Risk Management):** Decoupling state from the compute plane is driven by a strict risk-vs-reward matrix. While losing an hour of telemetry logs during a cluster crash is an acceptable operational inconvenience, losing customer orders or streaming events is a critical business outage. Therefore, all business-critical state is outsourced to managed services, making the Kubernetes clusters 100% stateless and disposable:
  * **Eliminating Stateful Backends (MySQL & Garage) while Securing Local I/O (OpenEBS):** The relational database would be replaced by a managed cloud service (e.g., Azure Database for MySQL, AWS RDS), and local Garage storage would be replaced by managed object storage (e.g., Azure Blob Storage, AWS S3). This shifts the massive maintenance overhead of backups, failovers, and storage corruption recovery entirely to the cloud provider. However, **OpenEBS LVM** is strategically retained as the Local CSI provisioner exclusively for temporary observability buffers (like Mimir/Loki Write-Ahead Logs). By carving out strict Logical Volumes, OpenEBS enforces OS-level hard quotas. This guarantees **Blast Radius isolation**—if an application log-spams, it simply fills its own PVC and crashes its own pod, protecting the worker node's root filesystem from catastrophic `DiskPressure` outages.
  * **Eliminating in-cluster Redpanda:** The self-hosted message brokers would be replaced by a managed service like **Azure Event Hubs** (or AWS MSK). This guarantees enterprise SLAs and zero data loss for critical event streams without the headache of maintaining distributed brokers during cluster upgrades.
  * **Eliminating in-cluster Authentik:** The self-hosted Identity Provider would be replaced by a managed cloud tenant (e.g., Microsoft Entra ID). This completely removes the severe security and downtime risks associated with maintaining a custom Identity Provider breaking during an update.
  * **Eliminating in-cluster HashiCorp Vault:** The self-hosted Vault would be replaced by a managed cloud secrets service (e.g., Azure Key Vault, AWS Secrets Manager) using Workload Identity, completely removing secret persistence and unseal-key management from the cluster state.
* **Consolidated CI/CD (Eliminating Kargo, GitHub Actions & GHCR):** The fragmented in-cluster setup of Kargo, GitHub Actions, and GHCR would be replaced by a unified, highly cost-effective enterprise platform like **Azure DevOps**. This eliminates the maintenance headache of orchestrating standalone tools, consolidating source code, container registries, and YAML-based CI/CD pipelines into a single, fully managed ecosystem.
* **Instant Disaster Recovery:** By moving databases, event streaming, identity, secrets, and object storage out of the worker nodes, the Kubernetes clusters become 100% stateless and disposable. In the event of a total cluster failure, you simply re-run your Terraform & Ansible playbooks to provision fresh infrastructure, and ArgoCD automatically bootstraps and syncs the entire application stack from Git in minutes.
* **Zero-Downtime Upgrades (Blue/Green):** A stateless architecture transforms risky, in-place Kubernetes version upgrades into safe, Blue/Green cluster replacements. Instead of risking production downtime due to deprecated APIs during forced upgrades, a fresh "Green" cluster is bootstrapped via GitOps. Using weighted DNS or a Global Load Balancer, live traffic is gradually shifted (e.g., 5% ➔ 20% ➔ 100%) to the new cluster. This allows for real-time validation that the new environment is completely stable before decommissioning the old "Blue" infrastructure, guaranteeing zero customer impact.
* **Database Schema as Code (Atlas + Terraform):** To eliminate the risk of manual database alterations and traditional imperative migrations (e.g., Flyway), database schema management would transition to a purely declarative model. By integrating **Atlas** with **Terraform**, schema changes would be treated exactly like infrastructure: planned in CI/CD, reviewed via automated diffs in GitHub Actions, and applied securely without human intervention, completing the end-to-end GitOps lifecycle.
* **Full-Stack Autoscaling & Consolidation:** Moving beyond simple CPU/Memory limits, the target architecture **would employ** a highly aggressive, multi-tier scaling strategy. At the application layer, **KEDA** **would query** the central Mimir TSDB via PromQL to proactively scale microservices based on real business metrics (e.g., Kafka lag, HTTP request rates), enabling true "Scale-to-Zero" for idle event consumers. When KEDA scales pods beyond current cluster capacity, a **Node Provisioner** (e.g., Karpenter) **would seamlessly take over** at the infrastructure layer. Unhindered by stateful workloads, it **would dynamically provision** perfectly sized compute instances to schedule pending pods. Furthermore, to avoid the overhead of legacy Kubernetes deschedulers, the node provisioner itself handles continuous cluster consolidation—actively bin-packing pods and ruthlessly terminating underutilized nodes during off-hours to minimize cloud billing.
* **Cloud FinOps & Cost Optimization:** The observability and compute layers are engineered with a strict FinOps mindset to minimize future cloud billing. By offloading high-volume telemetry exclusively to highly cost-effective S3-compatible Object Storage, the target architecture would completely avoid the premium costs of persistent cloud Block Storage (e.g., AWS EBS). Furthermore, strict **in-memory batching mechanisms** (`max_block_duration`) are enforced across all TSDB engines (Mimir, Tempo, Pyroscope) to drastically reduce cloud API PUT request charges. Finally, aggressive data lifecycle policies—such as dynamic stream-level retention (e.g., purging 'info'/'debug' logs after 14 days while retaining critical security logs) and strict 7-day TTLs for traces/profiles—guarantee that the storage footprint scales purely on data value, eliminating bloat.

---

## Current Infrastructure Stack

### Core Networking & Storage

| Component | Role |
| :--- | :--- |
| **Cilium** | CNI, Load Balancer, Hubble Observability, East-West routing (eBPF Kube-Proxy replacement) |
| **Envoy Gateway** | North-South Traffic Management (Kubernetes Gateway API) |
| **OpenEBS (LVM)** | High-performance local persistent block storage (LVM LocalPV CSI) |
| **Garage** | Lightweight, distributed S3-compatible object storage (Mimir, Loki, Tempo & Pyroscope backend) |
| **NodeLocal DNSCache (eBPF)** | Caches queries locally to eliminate CoreDNS latency. Uses **Cilium Local Redirect Policies (LRP)** for stateless, iptables-free traffic interception. |

### GitOps, Management & Security

| Component | Role |
| :--- | :--- |
| **ArgoCD** | GitOps Continuous Delivery (CD) engine |
| **Kargo** | Multi-stage Continuous Promotion & Lifecycle Orchestrator |
| **Rancher** | Centralized Kubernetes management and cluster dashboard |
| **KEDA** | Kubernetes Event-driven Autoscaling. Dynamically scales microservice workloads (HPA) based on custom Prometheus (Mimir) telemetry queries. |
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
| **Redpanda** | High-performance, C++ Kafka-compatible event streaming platform. Acts as the primary message broker for microservices **AND** serves as a resilient streaming buffer for high-throughput distributed trace ingestion (Tempo 3.x). |
| **MySQL** | Relational database storage layer for microservice state and order persistence |

### Observability Stack

| Component | Role |
| :--- | :--- |
| **Grafana** | Unified dashboard visualization, Alerting and APM UI |
| **Grafana Alloy** | Primary telemetry pipeline acting as a **Unified Agent**. It features **Intelligent Multi-Tenancy Routing**, **Embedded Host Metrics**, and **Native eBPF Auto-Instrumentation (Beyla)**. It dynamically splits telemetry into distinct 'App' and 'Infra' tenants at the edge, and utilizes OTel filter processors to proactively drop high-cardinality noise (e.g., `/health` and `/metrics` traces) before routing them to the decoupled backends. |
| **Grafana Mimir (Distributed)** | Horizontally scalable, highly available time-series metrics database. Deployed in microservices topology (Isolating Read/Write paths). *(FinOps optimized: S3-backed storage with Memcached acceleration)* |
| **Loki (SimpleScalable)** | Log aggregation and querying. Decouples ingestion from querying to prevent heavy searches from impacting log writes. *(FinOps optimized: S3-backed storage with dynamic stream-level retention)* |
| **Tempo (Distributed)** | Highly scalable tracing backend. Utilizes an event-driven architecture by consuming traces from **Redpanda (Kafka API)** to prevent data loss during traffic spikes. Includes an active Metrics-Generator for RED metrics. *(FinOps optimized: S3-backed with strict 7-day retention)* |
| **Pyroscope (Distributed)** | eBPF-powered continuous application profiling backend. Deployed using the v2 Phlare-based microservices architecture. *(FinOps optimized: S3-backed storage)* |
| **Robusta KRR** | *(Planned)* Kubernetes Resource Recommender for compute right-sizing and minimizing idle over-provisioning |
| **Hubble** | Network and service communication flow observability (via Cilium) |

---

## CI/CD & DevSecOps Pipeline

To ensure secure, automated, and reproducible delivery, the microservices utilize a streamlined **DevSecOps** pipeline powered by **GitHub Actions** and **Helm**:

* **Pre-Build Security Scans:** Source code is actively scanned for hardcoded secrets using **GitLeaks** and statically analyzed for vulnerabilities (SAST) using **Semgrep**.
* **Build & Containerize:** Java applications are built via Maven and packaged into minimal container images using Docker Buildx.
* **Post-Build Vulnerability Scanning:** Before distribution, **Trivy** scans container images for OS and library-level CVEs.
* **Image Registry & Provenance:** Production-ready container images are pushed to the **GitHub Container Registry (GHCR)** alongside generated Software Bill of Materials (SBOMs).
* **Helm Chart Delivery:** Application workloads are packaged into standardized **Helm Charts**, allowing declarative GitOps deployments seamlessly managed by ArgoCD and promoted by Kargo.