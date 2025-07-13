# 🚀 Argo-CD

Argo CD is a powerful, open-source continuous delivery (CD) tool specifically designed for Kubernetes. It follows the **GitOps** methodology, where Git repositories serve as the authoritative source of truth for defining the desired state of applications.

## ✨ Key Features

- **Multi-Cluster Support**: Argo CD can manage deployments across multiple Kubernetes clusters, enabling centralized control.
- **Multiple Configuration Management Tools**: Argo CD supports various tools for defining Kubernetes manifests, including:
    - **Kustomize**: Customize YAML configurations without modifying the base files.
    - **Helm charts**: Use Helm charts for templated Kubernetes resources.
    - **Plain YAML/JSON manifests**: Deploy directly from Kubernetes YAML or JSON files.
- **Web UI and CLI**: Argo CD provides both a user-friendly **Web Interface** and a powerful **Command-Line Interface (CLI)** to manage and monitor applications.
- **Health Checks**: Argo CD continuously monitors the health of deployed applications and can automatically take corrective actions if needed.
- **Synchronization**: Argo CD synchronizes the actual state of the cluster with the desired state stored in Git, ensuring that deployments are always aligned with the version control repository.
- **Rollbacks**: Easily roll back to a previous application version using Git history, ensuring fast recovery in case of failure.

---

## 🛠 Getting Started

### ✅ Prerequisites
- A running Kubernetes cluster.
- `kubectl` configured to access your Kubernetes cluster.
- A Git repository containing your application manifests (or use Helm charts/Kustomize as your repository format).

---

### 📦 Installation (Namespace-Only Access)

### 1️⃣ Namespace Creation

```commandline
kubectl create namespace argocd
```

### 2️⃣ Install Custom Resource Definitions (CRDs)
**Note:** CRDs are not included in `namespace-install.yaml`
```commandline
kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds?ref=stable -n argocd
```

---

### 🔀 Option-1 Default ContextPath Installation (/)
### 🔧 Choose an Installation Type

🔹 **Non-HA Installation (Not recommended for production)**
```commandline
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/namespace-install.yaml -n argocd
```

🔹 **High Availability (HA) Installation (Recommended for production)**\
Requires a multi-node setup for running multiple replicas.
```commandline
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/refs/heads/master/manifests/ha/namespace-install.yaml -n argocd
```

🔐 SSL Certificate (Optional for HTTPS)\
Create a self-signed certificate for local testing:

```commandline
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -out self-signed-tls.crt -keyout self-signed-tls.key \
  -subj "/CN=argocd-dev-local.com" \
  -reqexts SAN -extensions SAN \
  -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\\nsubjectAltName=DNS:argocd-dev-local.com,DNS:*.argocd-dev-local.com"))
```

Create TLS secret:
```commandline
kubectl -n argocd create secret tls argocd-tls-cert --key=self-signed-tls.key --cert=self-signed-tls.crt
```

🌐 Configure Ingress
Default Path (/)
```commandline
kubectl apply -f default/argocd-ingress.yaml -n argocd
```
Web UI URL: https://argocd-dev-local.com

👤 Retrieve Admin Password
```commandline
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

---

### 🔀 Option-2 Custom ContextPath Installation (`/argocd`)

1️⃣ Apply Custom ConfigMap
```commandline
kubectl apply -f custom-context-path/namespace-install-contextpath-configmap.yaml -n argocd
```

2️⃣ Install Argo CD
```commandline
kubectl apply -f custom-context-path/namespace-install-contextpath.yaml -n argocd
```

🔐 SSL Certificate (Optional for HTTPS)\
Create a self-signed certificate for local testing:

```commandline
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\
  -out self-signed-tls.crt -keyout self-signed-tls.key \\
  -subj "/CN=argocd-dev-local.com" \\
  -reqexts SAN -extensions SAN \\
  -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\\nsubjectAltName=DNS:argocd-dev-local.com,DNS:*.argocd-dev-local.com"))
```

🌐 Configure Ingress
```commandline
kubectl apply -f custom-context-path/argocd-ingress-context.yaml -n argocd
```

Web UI URL: https://argocd-dev-local.com/argocd

👤 Retrieve Admin Password
```commandline
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

---

### 🛡 Role Configuration (Namespace-Scoped Access)
By default, Argo CD installed with `namespace-install.yaml` cannot schedule pods in other namespaces. You'll need to create roles and bindings.

1️⃣ Create Role in Target Namespace (e.g., `dev`)
```commandline
kubectl apply -f namespace-permission/argocd-dev-role.yaml
```

2️⃣ Bind Role to Argo CD Components\
For `argocd-application-controller`
```commandline
kubectl apply -f namespace-permission/argocd-application-dev-rolebinding.yaml
```

For `argocd-server`
```commandline
kubectl apply -f namespace-permission/argocd-server-dev-rolebinding.yaml
```

These bindings grant Argo CD the necessary permissions to deploy and manage workloads in the target namespace.

---

📚 References:\
[Argo CD Official Documentation](https://argo-cd.readthedocs.io/en/stable/)\
[Argo CD GitHub Repository](https://github.com/argoproj/argo-cd)