# KinD Development Cluster

GitOps manifests for the `macula-dev` KinD cluster.

## Structure

```
kind-dev/
├── kustomization.yaml          # Root kustomization
├── infrastructure/             # Infrastructure components
│   ├── nginx-ingress/         # Ingress controller
│   ├── metallb/               # Load balancer
│   └── external-dns/          # DNS automation
└── apps/                      # Application deployments
    └── bootstrap/             # Macula bootstrap service
```

## Deployment Order

1. **Infrastructure** (installed first):
   - nginx-ingress-controller
   - MetalLB (provides LoadBalancer IPs)
   - ExternalDNS (creates DNS records in PowerDNS)

2. **Applications**:
   - macula-bootstrap (depends on infrastructure)

## Manual Deployment

```bash
# Deploy everything
kubectl apply -k dev/clusters/kind-dev

# Or deploy individually
kubectl apply -k dev/clusters/kind-dev/infrastructure/nginx-ingress
kubectl apply -k dev/clusters/kind-dev/infrastructure/metallb
kubectl apply -k dev/clusters/kind-dev/infrastructure/external-dns
kubectl apply -k dev/clusters/kind-dev/apps/bootstrap
```

## GitOps Deployment with FluxCD

When FluxCD is installed, it will automatically:
1. Monitor this directory for changes
2. Apply manifests in dependency order
3. Reconcile cluster state every minute

### Bootstrap FluxCD

```bash
export GITHUB_TOKEN=<your-token>
flux bootstrap github \
  --owner=macula-io \
  --repository=macula-gitops \
  --branch=main \
  --path=./dev/clusters/kind-dev \
  --personal
```

FluxCD will then automatically deploy and manage all resources.

## Customization

### MetalLB IP Pool

Edit `infrastructure/metallb/ipaddresspool.yaml`:
```yaml
spec:
  addresses:
  - 192.168.129.50-192.168.129.60  # Change to your LAN range
```

### ExternalDNS PowerDNS Connection

Edit `infrastructure/external-dns/deployment.yaml`:
```yaml
args:
- --pdns-server=http://macula-powerdns:8081  # PowerDNS API URL
- --pdns-api-key=macula-dev-api-key          # API key
- --domain-filter=macula.local               # DNS zone
```

## Verification

```bash
# Check infrastructure
kubectl get pods -n ingress-nginx
kubectl get pods -n metallb-system
kubectl get pods -n external-dns

# Check MetalLB IP assignments
kubectl get svc -n macula

# Check DNS records
kubectl logs -n external-dns -l app=external-dns
```

## Dependencies

- **KinD cluster** must be created first
- **PowerDNS** must be running (via Docker Compose)
- **Docker registry** must be accessible as `kind-registry:5000`

See `../../scripts/setup-kind-with-gitops.sh` for automated setup.
