# Cross-Host Container Proxying with NPM

## The Short Answer

| Question | Answer |
|----------|--------|
| Can NPM proxy to another host? | ✅ Yes |
| Using container name? | ❌ Not directly (names are local to each host) |
| Without exposing ports publicly? | ✅ Yes, with VPN/SDN |

## The Problem

Container names are only DNS-resolvable **within the same Docker daemon**:

```
Host A                          Host B
┌─────────────────┐            ┌─────────────────┐
│  ┌───────────┐  │            │  ┌───────────┐  │
│  │    NPM    │──┼──X Can't──►│  │  my-app   │  │
│  │           │  │  resolve   │  │  (name)   │  │
│  └───────────┘  │            │  └───────────┘  │
└─────────────────┘            └─────────────────┘
```

## Solutions

### Solution 1: Use VPN IPs (Recommended)

With Tailscale/Nebula/WireGuard between hosts:

```
Host A                          Host B
┌─────────────────┐   VPN      ┌─────────────────┐
│  ┌───────────┐  │  Tunnel    │  ┌───────────┐  │
│  │    NPM    │──┼───────────►│  │  my-app   │  │
│  │           │  │ 10.8.0.3   │  │  :8080    │  │
│  └───────────┘  │            │  └───────────┘  │
└─────────────────┘            └─────────────────┘
         │                              │
         │     NPM config:              │
         │     Forward: 10.8.0.3:8080   │
         │     (port not public!)       │
         └──────────────────────────────┘
```

**NPM Configuration:**
- Forward Hostname/IP: `10.8.0.3` (or `100.x.x.x` for Tailscale)
- Forward Port: `8080`
- Scheme: `http`

The container on Host B **does NOT need** `ports:` in docker-compose - it's accessible via the VPN tunnel interface.

### Solution 2: Docker Swarm (Native Overlay)

Docker Swarm creates a true multi-host overlay network with DNS:

```yaml
# docker-compose.swarm.yml
version: "3.8"

services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    networks:
      - overlay-net
    deploy:
      placement:
        constraints: [node.role == manager]

  my-app:
    image: myapp:latest
    networks:
      - overlay-net
    deploy:
      placement:
        constraints: [node.hostname == worker1]

networks:
  overlay-net:
    driver: overlay
    attachable: true  # Allow standalone containers to join
```

**NPM can now use:** `http://my-app:8080`

The name resolves across the Swarm overlay network!

### Solution 3: External DNS with Consul/CoreDNS

For container name resolution across hosts:

```
┌─────────────────────────────────────────┐
│          Consul / CoreDNS               │
│    (Service Discovery & DNS)            │
└─────────────────┬───────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
┌────────┐   ┌────────┐   ┌────────┐
│ Host A │   │ Host B │   │ Host C │
│  NPM   │──►│ my-app │   │  etc   │
└────────┘   └────────┘   └────────┘

NPM queries: my-app.service.consul → 10.8.0.3
```

### Solution 4: Manual /etc/hosts

Simple but doesn't scale:

```yaml
# On Host A, add to /etc/hosts
10.8.0.3  my-app

# NPM config
Forward: http://my-app:8080
```

Or via docker-compose:

```yaml
services:
  npm:
    extra_hosts:
      - "my-app:10.8.0.3"
      - "other-app:10.8.0.4"
```

## Complete Working Example

### Host A (NPM + Tailscale)

```yaml
version: "3.8"

services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    networks:
      - proxy-network

  tailscale:
    image: tailscale/tailscale:latest
    cap_add: [NET_ADMIN, NET_RAW]
    devices: [/dev/net/tun]
    environment:
      - TS_AUTHKEY=${TS_AUTHKEY}
    networks:
      - proxy-network  # Shares network with NPM

networks:
  proxy-network:
    driver: bridge
```

### Host B (Application + Tailscale)

```yaml
version: "3.8"

services:
  my-app:
    image: myapp:latest
    # NO ports exposed! Only accessible via VPN
    networks:
      - app-network

  tailscale:
    image: tailscale/tailscale:latest
    cap_add: [NET_ADMIN, NET_RAW]
    devices: [/dev/net/tun]
    environment:
      - TS_AUTHKEY=${TS_AUTHKEY}
      - TS_HOSTNAME=host-b-apps
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

### NPM Proxy Host Configuration

| Setting | Value |
|---------|-------|
| Domain Names | `myapp.yourdomain.com` |
| Scheme | `http` |
| Forward Hostname/IP | `host-b-apps` (or `100.x.x.x`) |
| Forward Port | `8080` |

The `my-app` container's port 8080 is **NOT exposed publicly** - only reachable through the Tailscale tunnel.

## Verification

From NPM container on Host A:

```bash
# Should resolve to Tailscale IP
docker compose exec npm nslookup host-b-apps

# Should connect successfully
docker compose exec npm wget -qO- http://host-b-apps:8080
```

## Summary

| Method | Container Names | No Public Ports | Complexity |
|--------|-----------------|-----------------|------------|
| VPN IPs (Tailscale/Nebula) | ❌ Use hostnames | ✅ Yes | Low |
| Docker Swarm | ✅ Yes | ✅ Yes | Medium |
| Consul DNS | ✅ Yes | ✅ Yes | High |
| /etc/hosts | ✅ Manual | ✅ Yes | Low |

**Recommendation**: Use Tailscale/Nebula with hostnames for simplicity, or Docker Swarm if you want native container name resolution.
