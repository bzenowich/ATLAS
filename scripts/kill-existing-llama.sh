#!/bin/bash
# Script to kill existing llama-server deployment to free up GPU
# Use this when a new deployment is stuck in Pending due to "Insufficient nvidia.com/gpu"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

echo "Force cleaning llama-server to free up GPU..."

# Delete deployment
sudo kubectl delete deployment -n "$ATLAS_NAMESPACE" llama-server 2>/dev/null || true

# Wait for pods to actually terminate
echo "Waiting for pods to terminate..."
sudo kubectl wait --for=delete pod -l app=llama-server -n "$ATLAS_NAMESPACE" --timeout=60s || {
    echo "Warning: Pods taking a long time to delete, force killing..."
    sudo kubectl delete pod -n "$ATLAS_NAMESPACE" -l app=llama-server --force --grace-period=0 2>/dev/null || true
}

echo "GPU should be free now."
