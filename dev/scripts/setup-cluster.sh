#!/usr/bin/env bash
set -e

CLUSTER_NAME="macula-dev"
INGRESS_CONTAINER="macula-nginx-ingress"
REGISTRY_PORT="5001"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Macula KinD Cluster Setup                             ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
echo -e "${CYAN}▸${NC} Checking prerequisites..."

if ! command -v kind &> /dev/null; then
    echo -e "${RED}✗${NC} kind is not installed"
    echo "Install: brew install kind (macOS) or see https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗${NC} kubectl is not installed"
    echo "Install: brew install kubectl (macOS) or see https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if infrastructure is running
if ! docker ps | grep -q "${INGRESS_CONTAINER}"; then
    echo -e "${YELLOW}⚠${NC} Macula infrastructure not running"
    echo ""
    echo "Start infrastructure first:"
    echo "  cd ../infrastructure && ./start-infrastructure.sh"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Prerequisites satisfied"
echo ""

# Create KinD cluster config
echo -e "${CYAN}▸${NC} Creating cluster configuration..."

cat <<EOF > /tmp/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080    # Changed: Avoid conflict with host nginx on port 80
    protocol: TCP
  - containerPort: 443
    hostPort: 8443    # Changed: Avoid conflict with potential host TLS
    protocol: TCP
  - containerPort: 4433
    hostPort: 4433    # QUIC port for bootstrap service
    protocol: UDP
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://kind-registry:5000"]
EOF

# Create cluster if it doesn't exist
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${GREEN}✓${NC} KinD cluster '${CLUSTER_NAME}' already exists"
else
    echo -e "${CYAN}▸${NC} Creating KinD cluster '${CLUSTER_NAME}'..."
    kind create cluster --name "${CLUSTER_NAME}" --config /tmp/kind-config.yaml
    echo -e "${GREEN}✓${NC} Cluster created"
fi

echo ""

# Connect ingress to cluster network
echo -e "${CYAN}▸${NC} Connecting ingress to cluster network..."

# Connect ingress container to kind network with alias for registry
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${INGRESS_CONTAINER}")" = 'null' ]; then
    docker network connect "kind" "${INGRESS_CONTAINER}" --alias kind-registry
    echo -e "${GREEN}✓${NC} Ingress connected to KinD network"
else
    echo -e "${GREEN}✓${NC} Ingress already connected to KinD network"
fi

echo ""

# Document the local registry
echo -e "${CYAN}▸${NC} Configuring cluster registry settings..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo -e "${GREEN}✓${NC} Registry configuration applied"
echo ""

echo "╔════════════════════════════════════════════════════════╗"
echo "║  Cluster Ready                                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}Cluster Details:${NC}"
echo "  Name:     ${CLUSTER_NAME}"
echo "  Context:  kind-${CLUSTER_NAME}"
echo ""

echo -e "${GREEN}Port Mappings:${NC}"
echo "  KinD Ingress (HTTP):  127.0.0.1:8080  (maps to 127.0.0.2:80 via socat)"
echo "  KinD Ingress (HTTPS): 127.0.0.1:8443  (maps to 127.0.0.2:443 via socat)"
echo "  QUIC Bootstrap:       127.0.0.1:4433"
echo ""

echo -e "${GREEN}Registry Access:${NC}"
echo "  From host:    localhost:${REGISTRY_PORT} or registry.macula.local"
echo "  From cluster: kind-registry:5000"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Deploy nginx-ingress-controller:"
echo "     kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
echo ""
echo "  2. Setup port forwarding:"
echo "     cd ../scripts && ./setup-port-forwarding.sh start"
echo ""
echo "  3. Build and deploy applications:"
echo "     ./build-and-push.sh"
echo "     kubectl apply -k ../apps/"
echo ""
