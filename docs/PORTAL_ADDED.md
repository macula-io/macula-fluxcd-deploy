# Macula Infrastructure Portal

A landing page has been added at **home.macula.local** that provides quick access to all infrastructure services.

## What Was Added

### Portal Service
- **URL**: http://home.macula.local
- **Container**: macula-portal (nginx:alpine)
- **IP**: 172.23.0.25
- **Purpose**: Single entry point to access all infrastructure UIs

### Features

**Clean, Modern UI:**
- Responsive grid layout
- Purple gradient design matching Macula branding
- Service cards with descriptions and direct links
- Organized by category (Infrastructure, Observability, Tools, Data)

**Service Categories:**

1. **Core Infrastructure**
   - Docker Registry (registry.macula.local)
   - PowerDNS Admin (dns-admin.macula.local)

2. **Observability Stack**
   - Prometheus (prometheus.macula.local)
   - Grafana (grafana.macula.local)
   - Loki (loki.macula.local)
   - Tempo (tempo.macula.local)

3. **Development Tools**
   - Excalidraw (draw.macula.local)

4. **Data Services**
   - MinIO Console (s3-console.macula.local)
   - TimescaleDB (postgres.macula.local:5432)

## Files Modified

### Infrastructure Configuration

**infrastructure/docker-compose.yml**
- Added `portal` service (nginx:alpine serving static HTML)
- Mounted `./portal` directory as web root
- Added portal to nginx-ingress dependencies

**infrastructure/config/nginx/ingress.conf**
- Added `upstream portal` pointing to portal:80
- Added server block for home.macula.local

**infrastructure/setup-dnsmasq.sh**
- Added DNS entry: `address=/home.macula.local/127.0.0.1`

### New Files

**infrastructure/portal/index.html**
- Single-page HTML with embedded CSS
- No external dependencies
- Works offline

## How to Access

### First Time Setup

1. **Run DNSmasq setup** (if not already done):
   ```bash
   cd infrastructure
   sudo ./setup-dnsmasq.sh
   ```

2. **Start the portal**:
   ```bash
   docker compose up -d portal
   docker compose restart nginx-ingress
   ```

3. **Open in browser**:
   ```bash
   open http://home.macula.local
   ```

### Without DNS

If DNSmasq isn't set up yet, you can still access the portal:

```bash
# Via curl with Host header
curl -H "Host: home.macula.local" http://localhost/

# Or add to /etc/hosts manually
echo "127.0.0.1 home.macula.local" | sudo tee -a /etc/hosts
```

## Customization

The portal is a simple static HTML page located at:
```
infrastructure/portal/index.html
```

To customize:

1. Edit the HTML file
2. Restart the portal container:
   ```bash
   docker compose restart portal
   ```

Changes appear immediately (no rebuild needed).

## Design Decisions

### Why Static HTML?

- **Zero dependencies**: No npm, no build process
- **Fast**: Nginx serves static files instantly
- **Reliable**: No framework versions to worry about
- **Simple**: Edit one file, see changes immediately

### Why home.macula.local?

- **Memorable**: Easy to remember as the "home" of the infrastructure
- **Consistent**: Follows the `*.macula.local` DNS pattern
- **Short**: Quick to type

### Why 127.0.0.1?

- **Infrastructure**: Portal is part of the host infrastructure (not KinD apps)
- **Same as registry**: Consistent with other infrastructure services
- **Direct access**: No port forwarding needed

## Integration Examples

### Add New Service to Portal

Edit `infrastructure/portal/index.html` and add a new card:

```html
<a href="http://your-service.macula.local" class="service-card">
  <div class="service-header">
    <div class="service-icon">🎯</div>
    <div class="service-name">Your Service</div>
  </div>
  <p class="service-description">
    Description of what your service does
  </p>
  <div class="service-url">your-service.macula.local</div>
  <span class="status-badge status-operational">Operational</span>
</a>
```

Then restart the portal:
```bash
docker compose restart portal
```

### Bookmark for Quick Access

Set `http://home.macula.local` as your browser's home page or pin it as a tab to have instant access to all services.

### Team Onboarding

New developers can simply open `http://home.macula.local` to see all available services instead of hunting through documentation.

## Service Status

The portal shows all services as "Operational" by default. In the future, this could be enhanced to:
- Check service health via HTTP endpoints
- Show real-time status (healthy/unhealthy)
- Display service metrics (uptime, response time)

For now, it serves as a convenient bookmark page for all infrastructure UIs.

## Troubleshooting

**Portal shows 403 Forbidden:**
```bash
# Fix file permissions
chmod 755 infrastructure/portal
chmod 644 infrastructure/portal/index.html
docker compose restart portal
```

**DNS not resolving home.macula.local:**
```bash
# Re-run DNS setup
cd infrastructure
sudo ./setup-dnsmasq.sh

# Or add to /etc/hosts manually
echo "127.0.0.1 home.macula.local" | sudo tee -a /etc/hosts
```

**Portal not showing in docker compose ps:**
```bash
# Start the portal
docker compose up -d portal
```

## Summary

The Macula Infrastructure Portal provides a **single, beautiful landing page** for all infrastructure services, making it easy to:

- ✅ Find service URLs quickly
- ✅ Understand what each service does
- ✅ Access all UIs from one place
- ✅ Onboard new team members
- ✅ Keep track of available infrastructure

**URL**: http://home.macula.local
