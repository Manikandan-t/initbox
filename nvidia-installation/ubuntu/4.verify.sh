#!/bin/bash

echo -e "\n🔍 Verifying NVIDIA Driver & CUDA Installation...\n"

# Check if NVIDIA driver is installed and working
if command -v nvidia-smi &> /dev/null; then
    echo "✅ NVIDIA driver is installed. GPU detected:"
    nvidia-smi
else
    echo "❌ NVIDIA driver is NOT installed or GPU not detected!"
    exit 1
fi

# Check if CUDA toolkit is installed
if [ -d "/usr/local/cuda" ]; then
    echo -e "\n✅ CUDA toolkit directory found: /usr/local/cuda"
else
    echo -e "\n❌ CUDA toolkit directory not found! It may not be installed."
    exit 1
fi

# Check CUDA version
if command -v nvcc &> /dev/null; then
    echo -e "\n✅ nvcc is available. CUDA version:"
    nvcc --version
else
    echo -e "\n❌ 'nvcc' not found. CUDA compiler may not be in PATH."
    echo "Try adding the following to your ~/.bashrc and reloading the shell:"
    echo "export PATH=/usr/local/cuda/bin:$PATH"
    echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
    exit 1
fi

# Optional: Test CUDA sample (if available)
if [ -f "/usr/local/cuda/samples/1_Utilities/deviceQuery/deviceQuery" ]; then
    echo -e "\n▶ Running CUDA sample: deviceQuery"
    /usr/local/cuda/samples/1_Utilities/deviceQuery/deviceQuery
else
    echo -e "\n⚠️ CUDA samples not built. You can build them with:"
    echo "cd /usr/local/cuda/samples"
    echo "sudo make -j$(nproc)"
fi

echo -e "\n✅ All checks passed. Your NVIDIA and CUDA setup looks good!"
