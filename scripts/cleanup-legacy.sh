#!/bin/bash
set -euo pipefail

# ATLAS Legacy Resource Cleanup
# Removes services and deployments from previous versions (V3.0 and older)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

main() {
    echo "=========================================="
    echo "  ATLAS Legacy Resource Cleanup"
    echo "=========================================="
    echo ""
    echo "Namespace: $ATLAS_NAMESPACE"
    echo ""

    # Legacy Deployments
    local deployments=(
        "api-portal"
        "atlas-dashboard"
        "dashboard"
        "task-worker"
        "rag-api"
        "embedding-service"
        "webgui"
    )

    log_info "Removing legacy deployments..."
    for dep in "${deployments[@]}"; do
        if kubectl get deployment -n "$ATLAS_NAMESPACE" "$dep" &>/dev/null; then
            log_info "  Deleting deployment: $dep"
            kubectl delete deployment -n "$ATLAS_NAMESPACE" "$dep"
        fi
    done

    # Legacy Services
    local services=(
        "api-portal"
        "atlas-dashboard"
        "dashboard"
        "rag-api"
        "embedding-service"
        "llama-service"
        "webgui"
    )

    log_info "Removing legacy services..."
    for svc in "${services[@]}"; do
        if kubectl get service -n "$ATLAS_NAMESPACE" "$svc" &>/dev/null; then
            log_info "  Deleting service: $svc"
            kubectl delete service -n "$ATLAS_NAMESPACE" "$svc"
        fi
    done

    # Legacy PVCs
    local pvcs=(
        "api-portal-data"
        "dashboard-data"
    )

    log_info "Removing legacy PVCs..."
    for pvc in "${pvcs[@]}"; do
        if kubectl get pvc -n "$ATLAS_NAMESPACE" "$pvc" &>/dev/null; then
            log_info "  Deleting PVC: $pvc"
            kubectl delete pvc -n "$ATLAS_NAMESPACE" "$pvc"
        fi
    done

    # Legacy CronJobs
    local cronjobs=(
        "atlas-nightly-training"
    )

    log_info "Removing legacy cronjobs..."
    for cj in "${cronjobs[@]}"; do
        if kubectl get cronjob -n "$ATLAS_NAMESPACE" "$cj" &>/dev/null; then
            log_info "  Deleting cronjob: $cj"
            kubectl delete cronjob -n "$ATLAS_NAMESPACE" "$cj"
        fi
    done

    echo ""
    log_info "Cleanup complete!"
    echo "You can now run 'sudo scripts/install.sh' to deploy the clean 3.1 stack."
    echo ""
}

main "$@"
