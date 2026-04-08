# InitBox

> A collection of modular installation scripts to bootstrap tools, platforms, and environments

This repository provides ready-to-use installation scripts, YAML manifests, and step-by-step guides for setting up essential tools and platforms in Kubernetes and bare-metal environments.

---

## Table of Contents

- [Kubernetes Installation](#kubernetes-installation)
- [ArgoCD Installation](#argocd-installation)
- [Monitoring & Observability](#monitoring--observability)
  - [Datadog](#datadog)
  - [Splunk](#splunk)
- [Autoscaling](#autoscaling)
  - [KEDA](#keda)
- [Kubernetes Dashboard](#kubernetes-dashboard)
- [NVIDIA GPU Support](#nvidia-gpu-support)

---

## Kubernetes Installation

Complete guides for setting up Kubernetes clusters on Ubuntu and RHEL systems, including GPU operator installation and ingress controller configuration.

**Topics covered:**
- Kubernetes master and worker node setup (Ubuntu & RHEL)
- GPU Operator installation for NVIDIA GPUs
- Ingress NGINX Controller configuration
- Namespace access and RBAC permissions
- Essential kubectl commands and cluster management

[📖 View Installation Guide](./k8s-installation/k8s-commands.md)

**Quick links:**
- [Node Installation Scripts](./k8s-installation/nodes-installation/)
- [GPU Operator Setup](./k8s-installation/gpu-operator/)
- [Ingress Controller Configuration](./k8s-installation/ingress-nginx-controller-installation/)
- [Namespace Access & RBAC](./k8s-installation/namespace-access/)

---

## ArgoCD Installation

Deploy ArgoCD, a declarative GitOps continuous delivery tool for Kubernetes, with support for custom context paths and namespace-scoped permissions.

**Features:**
- Namespace-only installation (non-HA and HA options)
- Custom context path configuration
- SSL/TLS certificate setup
- Ingress configuration
- Namespace-scoped RBAC permissions

[📖 View Installation Guide](./argocd-installation/README.md)

**Quick links:**
- [Default Installation (/ path)](./argocd-installation/default/)
- [Custom Context Path (/argocd)](./argocd-installation/custom-context-path/)
- [Namespace Permissions](./argocd-installation/namespace-permission/)

---

## Monitoring & Observability

### Datadog

Install Datadog Agent and Cluster Agent using the Datadog Operator with external metrics support for autoscaling.

**Features:**
- Datadog Operator installation via Helm
- Secure credential management with Kubernetes Secrets
- External Metrics Server for HPA integration
- Cluster monitoring and metrics collection

[📖 View Installation Guide](./datadog-installation/datadog-installation.md)

**YAML Manifests:**
- [DatadogAgent CR](./datadog-installation/datadog-agent.yaml)
- [Updated Configuration](./datadog-installation/datadog-agent-updated.yaml)

---

### Splunk

Deploy Splunk Enterprise standalone instance with OpenTelemetry Collector for comprehensive log management and observability.

**Features:**
- Splunk standalone instance deployment with persistent storage
- OpenTelemetry Collector for Kubernetes log aggregation
- HEC (HTTP Event Collector) for data ingestion
- Namespace and pod-level log filtering with annotations
- Custom storage path configuration
- Automated installation script with cleanup options
- Ingress support for external access

**Quick Start:**
- [⚡ 10-Minute Quick Start](./splunk-installation/QUICKSTART.md) - Get Splunk running fast
- [📖 Complete Installation Guide](./splunk-installation/README.md) - Full documentation
- [🔧 Automated Installation Script](./splunk-installation/splunk-standalone-installation.sh) - One-command setup

**Detailed Guides:**
- [OpenTelemetry Collector Setup](./splunk-installation/otel-installation.md)
- [Storage Architecture & Cleanup](./splunk-installation/storage-infos.md)

**Configuration Files:**
- [Splunk Instance YAML](./splunk-installation/splunk-standalone.yaml)
- [OTel Collector Values (Template)](./splunk-installation/otel-values.yaml)
- [OTel Collector Values (Example)](./splunk-installation/otel-values.example.yaml)
- [Ingress Configuration](./splunk-installation/splunk-ingress.yaml)
- [Custom Storage Provisioner](./splunk-installation/local-path-storage.yaml)

---

## Autoscaling

### KEDA

Kubernetes Event-Driven Autoscaling (KEDA) enables event-driven autoscaling for workloads based on external metrics and event sources.

**Features:**
- KEDA installation via kubectl or Helm
- ScaledObject configuration for event-driven scaling
- Integration with external metrics providers
- Support for multiple scalers (queues, databases, custom metrics)

[📖 View Installation Guide](./keda-installation/keda-installation.md)

**YAML Manifests:**
- [KEDA Core v2.17.2](./keda-installation/keda-2.17.2-core.yaml)

---

## Kubernetes Dashboard

Deploy the official Kubernetes Dashboard with token-based authentication for cluster visualization and management.

**Features:**
- Helm-based installation
- ServiceAccount and ClusterRoleBinding setup
- Token generation for secure access
- Port-forward configuration for local access

[📖 View Installation Guide](./kubernetes-dashboard/kubernetes-dashboard%20installation.md)

**YAML Manifests:**
- [ServiceAccount](./kubernetes-dashboard/kd-serviceAccount.yaml)
- [ClusterRoleBinding](./kubernetes-dashboard/kd-clusterRoleBinding.yaml)
- [Token Secret](./kubernetes-dashboard/kd-token.yaml)

---

## NVIDIA GPU Support

Install NVIDIA drivers and CUDA toolkit on Ubuntu and RHEL systems for GPU workload support.

**Platforms:**
- Ubuntu: Driver installation, CUDA toolkit, verification scripts
- RHEL: Repository setup, driver installation, verification

[📁 View NVIDIA Installation Scripts](./nvidia-installation/)

**Quick links:**
- [Ubuntu Installation Scripts](./nvidia-installation/ubuntu/)
- [RHEL Installation Scripts](./nvidia-installation/rhel/)
