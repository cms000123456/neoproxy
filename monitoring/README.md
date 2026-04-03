# Monitoring Stack for NeoProxy

High-availability monitoring for your infrastructure.

## Architecture Options

### Option 1: Kuma with Shared Storage (Recommended)

Multiple Kuma instances share the same SQLite database via GlusterFS.

```
┌─────────────────────────────────────────────────────┐
│              HA Controllers                          │
│                                                      │
│  ┌──────────────┐      ┌──────────────┐             │
│  │   Kuma 1     │◄────►│   Kuma 2     │             │
│  │  (Active)    │Shared│  (Standby)   │             │
│  │              │ DB   │              │             │
│  └──────┬───────┘      └───────┬──────┘             │
│         │                       │                    │
│         └───────────┬───────────┘                    │
│                     │                                │
│            ┌────────▼────────┐                       │
│            │  GlusterFS      │                       │
│            │  (kuma.db)      │                       │
│            └─────────────────┘                       │
└─────────────────────────────────────────────────────┘
                     │
        Monitors ────┼───────────────────────────────
                     │
            ┌────────┴────────┐
            ▼                 ▼
      ┌───────────┐     ┌───────────┐
      │  Spoke 1  │     │  Spoke 2  │
      └───────────┘     └───────────┘
```

**Pros:**
- Native Kuma interface
- Automatic failover
- Simple setup

**Cons:**
- SQLite locking (use PostgreSQL for better concurrency)

### Option 2: Kuma with PostgreSQL

Kuma uses PostgreSQL backend (better for multiple writers).

```
┌─────────────────────────────────────────────────────┐
│              HA Controllers                          │
│                                                      │
│  ┌──────────────┐      ┌──────────────┐             │
│  │   Kuma 1     │◄────►│   Kuma 2     │             │
│  │              │      │              │             │
│  └──────┬───────┘      └──────┬──────┘             │
│         │                     │                      │
│         └─────────┬───────────┘                      │
│                   │                                  │
│            ┌──────▼──────┐                           │
│            │ PostgreSQL  │                           │
│            │  (shared)   │                           │
│            └─────────────┘                           │
└─────────────────────────────────────────────────────┘
```

**Pros:**
- Better concurrency
- Supports multiple active instances
- Can use existing Authentik PostgreSQL

### Option 3: Prometheus + Grafana

Enterprise monitoring with time-series data.

```
┌─────────────────────────────────────────────────────┐
│              Monitoring Stack                        │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │Prometheus│  │ Grafana  │  │  Kuma    │          │
│  │  (TSDB)  │  │(Visuals) │  │(Uptime)  │          │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│       │             │             │                 │
│       └─────────────┴─────────────┘                 │
│                                                      │
│  Monitors all services, containers, hosts           │
└─────────────────────────────────────────────────────┘
```

## Quick Start - Kuma HA

### 1. Add to docker-compose.ha.yml

```yaml
services:
  kuma:
    image: louislam/uptime-kuma:latest
    container_name: kuma
    restart: unless-stopped
    volumes:
      # Shared storage for HA
      - ${SHARED_DATA_PATH:-./data}/kuma:/app/data
    environment:
      # Use PostgreSQL for better HA (optional)
      # UPTIME_KUMA_DB_TYPE: postgres
      # UPTIME_KUMA_DB_HOSTNAME: postgresql
      # UPTIME_KUMA_DB_PORT: 5432
      # UPTIME_KUMA_DB_NAME: kuma
      # UPTIME_KUMA_DB_USERNAME: kuma
      # UPTIME_KUMA_DB_PASSWORD: ${KUMA_DB_PASS}
    networks:
      - proxy-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 2. Configure on First Controller

Access Kuma on the active controller:

```
http://VIRTUAL_IP:3001
```

**Initial Setup:**
1. Create admin account
2. Add monitors for:
   - NPM: `http://localhost:81` (via Docker network)
   - Authentik: `http://authentik-server:9000/-/health/`
   - Each spoke: `ping 172.20.0.1`
   - External sites: `https://yourdomain.com`

### 3. Automatic Failover

Since Kuma uses shared storage:

1. **Active controller fails**
2. **Keepalived moves floating IP**
3. **Kuma on new controller uses same DB**
4. **Monitoring continues seamlessly**

## Monitoring Setup

### Essential Monitors

| Monitor | Type | Target | Interval |
|---------|------|--------|----------|
| NPM Admin | HTTP(s) | `http://npm:81` | 60s |
| NPM Proxy | HTTP(s) | `https://yourdomain.com` | 60s |
| Authentik | HTTP(s) | `http://authentik-server:9000/-/health/` | 30s |
| VPN Hub | Ping | `10.8.0.1` | 30s |
| Spoke 1 | Ping | `172.20.0.1` | 60s |
| Spoke 2 | Ping | `172.21.0.1` | 60s |
| DNS | DNS | `yourdomain.com` | 300s |
| SSL Cert | HTTP(s) | `https://yourdomain.com` | 3600s |

### Docker Monitors

Monitor container health:

```bash
# Add to Kuma as "Push" monitor
# Use this script on each host:

#!/bin/bash
# health-push.sh

KUMA_URL="http://VIRTUAL_IP:3001/api/push/TOKEN"

# Check all containers
if docker ps | grep -q "unhealthy"; then
    curl -s "$KUMA_URL?status=down&msg=Unhealthy+containers"
else
    curl -s "$KUMA_URL?status=up&msg=All+healthy"
fi
```

Add to crontab:
```bash
*/5 * * * * /opt/neoproxy/monitoring/health-push.sh
```

## Notifications

### Configure Alerts

In Kuma:

1. **Settings > Notifications**
2. Add notification channels:
   - **Email**: SMTP settings
   - **Slack**: Webhook URL
   - **Discord**: Webhook URL
   - **Telegram**: Bot token + Chat ID
   - **Pushover**: API key

### Recommended Alert Rules

| Monitor | Down Alert | Up Alert |
|---------|------------|----------|
| Production sites | Immediate | Yes |
| Internal services | 2 minutes | Yes |
| Spokes | 5 minutes | Yes |
| SSL Certs (expiry) | 7 days before | No |

## Advanced: Prometheus + Grafana

For detailed metrics and dashboards:

### 1. Deploy Prometheus

See [prometheus/](./prometheus/) for configuration.

### 2. Node Exporter

Run on every host:

```yaml
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
    networks:
      - monitoring
```

### 3. cAdvisor (Container Metrics)

```yaml
services:
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring
```

### 4. Grafana Dashboards

Import dashboards:
- Node Exporter Full (ID: 1860)
- Docker Monitoring (ID: 893)
- Nginx (ID: 9614)

## Monitoring the Monitors

### Meta-Monitoring

Who watches the watchers?

```bash
# Simple watchdog script
#!/bin/bash
# kuma-watchdog.sh

if ! curl -sf http://localhost:3001 > /dev/null; then
    # Kuma is down, restart it
    docker compose restart kuma
    # Also notify via alternative channel
    echo "Kuma was restarted" | mail -s "Kuma Alert" admin@domain.com
fi
```

### External Monitoring

Use external service to monitor your monitoring:

- UptimeRobot (free tier)
- Pingdom
- StatusCake

Point at: `https://status.yourdomain.com` (Kuma status page)

## Files

- [kuma/](./kuma/) - Kuma configurations
- [prometheus/](./prometheus/) - Prometheus setup
- [grafana/](./grafana/) - Grafana dashboards
