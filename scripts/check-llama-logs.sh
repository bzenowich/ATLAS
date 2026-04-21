#!/bin/bash
# Script to check llama-server logs in K3s
# Requires sudo access for k3s kubeconfig

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

# Set KUBECONFIG if not set
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

echo "Checking llama-server logs in namespace: $ATLAS_NAMESPACE..."

# Find pod name
POD=$(sudo kubectl get pods -n "$ATLAS_NAMESPACE" -l app=llama-server -o name | head -n 1)

if [[ -z "$POD" ]]; then
    echo "ERROR: llama-server pod not found."
    exit 1
fi

echo "Pod found: $POD"
echo "--- Logs start ---"
sudo kubectl logs "$POD" -n "$ATLAS_NAMESPACE" --tail 100
echo "--- Logs end ---"
