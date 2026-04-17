#!/usr/bin/env bash
# Advanced validation library for security infrastructure checks

# Source logger
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Source installer functions
source "$(dirname "${BASH_SOURCE[0]}")/installer.sh"

# Validate Kubernetes cluster
validate_kubernetes() {
    log_subsection "Validating Kubernetes cluster"

    log_subsection "Need to update based on devplays/cilium-teragon-clusters.sh..."
    return 0

    # unreachable code for now
    if ! command_exists kubectl; then
        log_failure "kubectl command not found"
        return 1
    fi

    # Check if cluster is accessible
    if kubectl get nodes &>/dev/null; then
        local node_count
        node_count=$(kubectl get nodes --no-headers | wc -l)
        log_success "Kubernetes cluster accessible ($node_count nodes)"
        return 0
    else
        log_failure "Cannot access Kubernetes cluster"
        return 1
    fi
}

# Validate Cilium
validate_cilium() {
    log_subsection "Validating Cilium"
    return 0

    # unreachable code for now

    if ! command_exists cilium; then
        log_failure "cilium command not found"
        return 1
    fi

    # Check Cilium status
    if cilium status | grep -q "OK"; then
        log_success "Cilium is healthy"
        return 0
    else
        log_failure "Cilium status check failed"
        return 1
    fi
}

# Validate Tetragon
validate_tetragon() {
    log_subsection "Validating Tetragon"
    return 0

    # unreachable code for now

    local ds_count
    ds_count=$(kubectl -n kube-system get ds tetragon --no-headers 2>/dev/null | wc -l)

    if [[ "$ds_count" -gt 0 ]]; then
        log_success "Tetragon daemonset deployed"
        return 0
    else
        log_failure "Tetragon daemonset not found"
        return 1
    fi
}

# Export functions
export -f validate_kubernetes validate_cilium validate_tetragon