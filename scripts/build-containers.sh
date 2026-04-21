#!/bin/bash
set -euo pipefail

# ATLAS Container Builder
# Builds all container images and imports to K3s
# Note: Importing to K3s requires sudo (will prompt if not root)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

# Colors for output (inherited from lib/config.sh)

# Detect container runtime
detect_runtime() {
    if command -v podman &> /dev/null; then
        echo "podman"
    elif command -v docker &> /dev/null; then
        echo "docker"
    else
        log_error "No container runtime found. Install podman or docker."
        exit 1
    fi
}

build_image() {
    local name="$1"
    local dir="$2"
    local runtime="$3"

    log_info "Building $name..."

    if [[ ! -d "$dir" ]]; then
        log_warn "Directory not found: $dir - skipping"
        return 0
    fi

    if [[ ! -f "$dir/Dockerfile" ]]; then
        log_warn "Dockerfile not found in $dir - skipping"
        return 0
    fi

    $runtime build -t "${ATLAS_REGISTRY}/$name:${ATLAS_IMAGE_TAG}" "$dir"

    log_info "$name built successfully"
}

import_to_k3s() {
    local name="$1"
    local runtime="$2"

    log_info "Importing $name to K3s..."

    # Check if image exists
    if ! $runtime image inspect "${ATLAS_REGISTRY}/$name:${ATLAS_IMAGE_TAG}" >/dev/null 2>&1; then
        log_warn "Image ${ATLAS_REGISTRY}/$name:${ATLAS_IMAGE_TAG} not found, skipping import"
        return 0
    fi

    # K3s containerd socket requires root access
    # Use full path since sudo doesn't inherit PATH
    if [[ $EUID -eq 0 ]]; then
        $runtime save "${ATLAS_REGISTRY}/$name:${ATLAS_IMAGE_TAG}" | /usr/local/bin/k3s ctr images import -
    else
        $runtime save "${ATLAS_REGISTRY}/$name:${ATLAS_IMAGE_TAG}" | sudo /usr/local/bin/k3s ctr images import -
    fi

    log_info "$name imported to K3s"
}

main() {
    echo "=========================================="
    echo "  ATLAS Container Builder"
    echo "=========================================="
    echo ""
    echo "Configuration:"
    echo "  Registry:    $ATLAS_REGISTRY"
    echo "  Image tag:   $ATLAS_IMAGE_TAG"
    echo ""

    RUNTIME=$(detect_runtime)
    log_info "Using container runtime: $RUNTIME"

    # Core services
    declare -a CORE_IMAGES=(
        "llama-server:$K8S_DIR/inference"
        "geometric-lens:$K8S_DIR/geometric-lens"
        "llm-proxy:$K8S_DIR/atlas-proxy"
        "v3-service:$K8S_DIR/v3-service"
        "sandbox:$K8S_DIR/sandbox"
    )

    # Build all core images
    echo ""
    echo "Building core service images..."
    for entry in "${CORE_IMAGES[@]}"; do
        name="${entry%%:*}"
        dir="${entry#*:}"
        
        # Special cases that need root context or specific flags
        if [[ "$name" == "llama-server" ]]; then
            log_info "Building $name (optimized for RTX 3060)..."
            # User has RTX 3060 (Ampere = 86)
            $RUNTIME build --build-arg CUDA_ARCH=86 -t "${ATLAS_REGISTRY}/$name:${ATLAS_IMAGE_TAG}" -f "$dir/Dockerfile.v31" "$dir"
        elif [[ "$name" == "v3-service" ]]; then
            log_info "Building $name..."
            $RUNTIME build -t "${ATLAS_REGISTRY}/$name:${ATLAS_IMAGE_TAG}" -f "$dir/Dockerfile" "$K8S_DIR"
        else
            build_image "$name" "$dir" "$RUNTIME"
        fi
    done

    # Import to K3s
    echo ""
    echo "Importing to K3s..."
    if [[ $EUID -ne 0 ]]; then
        log_warn "K3s import requires sudo - you may be prompted for your password"
    fi
    for entry in "${CORE_IMAGES[@]}"; do
        name="${entry%%:*}"
        import_to_k3s "$name" "$RUNTIME"
    done

    echo ""
    echo "=========================================="
    echo "  Build Complete!"
    echo "=========================================="
    echo ""
    echo "Images built and imported:"
    if [[ $EUID -eq 0 ]]; then
        /usr/local/bin/k3s ctr images list 2>/dev/null | grep "$ATLAS_REGISTRY" || echo "  (use 'sudo k3s ctr images list' to verify)"
    else
        sudo /usr/local/bin/k3s ctr images list 2>/dev/null | grep "$ATLAS_REGISTRY" || echo "  (use 'sudo k3s ctr images list' to verify)"
    fi
    echo ""
}

main "$@"
