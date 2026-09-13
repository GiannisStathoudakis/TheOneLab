This directory serves as a **blueprint and practical showcase** of the security posture for the Kubernetes cluster, demonstrating a **Defense in Depth** strategy across multiple layers of the infrastructure. 

While these manifests act as a foundational baseline rather than an exhaustive list of every production rule, they illustrate the core architectural mindset: instead of relying on a single perimeter, security is implemented at the Node, Network, Pod, and Admission levels.

## Architecture Structure

* **`/cilium`**: Examples of eBPF-based Node-level security, protecting the host machines and core Kubernetes components.
* **`/kubernetes`**: Blueprints for native API restrictions and Micro-segmentation (Zero-Trust NetworkPolicies, Pod Security Standards, and Resource limits).
* **`/kyverno`**: Example of Admission Control policies, enforcing configuration best practices (such as workload immutability) before workloads are accepted by the API Server.