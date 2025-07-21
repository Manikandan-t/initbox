# Kubernetes Dashboard Installation Guide

This guide explains how to install and access the Kubernetes Dashboard using Helm, including how to generate an access token and set up the required roles.

---

## Prerequisites

- A running Kubernetes cluster  
- Helm installed and configured  
- `kubectl` CLI installed and configured  

---

## Installation Steps

### 1. Add the Kubernetes Dashboard Helm repository

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
```

### 2. Install or upgrade the Kubernetes Dashboard

```bash
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --create-namespace --namespace kubernetes-dashboard
```

You should see output similar to:

```commandline
Release "kubernetes-dashboard" does not exist. Installing it now.
NAME: kubernetes-dashboard
LAST DEPLOYED: <timestamp>
NAMESPACE: kubernetes-dashboard
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
*************************************************************************************************
*** PLEASE BE PATIENT: Kubernetes Dashboard may need a few minutes to get up and become ready ***
*************************************************************************************************

Congratulations! You have just installed Kubernetes Dashboard in your cluster.
```

Accessing the Kubernetes Dashboard
Logging in to the dashboard
Now that we can access the Dashboard in our browser we need to log in to it. This requires a Service Account, Cluster Role Binding and Token/Secret.

We are going to create three YAML files for this purpose: serviceAccount.yaml, clusterRoleBinding.yaml and token.yaml.

# kd-serviceAccount.yaml
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
```


# kd-clusterRoleBinding.yaml

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard

```

# kd-token.yaml

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: "admin-user"
type: kubernetes.io/service-account-token
```

apply the YAML files on the cluster.

```bash
kubectl apply -f kd-serviceAccount.yaml
kubectl apply -f kd-clusterRoleBinding.yaml
kubectl apply -f kd-token.yaml
```


Forward the dashboard proxy port to your local machine
```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```

Open the dashboard
Navigate to:

```bash
https://localhost:8443
```

To finally get the password (secret) we need to log in to the dashboard, run
```bash
kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d
```
