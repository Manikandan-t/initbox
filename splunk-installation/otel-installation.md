# OpenTelemetry Collector - Detailed Setup

This guide covers advanced OpenTelemetry Collector configuration and troubleshooting.

> **Quick setup?** See the main [README.md](./README.md) for basic installation.

---

## Installation

### 1. Create HEC Token in Splunk

1. Splunk UI → Settings → Data Inputs → HTTP Event Collector
2. Click **Global Settings**:
   - Enable: **On**
   - Enable SSL: **Off** (for testing)
   - Save
3. Click **New Token**:
   - Name: `k8s-otel-token`
   - Next → Select index `main` → Review → Submit
4. **Copy the token value**

### 2. Configure `otel-values.yaml`

```yaml
clusterName: "production-cluster"  # Your cluster name

splunkPlatform:
  # For in-cluster Splunk
  endpoint: "http://splunk-s1-standalone-service.splunk.svc.cluster.local:8088/services/collector"

  # For external Splunk
  # endpoint: "https://splunk.example.com:8088/services/collector"

  token: "YOUR-HEC-TOKEN"  # Paste token from step 1
  index: "main"
  insecureSkipVerify: true  # Set false for valid HTTPS

logsCollection:
  containers:
    enabled: true
    useSplunkIncludeAnnotation: true  # Only collect annotated pods
```

### 3. Install with Helm

```bash
helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
helm repo update

kubectl create namespace splunk-otel

helm install splunk-otel-collector \
  -f otel-values.yaml \
  splunk-otel-collector-chart/splunk-otel-collector \
  -n splunk-otel
```

### 4. Annotate Resources

```bash
# Annotate namespace (all pods in namespace)
kubectl annotate namespace my-namespace splunk.com/include=true

# Annotate specific deployment
kubectl annotate deployment my-app -n my-namespace splunk.com/include=true

# Remove annotation
kubectl annotate namespace my-namespace splunk.com/include-
```

---

## Verification

### Check Collector Pods

```bash
kubectl get pods -n splunk-otel
```

Expected output:
```
NAME                                     READY   STATUS    RESTARTS   AGE
splunk-otel-collector-agent-xxxxx        1/1     Running   0          2m
```

### Check Collector Logs

```bash
kubectl logs -n splunk-otel -l app=splunk-otel-collector-agent --tail=50
```

Should NOT see errors like:
- `400 Bad Request`
- `403 Forbidden`
- `Invalid token`

### Test HEC from Collector Pod

```bash
kubectl exec -n splunk splunk-s1-standalone-0 -- curl -v \
  http://splunk-s1-standalone-service.splunk.svc.cluster.local:8088/services/collector \
  -H "Authorization: Splunk YOUR-TOKEN" \
  -d '{"event": "test from curl", "index": "main"}'
```

Expected: `{"text":"Success","code":0}`

### Search Logs in Splunk

Splunk UI → Search & Reporting:
```
index="main"
```

---

## Advanced Configuration

### Collect Metrics and Traces

```yaml
clusterReceiver:
  enabled: true

metricsEnabled: true
tracesEnabled: true
```

### Exclude Specific Namespaces

```yaml
logsCollection:
  containers:
    enabled: true
    excludeNamespaces:
      - kube-system
      - kube-public
```

### Add Custom Fields

```yaml
splunkPlatform:
  fields:
    environment: "production"
    region: "us-east-1"
    team: "platform"
```

### Resource Limits

```yaml
agent:
  resources:
    requests:
      cpu: 200m
      memory: 500Mi
    limits:
      cpu: 500m
      memory: 1Gi
```

### Filter by Log Level

```yaml
logsCollection:
  containers:
    minLogLevel: "info"  # Options: debug, info, warning, error
```

---

## Troubleshooting

### 400 Bad Request / 403 Forbidden

**Cause:** Invalid HEC token or HEC not enabled

**Fix:**
1. Verify HEC enabled: Splunk UI → Settings → Data Inputs → HEC → Global Settings
2. Verify token is correct in `otel-values.yaml`
3. Recreate token if needed

### No Logs Appearing

**Check 1 - Annotations:**
```bash
kubectl get namespace my-namespace -o yaml | grep splunk.com/include
```

**Check 2 - Collector Running:**
```bash
kubectl get pods -n splunk-otel
kubectl logs -n splunk-otel -l app=splunk-otel-collector-agent
```

**Check 3 - HEC Endpoint:**
```bash
# From inside cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://splunk-s1-standalone-service.splunk.svc.cluster.local:8088/services/collector/health
```

Expected: `{"text":"HEC is healthy","code":200}`

### Configuration Changes Not Applied

After editing `otel-values.yaml`:

```bash
# Upgrade the Helm release
helm upgrade splunk-otel-collector \
  -f otel-values.yaml \
  splunk-otel-collector-chart/splunk-otel-collector \
  -n splunk-otel

# Force restart collector pods
kubectl rollout restart daemonset splunk-otel-collector-agent -n splunk-otel

# Watch restart
kubectl get pods -n splunk-otel -w
```

### High Memory Usage

Reduce resource usage:

```yaml
logsCollection:
  containers:
    useSplunkIncludeAnnotation: true  # Don't collect all logs
    excludeNamespaces:
      - kube-system

agent:
  resources:
    limits:
      memory: 512Mi  # Set appropriate limit
```

### Connection Timeouts

For external Splunk over slow networks:

```yaml
splunkPlatform:
  timeout: 30s  # Increase timeout
```

---

## Per-Pod Annotation

You can annotate individual pods (not just deployments):

```bash
# Annotate running pod (temporary - lost on restart)
kubectl annotate pod my-pod-xxx -n my-namespace splunk.com/include=true

# Annotate via pod template in deployment (persistent)
kubectl patch deployment my-app -n my-namespace -p '
{
  "spec": {
    "template": {
      "metadata": {
        "annotations": {
          "splunk.com/include": "true"
        }
      }
    }
  }
}'
```

---

## Uninstall

```bash
helm uninstall splunk-otel-collector -n splunk-otel
kubectl delete namespace splunk-otel
```

---

## Configuration Reference

### Full `otel-values.yaml` Example

```yaml
clusterName: "production-k8s"

splunkPlatform:
  endpoint: "http://splunk-s1-standalone-service.splunk.svc.cluster.local:8088/services/collector"
  token: "12345678-1234-1234-1234-123456789abc"
  index: "main"
  insecureSkipVerify: true
  source: "kube:container"
  sourcetype: "_json"
  fields:
    environment: "production"
    region: "us-west-2"

logsCollection:
  containers:
    enabled: true
    useSplunkIncludeAnnotation: true
    excludeNamespaces:
      - kube-system
      - kube-public

clusterReceiver:
  enabled: false

gateway:
  enabled: false

agent:
  resources:
    requests:
      cpu: 200m
      memory: 500Mi
    limits:
      cpu: 500m
      memory: 1Gi
```

---

## Multi-Cluster Setup

For multiple Kubernetes clusters sending to same Splunk:

**Cluster 1:**
```yaml
clusterName: "us-west-prod"
splunkPlatform:
  fields:
    cluster: "us-west-prod"
    region: "us-west"
```

**Cluster 2:**
```yaml
clusterName: "eu-central-prod"
splunkPlatform:
  fields:
    cluster: "eu-central-prod"
    region: "eu-central"
```

Search in Splunk:
```
index="main" cluster="us-west-prod"
index="main" region="eu-central"
```

---

## Useful Splunk Searches

```spl
# All logs from specific cluster
index="main" cluster_name="production-k8s"

# Logs from specific namespace
index="main" k8s.namespace.name="default"

# Logs from specific pod
index="main" k8s.pod.name="my-app-*"

# Error logs only
index="main" level="error"

# Logs from last hour
index="main" earliest=-1h

# Count by namespace
index="main" | stats count by k8s.namespace.name

# Top 10 pods by log volume
index="main" | stats count by k8s.pod.name | sort -count | head 10
```

---

## References

- [Splunk OTel Collector Helm Chart](https://github.com/signalfx/splunk-otel-collector-chart)
- [Splunk HEC Documentation](https://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
