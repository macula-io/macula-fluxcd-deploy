#!/usr/bin/env bash
# Setup KinD cluster with FluxCD and ExternalDNS for Macula GitOps
# Run from: dev/scripts directory

set -e

CLUSTER_NAME="macula-dev"
INGRESS_CONTAINER="macula-nginx-ingress"
REGISTRY_PORT="5001"
POWERDNS_API_URL="http://172.23.0.10:8081"
POWERDNS_API_KEY="${POWERDNS_API_KEY:-macula-dev-api-key}"
GITHUB_USER="${GITHUB_USER:-macula-io}"
GITHUB_REPO="${GITHUB_REPO:-macula-gitops}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
FLUX_PATH="./dev/clusters/kind-dev"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Macula KinD + GitOps Setup                            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

#
# 1. Create KinD cluster
#
echo -e "${CYAN}▸${NC} Step 1: Checking prerequisites..."

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

if ! command -v flux &> /dev/null; then
    echo -e "${RED}✗${NC} flux CLI is not installed"
    echo "Install: brew install fluxcd/tap/flux (macOS) or see https://fluxcd.io/flux/installation/"
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

#
# 2. Create KinD cluster if needed
#
echo -e "${CYAN}▸${NC} Step 2: Creating KinD cluster..."

cat <<'EOF' > /tmp/kind-config.yaml
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
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
  - containerPort: 4433
    hostPort: 4433
    protocol: UDP
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
    endpoint = ["http://kind-registry:5000"]
EOF

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${GREEN}✓${NC} KinD cluster '${CLUSTER_NAME}' already exists"
else
    echo -e "${CYAN}▸${NC} Creating KinD cluster '${CLUSTER_NAME}'..."
    kind create cluster --name "${CLUSTER_NAME}" --config /tmp/kind-config.yaml
    echo -e "${GREEN}✓${NC} Cluster created"
fi

# Connect ingress to cluster network
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${INGRESS_CONTAINER}")" = 'null' ]; then
    docker network connect "kind" "${INGRESS_CONTAINER}" --alias kind-registry
    echo -e "${GREEN}✓${NC} Ingress connected to KinD network"
else
    echo -e "${GREEN}✓${NC} Ingress already connected to KinD network"
fi

# Document the local registry
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5001"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo ""

#
# 3. Install nginx-ingress-controller
#
echo -e "${CYAN}▸${NC} Step 3: Installing nginx-ingress-controller..."

if kubectl get namespace ingress-nginx &> /dev/null; then
    echo -e "${GREEN}✓${NC} nginx-ingress-controller already installed"
else
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    echo -e "${CYAN}▸${NC} Waiting for ingress-nginx to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s

    echo -e "${GREEN}✓${NC} nginx-ingress-controller installed"
fi

echo ""

#
# 4. Install FluxCD
#
echo -e "${CYAN}▸${NC} Step 4: Installing FluxCD..."

if kubectl get namespace flux-system &> /dev/null; then
    echo -e "${GREEN}✓${NC} FluxCD already installed"
else
    echo -e "${YELLOW}⚠${NC} FluxCD requires GitHub credentials to bootstrap"
    echo ""
    echo "You need to provide a GitHub Personal Access Token (classic) with repo permissions:"
    echo "  1. Go to: https://github.com/settings/tokens"
    echo "  2. Generate a new token (classic) with 'repo' scope"
    echo "  3. Export it: export GITHUB_TOKEN=<your-token>"
    echo ""

    if [ -z "${GITHUB_TOKEN}" ]; then
        echo -e "${RED}✗${NC} GITHUB_TOKEN not set. Skipping FluxCD installation."
        echo ""
        echo "To install FluxCD manually later:"
        echo "  export GITHUB_TOKEN=<your-token>"
        echo "  flux bootstrap github \\"
        echo "    --owner=${GITHUB_USER} \\"
        echo "    --repository=${GITHUB_REPO} \\"
        echo "    --branch=${GITHUB_BRANCH} \\"
        echo "    --path=${FLUX_PATH} \\"
        echo "    --personal"
        echo ""
    else
        flux bootstrap github \
            --owner="${GITHUB_USER}" \
            --repository="${GITHUB_REPO}" \
            --branch="${GITHUB_BRANCH}" \
            --path="${FLUX_PATH}" \
            --personal

        echo -e "${GREEN}✓${NC} FluxCD installed and bootstrapped"
    fi
fi

echo ""

#
# 5. Install ExternalDNS for PowerDNS integration
#
echo -e "${CYAN}▸${NC} Step 5: Installing ExternalDNS..."

if kubectl get namespace external-dns &> /dev/null; then
    echo -e "${GREEN}✓${NC} ExternalDNS already installed"
else
    kubectl create namespace external-dns

    # Create ExternalDNS deployment
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: external-dns
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services","endpoints","pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions","networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: external-dns
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: external-dns
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.0
        args:
        - --source=ingress
        - --provider=pdns
        - --pdns-server=${POWERDNS_API_URL}
        - --pdns-api-key=${POWERDNS_API_KEY}
        - --domain-filter=macula.local
        - --txt-owner-id=kind-dev
        - --log-level=debug
EOF

    echo -e "${GREEN}✓${NC} ExternalDNS installed"
fi

echo ""

#
# 6. Setup port forwarding
#
echo -e "${CYAN}▸${NC} Step 6: Setting up port forwarding..."

# Check if socat is installed
if ! command -v socat &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} socat is not installed"
    echo "Install: sudo apt-get install socat (Ubuntu/Debian) or brew install socat (macOS)"
    echo ""
    echo "For now, you can access services via localhost:8080"
    echo "To enable .macula.local domains, install socat and run:"
    echo "  sudo socat TCP4-LISTEN:80,bind=127.0.0.2,fork TCP4:127.0.0.1:8080 &"
else
    # Check if port forwarding is already running
    if pgrep -f "socat.*127.0.0.2:80.*127.0.0.1:8080" > /dev/null; then
        echo -e "${GREEN}✓${NC} Port forwarding already running"
    else
        echo -e "${CYAN}▸${NC} Starting port forwarding (requires sudo)..."
        echo "This will forward 127.0.0.2:80 → 127.0.0.1:8080"

        # Start socat in background
        sudo socat TCP4-LISTEN:80,bind=127.0.0.2,fork TCP4:127.0.0.1:8080 &

        sleep 2

        if pgrep -f "socat.*127.0.0.2:80.*127.0.0.1:8080" > /dev/null; then
            echo -e "${GREEN}✓${NC} Port forwarding started"
        else
            echo -e "${YELLOW}⚠${NC} Port forwarding failed to start"
        fi
    fi
fi

echo ""

echo "╔════════════════════════════════════════════════════════╗"
echo "║  KinD Cluster with GitOps Ready                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}Cluster Details:${NC}"
echo "  Name:     ${CLUSTER_NAME}"
echo "  Context:  kind-${CLUSTER_NAME}"
echo ""

echo -e "${GREEN}Installed Components:${NC}"
echo "  ✓ nginx-ingress-controller"
if kubectl get namespace flux-system &> /dev/null; then
    echo "  ✓ FluxCD (GitOps)"
else
    echo "  ⚠ FluxCD (not installed - set GITHUB_TOKEN)"
fi
if kubectl get namespace external-dns &> /dev/null; then
    echo "  ✓ ExternalDNS (PowerDNS integration)"
fi
echo ""

echo -e "${GREEN}Port Mappings:${NC}"
echo "  KinD Ingress (HTTP):  127.0.0.1:8080"
if pgrep -f "socat.*127.0.0.2:80.*127.0.0.1:8080" > /dev/null; then
    echo "  DNS Ingress:          127.0.0.2:80 → 127.0.0.1:8080"
fi
echo "  KinD Ingress (HTTPS): 127.0.0.1:8443"
echo "  QUIC Bootstrap:       127.0.0.1:4433"
echo ""

echo -e "${GREEN}Registry Access:${NC}"
echo "  From host:    localhost:${REGISTRY_PORT} or registry.macula.local"
echo "  From cluster: kind-registry:5000"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Build and push macula-bootstrap image:"
echo "   cd /home/rl/work/github.com/macula-io/macula/services/bootstrap"
echo "   docker build -t registry.macula.local:5000/macula/bootstrap:latest ."
echo "   docker push registry.macula.local:5000/macula/bootstrap:latest"
echo ""
echo "2. Create GitOps manifests in ../../dev/clusters/kind-dev/apps/"
echo ""
echo "3. Commit manifests and let Flux deploy:"
echo "   git add dev/clusters/kind-dev/"
echo "   git commit -m 'Add macula-bootstrap deployment'"
echo "   git push"
echo ""
echo "4. Verify deployment:"
echo "   kubectl get pods -n macula"
echo "   curl http://bootstrap.macula.local"
echo ""
