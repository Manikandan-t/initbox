# 🚀 Datadog Agent Installation via Operator (Using Secret for API Keys)

This guide describes how to install the **Datadog Agent and Cluster Agent** on Kubernetes using the **Datadog Operator**, with credentials securely mounted from a **Kubernetes Secret**, and enabling **External Metrics** support for autoscaling.

---

## 🔐 Prerequisites

- Kubernetes cluster (v1.10+)
- `kubectl` and `helm` installed
- Datadog account with API & App keys

---

## 📥 Step 1: Install Datadog Operator with Helm

Add the Datadog Helm repo, update, and install the Operator in the `datadog` namespace:

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update

kubectl create namespace datadog

helm install datadog-operator datadog/datadog-operator -n datadog
```

This deploys the operator which manages the DatadogAgent custom resources.

---

## 📦 Step 2: Create the Datadog Secret

Store your **Datadog API key** and **App key** in a Kubernetes Secret:

```bash
kubectl create secret generic datadog-secret \
  --from-literal=api-key='<DATADOG_API_KEY>' \
  --from-literal=app-key='<DATADOG_APP_KEY>' \
  -n datadog
```

> 🔒 Keep this secret secure! It grants access to your Datadog organization.


in specific node:
helm upgrade --install datadog-operator datadog/datadog-operator \
  --namespace datadog \
  --set datadog.apiKeyExistingSecret=datadog-secret \
  --set datadog.appKeyExistingSecret=datadog-secret \
  --set datadog.apiKeyExistingSecretKey=api-key \
  --set datadog.appKeyExistingSecretKey=app-key \
  --set nodeSelector."kubernetes\.io/hostname"=sonic


If Error from server (NotFound): the server could not find the requested resource (post datadogagents.datadoghq.com)
:
kubectl apply -f https://raw.githubusercontent.com/DataDog/datadog-operator/main/config/crd/bases/v1/datadoghq.com_datadogagents.yaml

---

## ⚙️ Step 3: Deploy DatadogAgent Custom Resource

Create a file named `datadog-agent.yaml` with the following content:

```yaml
apiVersion: datadoghq.com/v2alpha1
kind: DatadogAgent
metadata:
  name: datadog
  namespace: datadog
spec:
  global:
    site: us5.datadoghq.com         # Change to your Datadog site (e.g., us3, eu1)
    clusterName: kubernetes         # Logical cluster name in Datadog
    credentials:
      apiSecret:
        secretName: datadog-secret
        keyName: api-key
      appSecret:
        secretName: datadog-secret
        keyName: app-key
  features:
    externalMetricsServer:
      enabled: true
```

Apply the manifest:

```bash
kubectl apply -f datadog-agent.yaml
```

This will deploy the **Agent DaemonSet** and **Cluster Agent Deployment**, configured to serve external metrics to Kubernetes.

---

## ✅ Verify External Metrics Integration

Check that the external metrics API is available:

```bash
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq
```

If successful, you'll see available external metrics listed.

---

## 📈 Use Datadog Metrics with HPA

You can now scale workloads using external metrics from Datadog.

Example HPA manifest:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
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
          name: custom.metric.name
        target:
          type: AverageValue
          averageValue: "10"
```

Make sure the metric is already being sent to Datadog before applying the HPA.

---

## 🔍 Troubleshooting

- Check Cluster Agent logs:
  ```bash
  kubectl logs -n datadog -l app=datadog-cluster-agent
  ```

- Check Agent DaemonSet pods:
  ```bash
  kubectl get pods -n datadog -l app=datadog-agent
  ```

- Verify metrics provider status:
  ```bash
  kubectl get apiservices | grep external.metrics
  ```

---

## 📝 Notes

- You must install the [Datadog Operator](https://docs.datadoghq.com/containers/kubernetes/operator/) **before** applying the `DatadogAgent` CR.
- Replace `us5.datadoghq.com` with the site for your Datadog region:
  - `us3.datadoghq.com`
  - `us5.datadoghq.com`
  - `eu1.datadoghq.com`
  - `ddog-gov.com` (GovCloud)

---

## 📚 References

- [Datadog Operator Installation Docs](https://docs.datadoghq.com/containers/kubernetes/operator/)
- [External Metrics with Datadog](https://docs.datadoghq.com/agent/cluster_agent/external_metrics/)

---

🎉 Datadog Agent and Cluster Agent are now running in your cluster using secrets, with support for external metrics and autoscaling!