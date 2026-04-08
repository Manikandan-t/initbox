#!/bin/bash

################################################################################
# Splunk Enterprise Standalone Installation Script for Kubernetes
################################################################################
#
# This script automates the installation of:
# - Local-path storage provisioner (for persistent storage)
# - Splunk Operator v3.0.0
# - Splunk Enterprise standalone instance
#
# IMPORTANT: This uses local-path storage, which is NOT recommended for production.
# For production, use distributed storage (NFS, Ceph, cloud storage).
#
# Usage:
#   chmod +x splunk-standalone-installation.sh
#   ./splunk-standalone-installation.sh [--cleanup] [--custom-storage]
#
# Options:
#   --cleanup         Clean up previous installations before installing
#   --custom-storage  Use custom local-path-storage.yaml from current directory
#   --help           Display this help message
#
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

################################################################################
# Configuration Variables
################################################################################

# Splunk Operator version
OPERATOR_VERSION="3.0.0"

# Namespaces
SPLUNK_NAMESPACE="splunk"
OPERATOR_NAMESPACE="splunk-operator"
STORAGE_NAMESPACE="local-path-storage"

# Storage configuration
VAR_STORAGE_SIZE="40Gi"  # Size for index data
ETC_STORAGE_SIZE="4Gi"   # Size for configuration
STORAGE_CLASS="local-path"

# Timeouts (in seconds)
TIMEOUT_POD_READY=120
TIMEOUT_DEPLOYMENT=300

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    print_info "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    print_info "Kubernetes cluster: Connected"

    # Check permissions
    if ! kubectl auth can-i create namespace &> /dev/null; then
        print_error "Insufficient permissions. Cluster admin access required."
        exit 1
    fi
    print_info "Permissions: OK"

    echo ""
}

cleanup_previous_installation() {
    print_header "Cleaning Up Previous Installations"

    print_info "Deleting Splunk standalone instance..."
    kubectl delete standalone s1 -n "$SPLUNK_NAMESPACE" --ignore-not-found=true

    print_info "Deleting namespaces..."
    kubectl delete namespace "$SPLUNK_NAMESPACE" --ignore-not-found=true --timeout=60s
    kubectl delete namespace "$OPERATOR_NAMESPACE" --ignore-not-found=true --timeout=60s

    print_info "Deleting storage provisioner..."
    if kubectl get namespace "$STORAGE_NAMESPACE" &> /dev/null; then
        kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml --ignore-not-found=true
    fi

    print_info "Cleanup complete."
    echo ""
}

install_storage_provisioner() {
    print_header "Installing Storage Provisioner"

    if [ "$USE_CUSTOM_STORAGE" = true ]; then
        if [ ! -f "local-path-storage.yaml" ]; then
            print_error "local-path-storage.yaml not found in current directory"
            exit 1
        fi
        print_info "Using custom local-path-storage.yaml"
        kubectl apply -f local-path-storage.yaml
    else
        print_info "Using official local-path provisioner (v0.0.26)"
        kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
    fi

    print_info "Waiting for provisioner pod to be ready..."
    if kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path --timeout="${TIMEOUT_POD_READY}s" 2>/dev/null; then
        print_info "Provisioner is ready"
    else
        print_warning "Provisioner may not be ready yet. Check with: kubectl get pods -n local-path"
    fi

    print_info "Setting local-path as default StorageClass..."
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' || true

    print_info "Storage provisioner installation complete"
    echo ""
}

install_splunk_operator() {
    print_header "Installing Splunk Operator"

    print_info "Creating operator namespace..."
    kubectl create namespace "$OPERATOR_NAMESPACE"

    print_info "Applying Splunk Operator v${OPERATOR_VERSION} (using server-side apply)..."
    kubectl apply --server-side -f "https://github.com/splunk/splunk-operator/releases/download/${OPERATOR_VERSION}/splunk-operator-cluster.yaml" -n "$OPERATOR_NAMESPACE"

    print_info "Waiting for operator deployment..."
    if kubectl wait --for=condition=available deployment/splunk-operator-controller-manager -n "$OPERATOR_NAMESPACE" --timeout="${TIMEOUT_DEPLOYMENT}s"; then
        print_info "Operator deployment is available"
    else
        print_error "Operator deployment failed to become available"
        exit 1
    fi

    print_info "Splunk Operator installation complete"
    echo ""
}

accept_splunk_license() {
    print_header "Accepting Splunk License Terms"

    print_warning "Patching operator to accept Splunk General Terms"
    print_warning "By continuing, you accept the Splunk General Terms:"
    print_warning "https://www.splunk.com/en_us/legal/splunk-general-terms.html"

    kubectl patch deployment splunk-operator-controller-manager -n "$OPERATOR_NAMESPACE" --type=json \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "SPLUNK_GENERAL_TERMS", "value": "--accept-sgt-current-at-splunk-com"}}]'

    print_info "Waiting for operator to restart..."
    if kubectl rollout status deployment splunk-operator-controller-manager -n "$OPERATOR_NAMESPACE" --timeout="${TIMEOUT_DEPLOYMENT}s"; then
        print_info "Operator restarted successfully"
    else
        print_error "Operator failed to restart"
        exit 1
    fi

    echo ""
}

deploy_splunk_instance() {
    print_header "Deploying Splunk Standalone Instance"

    print_info "Creating Splunk namespace..."
    kubectl create namespace "$SPLUNK_NAMESPACE"

    print_info "Generating Splunk standalone manifest..."

    # Check if splunk-standalone.yaml already exists and use it, or create a basic one
    if [ -f "splunk-standalone.yaml" ]; then
        print_info "Using existing splunk-standalone.yaml"
        kubectl apply -f splunk-standalone.yaml -n "$SPLUNK_NAMESPACE"
    else
        print_info "Creating basic splunk-standalone.yaml"
        cat <<EOF | kubectl apply -f - -n "$SPLUNK_NAMESPACE"
apiVersion: enterprise.splunk.com/v4
kind: Standalone
metadata:
  name: s1
  namespace: ${SPLUNK_NAMESPACE}
spec:
  varVolumeStorageConfig:
    storageClassName: ${STORAGE_CLASS}
    storageCapacity: ${VAR_STORAGE_SIZE}
  etcVolumeStorageConfig:
    storageClassName: ${STORAGE_CLASS}
    storageCapacity: ${ETC_STORAGE_SIZE}
EOF
    fi

    print_info "Splunk instance deployed"
    echo ""
}

print_next_steps() {
    print_header "Installation Complete!"

    echo ""
    print_info "The Splunk instance is being created. Monitor progress with:"
    echo ""
    echo "  # Watch PVCs get bound:"
    echo "  kubectl get pvc -n $SPLUNK_NAMESPACE -w"
    echo ""
    echo "  # Watch pod startup:"
    echo "  kubectl get pods -n $SPLUNK_NAMESPACE -w"
    echo ""

    print_info "Once the pod 'splunk-s1-standalone-0' is Running:"
    echo ""
    echo "  1. Get the admin password:"
    echo "     kubectl get secret -n $SPLUNK_NAMESPACE splunk-s1-standalone-secret-v1 -o jsonpath='{.data.password}' | base64 -d && echo"
    echo ""
    echo "  2. Port-forward to access Splunk UI:"
    echo "     kubectl port-forward -n $SPLUNK_NAMESPACE svc/splunk-s1-standalone-service 8000:8000"
    echo ""
    echo "  3. Open browser to:"
    echo "     http://localhost:8000"
    echo ""
    echo "  4. Login with:"
    echo "     Username: admin"
    echo "     Password: (from step 1)"
    echo ""

    print_warning "IMPORTANT: Configure data retention in Splunk UI to prevent disk from filling up!"
    print_warning "Go to Settings → Indexes → Edit 'main' → Set 'Max Size of Entire Index'"
    echo ""

    print_info "For OpenTelemetry Collector setup, see: otel-installation.md"
    print_info "For ingress setup, see: splunk-ingress.yaml"
    echo ""
}

show_help() {
    cat << EOF
Splunk Enterprise Standalone Installation Script

Usage: $0 [OPTIONS]

Options:
    --cleanup         Clean up previous installations before installing
    --custom-storage  Use custom local-path-storage.yaml from current directory
    --help           Display this help message

Examples:
    # Fresh installation
    $0

    # Clean up and reinstall
    $0 --cleanup

    # Use custom storage configuration
    $0 --custom-storage

    # Clean up and use custom storage
    $0 --cleanup --custom-storage

EOF
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse command line arguments
    DO_CLEANUP=false
    USE_CUSTOM_STORAGE=false

    for arg in "$@"; do
        case $arg in
            --cleanup)
                DO_CLEANUP=true
                shift
                ;;
            --custom-storage)
                USE_CUSTOM_STORAGE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $arg"
                show_help
                exit 1
                ;;
        esac
    done

    # Start installation
    print_header "Splunk Enterprise Standalone Installation"
    echo ""
    print_info "Operator Version: $OPERATOR_VERSION"
    print_info "Storage Size (var): $VAR_STORAGE_SIZE"
    print_info "Storage Size (etc): $ETC_STORAGE_SIZE"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Optional cleanup
    if [ "$DO_CLEANUP" = true ]; then
        cleanup_previous_installation
    fi

    # Run installation steps
    install_storage_provisioner
    install_splunk_operator
    accept_splunk_license
    deploy_splunk_instance

    # Print next steps
    print_next_steps
}

# Run main function
main "$@"
