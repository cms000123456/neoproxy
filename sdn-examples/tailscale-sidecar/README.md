# Tailscale Sidecar - Easiest Multi-Host Docker Networking

Tailscale creates an encrypted mesh network between hosts using WireGuard. Containers can communicate securely across the internet as if on the same LAN.

## Quick Start

### 1. Get Auth Key

1. Sign up at [tailscale.com](https://tailscale.com)
2. Go to **Admin Console > Keys**
3. Generate **Auth Key** (enable reusable for multiple hosts)

### 2. Add Tailscale to Docker Compose

```yaml
services:
  tailscale:
    image: tailscale/tailscale:latest
    container_name: tailscale
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - NET_RAW
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - ./tailscale:/var/lib/tailscale
    environment:
      - TS_AUTHKEY=tskey-auth-your-key-here
      - TS_HOSTNAME=docker-host-$(hostname)
    networks:
      - proxy-network
```

### 3. Update .env

```bash
TS_AUTHKEY=tskey-auth-your-key-here
```

## How It Works

```
Internet
   │
   ▼
┌─────────────────────────────────────┐
│         Tailscale Network           │
│   100.x.x.x (WireGuard mesh)        │
│                                     │
│  ┌─────────┐      ┌─────────┐      │
│  │ Host A  │◄────►│ Host B  │      │
│  │NPM+Auth │      │  Apps   │      │
│  └─────────┘      └─────────┘      │
└─────────────────────────────────────┘
```

## Cross-Host Container Communication

Once connected, containers can reach each other by Tailscale IP:

```bash
# On Host A, reach Host B's containers
curl http://100.x.x.x:8096  # Jellyfin on Host B

# Or use MagicDNS hostnames
curl http://docker-host-hostb:8096
```

## NPM Configuration for Remote Hosts

In NPM, use Tailscale IPs or hostnames:

| Setting | Value |
|---------|-------|
| Domain Names | `app.yourdomain.com` |
| Forward Hostname/IP | `docker-host-hostb` (or `100.x.x.x`) |
| Forward Port | `8080` |

## Full Example: docker-compose.yml

See `docker-compose.tailscale.yml` for complete setup.

## Subnet Routing (Advanced)

Expose entire Docker network to Tailscale:

```yaml
environment:
  - TS_ROUTES=172.20.0.0/16
```

Then accept routes on other nodes:
```bash
sudo tailscale up --accept-routes
```

## ACLs (Access Control)

In Tailscale admin console, restrict access:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:docker-hosts"],
      "dst": ["100.x.x.x:443", "100.x.x.x:80"]
    }
  ]
}
```

## Pros & Cons

| ✅ Pros | ❌ Cons |
|---------|---------|
| 5 minute setup | External service dependency |
| Automatic encryption | Free plan: 1 user, 100 devices |
| NAT traversal | |
| Built-in DNS | |
