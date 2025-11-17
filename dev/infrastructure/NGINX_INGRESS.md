# Nginx Ingress for Infrastructure Services

## Overview

All infrastructure services are now accessible via a unified nginx ingress using **host-based routing**. This provides clean, DNS-based URLs for all services while maintaining backward compatibility.

## Architecture

### Before (Port-based Access)

```
Developer → localhost:5001 → Registry
Developer → localhost:8081 → PowerDNS API
Developer → localhost:9191 → PowerDNS Admin
```

**Problems:**
- Hard to remember port numbers
- Not intuitive for new users
- No consistency with Kubernetes service access patterns

### After (DNS-based Access)

```
Developer → registry.macula.local:80 → Nginx Ingress → Registry
Developer → dns.macula.local:80 → Nginx Ingress → PowerDNS API
Developer → dns-admin.macula.local:80 → Nginx Ingress → PowerDNS Admin
Developer → localhost:5001 → Nginx Ingress → Registry (legacy)
```

**Benefits:**
- Clean, memorable URLs
- Consistent with Kubernetes service patterns
- Single entry point (port 80)
- Backward compatibility maintained
- Prepares for future HTTPS/TLS

## Service URLs

| Service | DNS URL | Legacy URL | Description |
|---------|---------|------------|-------------|
| Registry UI | http://registry.macula.local | http://localhost:5001 | Container registry web interface |
| Registry API | http://registry.macula.local/v2/ | http://localhost:5001/v2/ | Docker Registry v2 API |
| PowerDNS API | http://dns.macula.local | N/A | DNS HTTP API (for ExternalDNS) |
| PowerDNS Admin | http://dns-admin.macula.local | N/A | DNS management web UI |

## Setup

### 1. Add DNS Entries

**Using helper script:**
```bash
cd scripts
./setup-hosts.sh
```

**Or manually:**
```bash
echo "127.0.0.1 registry.macula.local dns.macula.local dns-admin.macula.local" | sudo tee -a /etc/hosts
```

### 2. Verify Entries

```bash
cat /etc/hosts | grep macula.local
```

Expected output:
```
127.0.0.1 registry.macula.local dns.macula.local dns-admin.macula.local
```

## Usage Examples

### Docker Registry

**Push an image (DNS-based):**
```bash
docker build -t my-app:latest .
docker tag my-app:latest registry.macula.local/my-app:latest
docker push registry.macula.local/my-app:latest
```

**View catalog:**
```bash
curl http://registry.macula.local/v2/_catalog
```

**Access UI:**
```bash
open http://registry.macula.local/
```

### PowerDNS API

**Test connectivity:**
```bash
curl -H "X-API-Key: macula-dev-api-key" http://dns.macula.local/api/v1/servers
```

**List zones:**
```bash
curl -H "X-API-Key: macula-dev-api-key" http://dns.macula.local/api/v1/servers/localhost/zones
```

### PowerDNS Admin

**Access UI:**
```bash
open http://dns-admin.macula.local/
```

## Nginx Configuration

The nginx ingress is configured via `infrastructure/config/nginx/ingress.conf`:

### Key Features

1. **Host-based Routing**
   - Uses HTTP `Host` header to route requests
   - Each service has its own virtual host

2. **Large File Support**
   - `client_max_body_size 0` (unlimited)
   - Extended timeouts for large image pushes
   - Chunked transfer encoding

3. **Proper Headers**
   - `X-Forwarded-For` for client IP
   - `X-Forwarded-Proto` for protocol
   - Docker-specific headers for registry

4. **Health Checks**
   - Each virtual host has `/health` endpoint
   - Returns 200 OK with service identifier

5. **Backward Compatibility**
   - Port 5001 listener for legacy access
   - Same functionality as DNS-based access

### Virtual Hosts

```nginx
# Registry UI and API
server {
  listen 80;
  server_name registry.macula.local;
  location / { proxy_pass http://registry-ui/; }
  location /v2/ { proxy_pass http://registry/v2/; }
}

# PowerDNS API
server {
  listen 80;
  server_name dns.macula.local;
  location / { proxy_pass http://powerdns-api/; }
}

# PowerDNS Admin
server {
  listen 80;
  server_name dns-admin.macula.local;
  location / { proxy_pass http://powerdns-admin/; }
}

# Legacy port access
server {
  listen 5001;
  server_name localhost;
  # Same as registry.macula.local
}
```

## KinD Integration

The nginx ingress connects to the KinD network with alias `kind-registry`:

```bash
docker network connect kind macula-nginx-ingress --alias kind-registry
```

This allows KinD pods to pull images via:
```yaml
image: kind-registry:5000/my-app:latest
```

The ingress routes this to the registry backend on port 5001.

## Troubleshooting

### DNS Resolution Not Working

**Symptom:**
```bash
curl http://registry.macula.local
# curl: (6) Could not resolve host: registry.macula.local
```

**Solution:**
```bash
# Check /etc/hosts
cat /etc/hosts | grep macula.local

# If missing, add entry
cd scripts && ./setup-hosts.sh
```

### Wrong Port

**Symptom:**
```bash
curl http://registry.macula.local:5001
# Works, but should not need port
```

**Solution:**
Use port 80 (default HTTP):
```bash
curl http://registry.macula.local
```

### Nginx Not Routing

**Symptom:**
```bash
curl http://registry.macula.local
# 404 Not Found
```

**Solution:**
```bash
# Check nginx is running
docker ps | grep macula-nginx-ingress

# Check nginx logs
docker logs macula-nginx-ingress

# Check Host header is being sent
curl -v http://registry.macula.local 2>&1 | grep Host
# Should see: Host: registry.macula.local
```

### Services Not Available

**Symptom:**
```bash
curl http://registry.macula.local
# 502 Bad Gateway
```

**Solution:**
```bash
# Check backend services are running
docker ps | grep macula-registry
docker ps | grep macula-powerdns

# Check docker-compose status
cd infrastructure
docker compose ps
```

## Future Enhancements

### HTTPS/TLS

Add self-signed certificates for HTTPS:

```nginx
server {
  listen 443 ssl;
  server_name registry.macula.local;
  ssl_certificate /etc/nginx/certs/registry.crt;
  ssl_certificate_key /etc/nginx/certs/registry.key;
  # ... rest of config
}
```

### Authentication

Add basic auth or OAuth2 proxy:

```nginx
location / {
  auth_basic "Restricted";
  auth_basic_user_file /etc/nginx/.htpasswd;
  proxy_pass http://registry-ui/;
}
```

### Rate Limiting

Prevent abuse:

```nginx
limit_req_zone $binary_remote_addr zone=registry:10m rate=10r/s;

server {
  location /v2/ {
    limit_req zone=registry burst=20;
    proxy_pass http://registry/v2/;
  }
}
```

### Access Logs

Separate logs per service:

```nginx
server {
  server_name registry.macula.local;
  access_log /var/log/nginx/registry_access.log;
  error_log /var/log/nginx/registry_error.log;
}
```

## Summary

The nginx ingress provides:
- ✅ Clean DNS-based URLs for all services
- ✅ Consistent access patterns
- ✅ Backward compatibility (port 5001)
- ✅ Single entry point for all infrastructure
- ✅ Prepares for future enhancements (HTTPS, auth, etc.)
- ✅ KinD integration with registry alias

All infrastructure services are now accessible via intuitive, memorable URLs while maintaining compatibility with existing workflows.
