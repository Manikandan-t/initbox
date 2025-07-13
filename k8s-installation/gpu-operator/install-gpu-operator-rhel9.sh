#!/bin/bash
# NVIDIA GPU Operator Setup for RHEL 9 / CentOS Stream 9

set -euo pipefail

echo "[INFO] Checking NVIDIA driver and CUDA installation..."
if command -v nvidia-smi &>/dev/null; then
  DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)
  CUDA_VERSION=$(nvidia-smi | grep -i "CUDA Version" | sed -E 's/.*CUDA Version: ([0-9.]+).*/\1/')

  nvidia-smi

  echo "[INFO] NVIDIA driver is installed. Version: $DRIVER_VERSION"
  echo "[INFO] CUDA version reported by nvidia-smi: $CUDA_VERSION"
else
  echo "[WARNING] 'nvidia-smi' not found. NVIDIA driver and CUDA may not be installed."
fi

echo "[1/7] Adding NVIDIA Container Toolkit repository..."
sudo curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
  -o /etc/yum.repos.d/nvidia-container-toolkit.repo

echo "[2/7] Installing NVIDIA Container Toolkit..."
sudo dnf clean all
sudo dnf install -y nvidia-container-toolkit

echo "[3/7] Configuring containerd runtime..."
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart containerd
sudo systemctl enable --now containerd

if ! grep -q "\[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.nvidia\]" /etc/containerd/config.toml; then
  echo "[ERROR] NVIDIA runtime not configured in containerd."
  exit 1
fi

echo "[4/7] Installing Helm (if not already installed)..."
if ! command -v helm &>/dev/null; then
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  rm -f get_helm.sh
else
  echo "[INFO] Helm is already installed."
fi

echo "[5/7] Adding NVIDIA Helm repo..."
helm repo add nvidia https://nvidia.github.io/gpu-operator
helm repo update

echo "[6/7] Installing jq for JSON parsing..."
sudo dnf install -y jq

echo "[6/7] Discovering latest GPU Operator version..."
LATEST_VERSION=$(helm search repo nvidia/gpu-operator --devel -o json | jq -r '.[0].version')

if [[ -z "$LATEST_VERSION" ]]; then
  echo "[ERROR] Could not detect latest GPU Operator version."
  exit 1
fi

echo "[INFO] Latest version: $LATEST_VERSION"

echo "[7/7] Installing GPU Operator version $LATEST_VERSION..."
helm upgrade --install --wait gpu-operator -n gpu-operator --create-namespace nvidia/gpu-operator \
  --version "$LATEST_VERSION" \
  --set cdi.enabled=true \
  --set driver.enabled=false \
  --set toolkit.enabled=false \
  --set toolkit.env[0].name=CONTAINERD_CONFIG \
  --set toolkit.env[0].value=/etc/containerd/config.toml \
  --set toolkit.env[1].name=CONTAINERD_SOCKET \
  --set toolkit.env[1].value=/run/containerd/containerd.sock \
  --set toolkit.env[2].name=CONTAINERD_RUNTIME_CLASS \
  --set toolkit.env[2].value=nvidia \
  --set toolkit.env[3].name=CONTAINERD_SET_AS_DEFAULT \
  --set-string toolkit.env[3].value=true \
  --set mps.enabled=true \
  --set mig.strategy=none

echo "[INFO] Waiting for pods to initialize..."
sleep 10

echo "[INFO] GPU Operator pods:"
kubectl get pods -n gpu-operator

echo "[INFO] Node GPU capacity:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,CAPACITY:.status.capacity