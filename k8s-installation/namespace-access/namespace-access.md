# Kubernetes Namespace Access for `sonic-prod-read`

This guide describes how to provide **namespace-limited Kubernetes access** to a user using **client certificates** and **RBAC (Role-Based Access Control)** in Kubernetes.

---

## 🔐 Prerequisites

Before beginning, ensure you have:

- ✅ Kubernetes Cluster Admin access
- ✅ Access to the Kubernetes CA certificate and key (typically located at `/etc/kubernetes/pki/ca.crt` and `ca.key`)
- ✅ `kubectl` installed
- ✅ `openssl` installed
- ✅ A namespace created for the user, e.g. `sonic-prod`

---

## ✅ Step 1: Generate Client Certificates for the User

Generate a private key and a certificate signing request (CSR) for the new user `sonic-prod-read`.

```bash
openssl genrsa -out sonic-prod.key 2048

openssl req -new -key sonic-prod.key -out sonic-prod.csr -subj "/CN=sonic-prod-read"
```

> 📝 `CN` (Common Name) is used by Kubernetes as the username.

---

## ✅ Step 2: Sign the CSR with Your Cluster's Certificate Authority

Use the Kubernetes CA to sign the CSR and generate the user certificate.

```bash
sudo openssl x509 -req -in sonic-prod.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial \
  -out sonic-prod.crt \
  -days 365
```

> 📝 This certificate will be valid for 365 days.

---

## ✅ Step 3: Create a Role and RoleBinding

This step defines what the user is allowed to do within the namespace.

### `sonic-prod-role.yaml`

This file creates a **Role** within the `sonic-prod` namespace, granting full access to all resources and verbs (CRUD operations).

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: sonic-prod-role
  namespace: sonic-prod
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

> ⚠️ **Warning:** This Role grants full access (`*`) to all resources in the namespace. You may want to scope it down to specific resources and verbs (e.g., only pods, get/list/watch).

---

### `sonic-prod-rolebinding.yaml`

This file binds the above Role to the user `sonic-prod-read`.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sonic-prod-role-binding
  namespace: sonic-prod
subjects:
- kind: User
  name: sonic-prod-read
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: sonic-prod-role
  apiGroup: rbac.authorization.k8s.io
```

> 📝 This binds the Role to the user only within the specified namespace.

Apply both configurations:

```bash
kubectl apply -f sonic-prod-role.yaml
kubectl apply -f sonic-prod-rolebinding.yaml
```

---

## ✅ Step 4: Create the Kubeconfig File for the User

### 1. Get the API server endpoint:

```bash
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

### 2. Set up a new Kubeconfig for the user:

```bash
kubectl config set-cluster local-cluster \
  --server=https://192.168.15.34:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --kubeconfig=sonic-prod.kubeconfig

kubectl config set-credentials sonic-prod-read \
  --client-certificate=sonic-prod.crt \
  --client-key=sonic-prod.key \
  --embed-certs=true \
  --kubeconfig=sonic-prod.kubeconfig

kubectl config set-context sonic-prod-context \
  --cluster=local-cluster \
  --user=sonic-prod-read \
  --namespace=sonic-prod \
  --kubeconfig=sonic-prod.kubeconfig

kubectl config use-context sonic-prod-context --kubeconfig=sonic-prod.kubeconfig
```

> 📝 `--embed-certs=true` ensures all necessary certificate data is embedded inside the kubeconfig file, making it portable.

---

## 🧑‍💻 Actions on the User's Machine

### 1. Install `kubectl`

Ensure `kubectl` is installed. You can install it from [Kubernetes documentation](https://kubernetes.io/docs/tasks/tools/).

### 2. Set the `KUBECONFIG` environment variable

```bash
export KUBECONFIG=/path/to/sonic-prod.kubeconfig
```

or copy to kube config
```commandline
sudo cp -i /path/to/sonic-prod.kubeconfig $HOME/.kube/config
```

```commandline
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```


Replace `/path/to/sonic-prod.kubeconfig` with the actual path.

### 3. Verify Access

```bash
kubectl get pods -n sonic-prod
```

> ✅ If everything is set up correctly, the user should see a list of pods in the `sonic-prod` namespace (or a message saying there are none).

---

If Issues:
E0625 18:07:53.236154 1421739 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"http://localhost:8080/api?timeout=32s\": dial tcp 127.0.0.1:8080: connect: connection refused"

✅ Fix:
Run this to set the context in your kubeconfig:

```commandline
kubectl config use-context sonic-prod-context --kubeconfig=$HOME/.kube/config
```
Now try again:

```commandline
kubectl get pods --kubeconfig=$HOME/.kube/config
```

## ✅ Summary

You have now:

- Created and signed client certificates for a user.
- Created a namespaced Role with specific permissions.
- Bound the user to the Role using RoleBinding.
- Configured a secure kubeconfig for the user to access the namespace.

---

## 💡 Suggestions & Notes

- 🔒 **Security Tip:** Instead of giving `"*"` access to everything, consider tailoring roles to least-privilege principles.
- 📁 **Namespace Check:** Ensure the `sonic-prod` namespace exists:  
  ```bash
  kubectl get namespace sonic-prod || kubectl create namespace sonic-prod
  ```
- 🧼 **Optional Cleanup:** To revoke access, delete the RoleBinding or remove the user from the kubeconfig.

---

🎉 The user `sonic-prod-read` now has secure, limited access to the `sonic-prod` namespace!