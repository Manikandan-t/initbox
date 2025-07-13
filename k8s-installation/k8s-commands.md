# Kubernetes Deployment Commands (Namespace: `sonic-prod`)

This guide provides essential `kubectl` commands for managing Kubernetes resources in the `sonic-prod` namespace.

---

## 📦 Apply / Delete YAML

```bash
kubectl apply -f <file>.yaml -n sonic-prod       # Apply manifest
kubectl delete -f <file>.yaml -n sonic-prod      # Delete resources from manifest
```

---

## 🐳 Pods

```bash
kubectl get pods -n sonic-prod                                 # List all pods
kubectl logs --follow --tail=100 <pod-name> -n sonic-prod      # View logs of a pod
kubectl describe pod <pod-name> -n sonic-prod                  # Describe a specific pod
kubectl exec -it <pod-name> -n sonic-prod -- /bin/sh           # Shell into a pod (sh)
kubectl exec -it <pod-name> -n sonic-prod -- /bin/bash         # Shell into a pod (bash, if available)
kubectl delete pod <pod-name> -n sonic-prod                    # Delete a specific pod
```

---

## 🌐 Services & Ingress

```bash
kubectl get svc -n sonic-prod                # List services
kubectl describe svc <svc-name> -n sonic-prod # Describe a specific service
kubectl get ingress -n sonic-prod            # List ingress resources
kubectl describe ingress <name> -n sonic-prod # Describe a specific ingress
```

---

## ⚙️ Deployment & ConfigMap

```bash
kubectl get deployments -n sonic-prod                         # List deployments
kubectl describe deployment <name> -n sonic-prod              # Describe a specific deployment
kubectl rollout restart deployment <name> -n sonic-prod       # Restart a deployment
kubectl get configmap <name> -n sonic-prod -o yaml            # Get ConfigMap in YAML format
kubectl edit configmap <name> -n sonic-prod                   # Edit a ConfigMap
```

---

## 🗂️ Namespace Management

```bash
kubectl create namespace sonic-prod    # Create the namespace
kubectl get ns                         # List all namespaces
```

---

## 🧩 Persistent Volumes

```bash
kubectl get pv                          # Get Persistent Volume info
kubectl get pvc -n sonic-prod           # Get Persistent Volume Claim info
kubectl describe pvc <name> -n sonic-prod # Describe a specific PVC
```

---

## 🧠 Node Management

```bash
kubectl get nodes                                      # List cluster nodes
kubectl describe node <node-name>                      # Describe a node
kubectl taint nodes --all node-role.kubernetes.io/master-         # Allow pods on master
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  # Allow pods on control-plane
```

---

## 🔐 Cluster Join (on Master Node)

```bash
kubeadm token create --print-join-command              # Get node join command
```

---

## 🔄 Miscellaneous

```bash
kubectl get all -n sonic-prod                          # Get all resources in namespace
kubectl top pods -n sonic-prod                         # View pod resource usage (requires metrics server)
kubectl get events -n sonic-prod --sort-by=.metadata.creationTimestamp   # View recent events
```