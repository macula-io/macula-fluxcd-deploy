#!/usr/bin/env bash
# Recreate macula-hub KinD cluster with updated config
# This will delete and recreate the cluster - all data will be lost!

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_DIR="${SCRIPT_DIR}/../clusters/kind-macula-hub"
CLUSTER_NAME="macula-hub"
KIND_CONFIG="${CLUSTER_DIR}/kind-config.yaml"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Recreate macula-hub KinD Cluster"
echo "=========================================="
echo ""

# Check if config exists
if [ ! -f "${KIND_CONFIG}" ]; then
    echo -e "${RED}Error: ${KIND_CONFIG} not found${NC}"
    exit 1
fi

echo -e "${YELLOW}WARNING: This will delete the existing cluster and all its data!${NC}"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Delete existing cluster if it exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${CYAN}Deleting existing cluster '${CLUSTER_NAME}'...${NC}"
    kind delete cluster --name "${CLUSTER_NAME}"
    echo -e "${GREEN}Cluster deleted${NC}"
fi

# Create new cluster
echo -e "${CYAN}Creating cluster '${CLUSTER_NAME}' with updated config...${NC}"
kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
echo -e "${GREEN}Cluster created${NC}"

# Set kubectl context
kubectl cluster-info --context "kind-${CLUSTER_NAME}"

# Install nginx-ingress-controller
echo -e "${CYAN}Installing nginx-ingress-controller...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo -e "${CYAN}Waiting for ingress-nginx to be ready...${NC}"
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s

echo -e "${GREEN}nginx-ingress-controller installed${NC}"

# Create macula namespace
echo -e "${CYAN}Creating macula namespace...${NC}"
kubectl create namespace macula --dry-run=client -o yaml | kubectl apply -f -

# Connect to kind network (for registry access)
if docker network ls | grep -q "^kind"; then
    # Connect console-proxy to kind network if it exists
    if docker ps --format '{{.Names}}' | grep -q "console-proxy"; then
        if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' console-proxy 2>/dev/null)" = 'null' ]; then
            docker network connect kind console-proxy 2>/dev/null || true
            echo -e "${GREEN}Connected console-proxy to kind network${NC}"
        fi
    fi
fi

echo ""
echo "=========================================="
echo "  Cluster Recreated Successfully"
echo "=========================================="
echo ""
echo -e "${GREEN}Cluster:${NC} ${CLUSTER_NAME}"
echo -e "${GREEN}Context:${NC} kind-${CLUSTER_NAME}"
echo ""
echo -e "${GREEN}Host mount available:${NC}"
echo "  /home/rl/work -> /home/rl/work (read-only)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Bootstrap FluxCD (if using GitOps):"
echo "     export GITHUB_TOKEN=<your-token>"
echo "     flux bootstrap github --owner=macula-io --repository=macula-gitops \\"
echo "       --branch=main --path=./dev/clusters/kind-macula-hub --personal"
echo ""
echo "  2. Or apply manifests directly:"
echo "     kubectl apply -k ${CLUSTER_DIR}/apps/console/"
echo ""
