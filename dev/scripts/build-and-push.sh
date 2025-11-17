#!/usr/bin/env bash
set -e

REGISTRY="localhost:5001"
REPOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "================================================"
echo "Building and pushing Macula images"
echo "================================================"
echo ""
echo "Registry: ${REGISTRY}"
echo "Repos dir: ${REPOS_DIR}"
echo ""

# Build bootstrap
echo "→ Building macula-bootstrap..."
docker build -t macula-bootstrap:latest \
    -f "${REPOS_DIR}/macula/services/bootstrap/Dockerfile" \
    "${REPOS_DIR}/macula"

docker tag macula-bootstrap:latest ${REGISTRY}/macula-bootstrap:latest
docker push ${REGISTRY}/macula-bootstrap:latest
echo "✓ macula-bootstrap pushed"
echo ""

# Build console
echo "→ Building macula-console..."
docker build -t macula-console:latest \
    "${REPOS_DIR}/macula-console/system"

docker tag macula-console:latest ${REGISTRY}/macula-console:latest
docker push ${REGISTRY}/macula-console:latest
echo "✓ macula-console pushed"
echo ""

# Build arcade
echo "→ Building macula-arcade..."
docker build -t macula-arcade:latest \
    "${REPOS_DIR}/macula-arcade/system"

docker tag macula-arcade:latest ${REGISTRY}/macula-arcade:latest
docker push ${REGISTRY}/macula-arcade:latest
echo "✓ macula-arcade pushed"
echo ""

echo "================================================"
echo "✓ All images built and pushed!"
echo "================================================"
echo ""
echo "Verify:"
echo "  curl http://${REGISTRY}/v2/_catalog"
echo ""
echo "Images available in cluster as:"
echo "  kind-registry:5000/macula-bootstrap:latest"
echo "  kind-registry:5000/macula-console:latest"
echo "  kind-registry:5000/macula-arcade:latest"
echo ""
