# Splunk Enterprise on Kubernetes

Complete setup for Splunk Enterprise standalone instance with OpenTelemetry log collection.

---

## Quick Start (5 minutes)

```bash
# 1. Run the installation script
chmod +x splunk-standalone-installation.sh
./splunk-standalone-installation.sh

# 2. Wait for pod to be ready (3-5 minutes)
kubectl get pods -n splunk -w

# 3. Get admin password
kubectl get secret -n splunk splunk-s1-standalone-secret-v1 -o jsonpath='{.data.password}' | base64 -d && echo

# 4. Access Splunk UI
kubectl port-forward -n splunk svc/splunk-s1-standalone-service 8000:8000
# Open: http://localhost:8000
# Login: admin / <password from step 3>
```

---

## What Gets Installed

- **Splunk Enterprise** standalone instance
- **Local-path storage provisioner** for persistent storage (40GB for data, 4GB for config)
- **Splunk Operator** v3.0.0 to manage Splunk instance

---

## Installation Options

### Option 1: Automated (Recommended)

```bash
# Fresh install
./splunk-standalone-installation.sh

# Clean up and reinstall
./splunk-standalone-installation.sh --cleanup

# Use custom storage path
./splunk-standalone-installation.sh --custom-storage

# See all options
./splunk-standalone-installation.sh --help
```

### Option 2: Manual Installation

```bash
# 1. Install storage provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 2. Install Splunk Operator
kubectl create namespace splunk-operator
kubectl apply --server-side -f https://github.com/splunk/splunk-operator/releases/download/3.0.0/splunk-operator-cluster.yaml -n splunk-operator
kubectl wait --for=condition=available deployment/splunk-operator-controller-manager -n splunk-operator --timeout=300s

# 3. Accept Splunk license
kubectl patch deployment splunk-operator-controller-manager -n splunk-operator --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "SPLUNK_GENERAL_TERMS", "value": "--accept-sgt-current-at-splunk-com"}}]'

# 4. Deploy Splunk
kubectl create namespace splunk
kubectl apply -f splunk-standalone.yaml -n splunk
```

---

## Add Log Collection (OpenTelemetry Collector)

### 1. Configure HEC in Splunk

1. Access Splunk UI: Settings → Data Inputs → HTTP Event Collector
2. Click **Global Settings**: Enable HEC, Disable SSL → Save
3. Click **New Token**: Name it `k8s-logs`, select index `main` → Submit
4. **Copy the token**

### 2. Edit `otel-values.yaml`

```yaml
clusterName: "my-cluster"              # Change this
splunkPlatform:
  token: "YOUR-HEC-TOKEN-HERE"         # Paste token from step 1
  # Rest can stay as-is for in-cluster Splunk
```

### 3. Install OpenTelemetry Collector

```bash
helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
helm repo update

kubectl create namespace splunk-otel
helm install splunk-otel-collector \
  -f otel-values.yaml \
  splunk-otel-collector-chart/splunk-otel-collector \
  -n splunk-otel
```

### 4. Annotate Namespaces/Pods to Send Logs

```bash
# Annotate namespace
kubectl annotate namespace default splunk.com/include=true

# Or annotate specific deployment
kubectl annotate deployment my-app -n default splunk.com/include=true
```

### 5. Search Logs in Splunk

In Splunk UI → Search & Reporting:
```
index="main"
```

---

## Add Ingress (Optional)

Edit `splunk-ingress.yaml`:
- Change `your-splunk-domain.com` to your actual domain
- Apply: `kubectl apply -f splunk-ingress.yaml -n splunk`

---

## Customization

### Change Storage Path

Edit `local-path-storage.yaml` line 133:
```yaml
"paths":["/your/custom/path"]  # Default: /opt/local-path-provisioner
```

Then install with:
```bash
./splunk-standalone-installation.sh --custom-storage
```

### Change Storage Sizes

Edit `splunk-standalone.yaml`:
```yaml
varVolumeStorageConfig:
  storageCapacity: 100Gi  # Change from default 40Gi
etcVolumeStorageConfig:
  storageCapacity: 10Gi   # Change from default 4Gi
```

### Change Web UI Path

Edit `splunk-standalone.yaml`:
```yaml
# Remove or comment out this section to use default path (/)
defaults: |
  splunk:
    web:
      root_endpoint: /splunkui
```

If you change this, update `splunk-ingress.yaml` to match.

---

## Configure Data Retention (IMPORTANT)

⚠️ **Without this, your disk will fill up!**

1. In Splunk UI: Settings → Indexes
2. Click **Edit** on `main` index
3. Set **Max Size of Entire Index**: `32000` MB (for 40GB storage)
4. Or set **Max Hot/Warm/Cold Time**: `30d` (30 days retention)
5. Click **Save**

---

## Common Commands

```bash
# Get Splunk password
kubectl get secret -n splunk splunk-s1-standalone-secret-v1 -o jsonpath='{.data.password}' | base64 -d && echo

# Port-forward Splunk UI
kubectl port-forward -n splunk svc/splunk-s1-standalone-service 8000:8000

# Check Splunk status
kubectl get pods -n splunk
kubectl logs -n splunk splunk-s1-standalone-0 --tail=50

# Check log collector status
kubectl get pods -n splunk-otel
kubectl logs -n splunk-otel -l app=splunk-otel-collector-agent --tail=50

# Restart log collector after config change
helm upgrade splunk-otel-collector -f otel-values.yaml \
  splunk-otel-collector-chart/splunk-otel-collector -n splunk-otel
kubectl rollout restart daemonset splunk-otel-collector-agent -n splunk-otel

# Test HEC
kubectl exec -n splunk splunk-s1-standalone-0 -- curl -k \
  http://localhost:8088/services/collector \
  -H "Authorization: Splunk YOUR-TOKEN" \
  -d '{"event": "test", "index": "main"}'
```

---

## Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod splunk-s1-standalone-0 -n splunk
kubectl get pvc -n splunk  # Check if PVCs are Bound
```

### No Logs in Splunk
- Check HEC is enabled: Splunk UI → Settings → Data Inputs → HTTP Event Collector
- Check collector pods: `kubectl get pods -n splunk-otel`
- Check collector logs: `kubectl logs -n splunk-otel -l app=splunk-otel-collector-agent`
- Verify annotation: `kubectl get namespace default -o yaml | grep splunk.com/include`

### Disk Full
- Configure data retention (see above)
- Check disk usage on node: `df -h /opt/local-path-provisioner`

---

## Storage Details

### Where is Data Stored?

By default: `/opt/local-path-provisioner/` on your Kubernetes nodes

Files created:
- `pvc-var-splunk-s1-standalone-0-xxx/` - Index data (logs you collect)
- `pvc-etc-splunk-s1-standalone-0-xxx/` - Splunk configuration

### Cleanup Storage

Storage is automatically deleted when you run:
```bash
kubectl delete standalone s1 -n splunk
```

### Custom Storage Path

1. Edit `local-path-storage.yaml` line 133
2. Install with: `./splunk-standalone-installation.sh --custom-storage`

Or change at runtime:
```bash
kubectl edit configmap local-path-config -n local-path-storage
# Change the paths value, save, then:
kubectl rollout restart deployment local-path-provisioner -n local-path-storage
```

---

## Complete Uninstall

```bash
kubectl delete standalone s1 -n splunk
kubectl delete namespace splunk splunk-otel splunk-operator
kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
```

---

## Production Considerations

⚠️ **This setup uses local-path storage which is NOT production-ready**

For production:
- Use distributed storage (NFS, Ceph, cloud storage like EBS/Azure Disk)
- Deploy Splunk in clustered mode (not standalone)
- Enable TLS/SSL for all connections
- Set resource limits on pods
- Configure proper backup and monitoring
- Use proper DNS and certificates for ingress

This installation is ideal for:
- ✅ Development and testing
- ✅ Proof of concept
- ✅ Learning and demos
- ❌ Production workloads (without modifications)

---

## Files

| File | Purpose |
|------|---------|
| `README.md` | This guide |
| `splunk-standalone-installation.sh` | Automated installation script |
| `splunk-standalone.yaml` | Splunk instance configuration |
| `local-path-storage.yaml` | Storage provisioner with custom path |
| `splunk-ingress.yaml` | Ingress configuration |
| `otel-values.yaml` | OpenTelemetry Collector configuration |
| `otel-installation.md` | Detailed OTel setup and troubleshooting |

---

## References

- [Splunk Operator](https://splunk.github.io/splunk-operator/)
- [OpenTelemetry Collector](https://github.com/signalfx/splunk-otel-collector-chart)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
