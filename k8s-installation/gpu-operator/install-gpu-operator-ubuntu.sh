#!/bin/bash
# NVIDIA GPU Operator Setup for Ubuntu

set -e

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

echo "[1/7] Adding NVIDIA Container Toolkit repo..."
sudo apt-get update
sudo apt-get install -y curl gnupg lsb-release

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

echo "[2/7] Installing NVIDIA Container Toolkit..."
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

echo "[3/7] Configuring containerd runtime..."
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart containerd

grep -q "\[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.nvidia\]" /etc/containerd/config.toml || {
  echo "[ERROR] NVIDIA runtime not configured in containerd"
  exit 1
}

echo "[4/7] Install Helm (if not already installed) ---"
if ! command -v helm &>/dev/null; then
  echo "[INFO] Helm not found. Installing Helm..."
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
else
  echo "[INFO] Helm is already installed."
fi

echo "[5/7] Adding NVIDIA Helm repo..."
helm repo add nvidia https://nvidia.github.io/gpu-operator
helm repo update

echo "Installing required packages"
sudo apt-get install -y jq
set -euo pipefail

echo "[6/7] Find Latest Version of GPU Operator ..."
LATEST_VERSION=$(helm search repo nvidia/gpu-operator --devel -o json | jq -r '.[0].version')

if [[ -z "$LATEST_VERSION" ]]; then
  echo "[ERROR] Unable to find latest GPU Operator version."
  exit 1
fi

echo "[INFO] Latest version found: $LATEST_VERSION"

echo "[6/7] Installing GPU Operator version $LATEST_VERSION..."
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

echo "[7/7] Validating GPU Operator Pods..."
sleep 10
kubectl get pods -n gpu-operator

echo "[INFO] Checking node GPU capacity..."
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,CAPACITY:.status.capacity