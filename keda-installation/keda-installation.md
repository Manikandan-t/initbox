# 🚀 KEDA (Kubernetes Event-Driven Autoscaling) Installation Guide

[KEDA](https://keda.sh/) enables event-driven autoscaling for Kubernetes workloads, allowing you to scale based on external metrics (e.g., queues, databases, custom metrics).

---

## 🔐 Prerequisites

- Kubernetes cluster (v1.16+ recommended)
- `kubectl` installed and configured
- Metrics Server installed and working (`kubectl top nodes` works)
- (Optional) Helm installed if using Helm method

---

## 1. Install KEDA

### A. Using kubectl (YAML manifests)

Apply the official KEDA manifests directly:

```bash
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.17.2/keda-2.17.2-core.yaml
```

> Replace `2.17.2` with the latest stable version from the [KEDA releases page](https://github.com/kedacore/keda/releases).

### B. Using Helm

Add the KEDA Helm repo and install:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

kubectl create namespace keda

helm install keda kedacore/keda --namespace keda
```

---

## 2. Verify KEDA Installation

Check that KEDA pods are running in `keda` namespace:

```bash
kubectl get pods -n keda
```

You should see pods like:

- `keda-operator-xxxxx`
- `keda-metrics-apiserver-xxxxx`

---

## 3. Using KEDA ScaledObjects

KEDA uses **ScaledObjects** to define autoscaling based on external event sources or metrics.

Example: scale deployment based on queue length

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: queue-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: my-deployment
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
  - type: azure-queue
    metadata:
      queueName: myqueue
      connectionFromEnv: AZURE_STORAGE_CONNECTION_STRING
      queueLength: "5"
```

---

## 4. Using KEDA with External Metrics (Datadog, Prometheus, etc.)

KEDA can scale based on external/custom metrics exposed via the Kubernetes external metrics API.

- Make sure your metrics provider (e.g., Datadog Cluster Agent) exposes external metrics.
- Create an HPA using `metrics.k8s.io` or `external.metrics.k8s.io` APIs.
- KEDA can read from these metrics and scale accordingly.

Example HPA with external metrics:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: external-metrics-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: External
    external:
      metric:
        name: custom.external.metric
      target:
        type: AverageValue
        averageValue: "10"
```

---

## 5. Uninstall KEDA

If you want to remove KEDA:

```bash
kubectl delete -f https://github.com/kedacore/keda/releases/latest/download/keda-2.10.0.yaml
```

or if installed via Helm:

```bash
helm uninstall keda -n keda
kubectl delete namespace keda
```

---

## 💡 Tips & Best Practices

- Always monitor your scaled deployments to avoid unexpected scale-downs.
- Use **ScaledJobs** for batch workloads.
- Test triggers carefully with small min/max replica counts.
- Check KEDA operator logs for troubleshooting:

  ```bash
  kubectl logs -n keda -l app=keda-operator
  ```

- Keep KEDA and Metrics Server versions compatible with your Kubernetes cluster.

---

## 📚 References

- [KEDA installation](https://keda.sh/docs/2.9/deploy/)
- [Official KEDA Documentation](https://keda.sh/docs/)
- [KEDA Scalers Catalog](https://keda.sh/docs/latest/scalers/)
- [KEDA GitHub Releases](https://github.com/kedacore/keda/releases)

---

🎉 You’re ready to start autoscaling Kubernetes workloads based on events with KEDA!
