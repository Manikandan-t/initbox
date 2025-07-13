# Ingress Controller Setup in Kubernetes (Namespace: sonic-prod)

## Overview

An **Ingress Controller** is an advanced solution for managing external access to services in Kubernetes. It operates at the HTTP/HTTPS layer and provides features such as:

- Routing
- Load balancing
- SSL termination

---

## How Ingress Controller Works

- An Ingress Controller (e.g., NGINX, Traefik) listens for Ingress resources defined in your cluster and configures a proxy/load balancer accordingly.
- Traffic is routed based on rules defined in Ingress resources (e.g., hostnames, paths).

---

## Benefits of Ingress Controller

- **Advanced traffic management:**
  - Path-based routing (e.g., `/app1`, `/app2`)
  - Host-based routing (e.g., `app1.example.com`, `app2.example.com`)
- Centralized entry point for multiple services, reducing the need for individual external IPs.
- SSL termination for HTTPS traffic.
- Cost-effective for multi-service environments (a single external IP for all services).

---

## Installing NGINX Ingress Controller

### Step 1: Add the NGINX ingress Helm repository

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

### Step 2: Search for available release versions

```bash
helm search repo ingress-nginx
```

### Step 3: Install the NGINX ingress controller in the `sonic-prod` namespace

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx -n sonic-prod
```

---

## Step 4: Set the External IP for the LoadBalancer

Edit the service to configure the external IP and ensure the service type is `LoadBalancer`:

```bash
kubectl edit svc ingress-nginx-controller -n sonic-prod
```

Modify or add the following fields:

```yaml
type: LoadBalancer
externalIPs:
- 192.168.10.170
```

---

## Step 5: Verify the External IP is set

Check the service details:

```bash
kubectl get service --namespace sonic-prod ingress-nginx-controller --output wide
```

Expected output example:

```
NAME                     TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                          AGE
ingress-nginx-controller LoadBalancer   10.108.29.121   192.168.10.170  80:30345/TCP,443:30588/TCP       7d16h
```

---

**Labels on the ingress-nginx-controller pod:**

```
app.kubernetes.io/component=controller
app.kubernetes.io/instance=ingress-nginx
app.kubernetes.io/name=ingress-nginx
```
