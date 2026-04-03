# Docker Swarm Overlay Network (Alternative)

Instead of Nebula + Consul, use Docker Swarm's built-in overlay networking and DNS.

## Why Swarm?

- ✅ Built-in service discovery and DNS
- ✅ Native to Docker - no extra tools
- ✅ Automatic load balancing
- ✅ Rolling updates
- ✅ Works over VPN (can combine with Nebula)

## Architecture

```
┌─────────────────────────────────────────┐
│              MANAGER NODE (Hub)          │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ │
│  │   NPM   │ │Authentik │ │  Swarm   │ │
│  │ Manager │ │          │ │ Manager  │ │
│  └────┬────┘ └──────────┘ └────┬─────┘ │
└───────┼────────────────────────┼───────┘
        │                        │
        │    Encrypted Overlay   │
        │        Network         │
        │     (VXLAN over        │
        │      Nebula/WAN)       │
        │                        │
┌───────┼────────────────────────┼───────┐
│       ▼                        ▼       │
│  ┌──────────────────────────────────┐  │
│  │     WORKER NODE 1 (Spoke 1)      │  │
│  │  ┌──────────┐    ┌──────────┐   │  │
│  │  │myapp_web │    │myapp_api │   │  │
│  │  │:8080     │    │:3000     │   │  │
│  │  └────┬─────┘    └────┬─────┘   │  │
│  │       │               │          │  │
│  │  http://myapp_web    http://myapp_api  │
│  │  resolves directly   resolves directly  │
│  │  from NPM!           from NPM!          │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Setup

### 1. Initialize Swarm on Hub

```bash
docker swarm init --advertise-addr 10.8.0.1  # Use Nebula VPN IP
```

Get join token:
```bash
docker swarm join-token worker
```

### 2. Join Spokes

On each remote host:
```bash
docker swarm join --token <token> 10.8.0.1:2377
```

### 3. Create Overlay Network

On hub:
```bash
docker network create \
  --driver overlay \
  --attachable \
  --opt encrypted \
  --subnet 10.10.0.0/16 \
  crosshost
```

### 4. Deploy Services

**docker-compose.swarm.yml:**
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
      - crosshost
    deploy:
      placement:
        constraints: [node.role == manager]

  whoami:
    image: traefik/whoami:latest
    networks:
      - crosshost
    deploy:
      placement:
        constraints: [node.hostname == spoke1]
      replicas: 1

  webapp:
    image: nginx:alpine
    networks:
      - crosshost
    deploy:
      placement:
        constraints: [node.hostname == spoke2]

networks:
  crosshost:
    external: true
```

Deploy:
```bash
docker stack deploy -c docker-compose.swarm.yml proxy
```

## DNS Resolution

From NPM (or any container on the network):

```bash
# These resolve automatically!
ping whoami      # → container IP on spoke1
ping webapp      # → container IP on spoke2
ping tasks.whoami # → All replicas (if scaled)
```

## NPM Configuration

| Domain | Forward Hostname | Port |
|--------|-----------------|------|
| `whoami.example.com` | `whoami` | `80` |
| `site.example.com` | `webapp` | `80` |

**No IPs needed!** Docker Swarm DNS handles it.

## Combining with Nebula

Best of both worlds:

```
┌─────────────────────────────────────────┐
│  Hub: Docker Swarm Manager + Nebula     │
│  + Consul (optional)                    │
│       │                                 │
│       │ Nebula encrypted tunnel         │
│       ▼                                 │
│  ┌─────────────────────────────────┐    │
│  │ Docker Swarm Overlay (VXLAN)    │    │
│  │ running OVER Nebula             │    │
│  │                                 │    │
│  │  ┌─────┐      ┌─────┐          │    │
│  │  │Spoke1│◄────►│Spoke2│          │    │
│  │  └─────┘      └─────┘          │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

This gives you:
- **Nebula**: Secure tunneling through NAT/firewalls
- **Swarm**: Native container DNS and orchestration

## Pros vs Cons

| Pros | Cons |
|------|------|
| Native Docker DNS | Swarm mode required |
| No extra tools (Consul, etc) | Slightly more complex setup |
| Automatic load balancing | Must use `docker stack deploy` |
| Encrypted overlay option | |

## Recommendation

- **Simple setup**: Use Nebula + static IPs
- **Medium complexity**: Use Nebula + Consul for DNS
- **Full orchestration**: Use Docker Swarm (with or without Nebula underneath)
