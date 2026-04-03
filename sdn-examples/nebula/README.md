# Nebula - Self-Hosted Mesh Network (Slack)

Nebula is a scalable overlay networking tool focused on performance, simplicity and security. Perfect for "host-only" type networks.

## Why Nebula?

- ✅ **Self-hosted** - No external dependencies
- ✅ **Fast** - Better performance than VPNs
- ✅ **Simple** - Static binary, minimal config
- ✅ **Secure** - Certificate-based auth
- ✅ **Firewall** - Built-in layer 4 firewall
- ✅ **Lighthouse** - Automatic peer discovery

## Architecture

```
                    Internet
                       │
           ┌───────────┴───────────┐
           │    Lighthouse Node    │
           │   (Coordination only) │
           │      203.0.113.1      │
           └───────────┬───────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │  Host A │◄─►│  Host B │◄─►│  Host C │
   │10.8.0.2 │   │10.8.0.3 │   │10.8.0.4 │
   │ Docker  │   │ Docker  │   │ Docker  │
   └─────────┘   └─────────┘   └─────────┘
   
   Direct peer-to-peer (preferred)
   Or relay through lighthouse (fallback)
```

## Quick Start

### 1. Download Nebula

```bash
# On each host
curl -L -o nebula.tar.gz "https://github.com/slackhq/nebula/releases/latest/download/nebula-linux-amd64.tar.gz"
tar -xzf nebula.tar.gz
sudo mv nebula /usr/local/bin/
sudo mv nebula-cert /usr/local/bin/
```

### 2. Create Certificate Authority

On one host (or secure admin machine):

```bash
mkdir nebula-ca
cd nebula-ca

# Create CA
nebula-cert ca -name "MyOrg"
# Generates: ca.crt, ca.key (keep ca.key SECURE!)
```

### 3. Generate Host Certificates

```bash
# For NPM/Authentik host
nebula-cert sign -name "npm-host" -ip "10.8.0.2/24" -groups "docker,proxy"

# For apps host 1
nebula-cert sign -name "apps-host-1" -ip "10.8.0.3/24" -groups "docker,apps"

# For apps host 2
nebula-cert sign -name "apps-host-2" -ip "10.8.0.4/24" -groups "docker,apps"

# For lighthouse (publicly accessible)
nebula-cert sign -name "lighthouse" -ip "10.8.0.1/24" -groups "lighthouse"
```

### 4. Lighthouse Configuration

`config.lighthouse.yml`:
```yaml
pki:
  ca: /etc/nebula/ca.crt
  cert: /etc/nebula/lighthouse.crt
  key: /etc/nebula/lighthouse.key

static_host_map:
  "10.8.0.1": ["203.0.113.1:4242"]

lighthouse:
  am_lighthouse: true
  interval: 60

listen:
  host: 0.0.0.0
  port: 4242

punchy:
  punch: true

relay:
  am_relay: true
  use_relays: true

tun:
  disabled: false
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    - port: any
      proto: any
      host: any
```

### 5. Regular Node Configuration

`config.node.yml`:
```yaml
pki:
  ca: /etc/nebula/ca.crt
  cert: /etc/nebula/npm-host.crt  # Change per host
  key: /etc/nebula/npm-host.key

static_host_map:
  "10.8.0.1": ["203.0.113.1:4242"]

lighthouse:
  hosts:
    - "10.8.0.1"
  interval: 60

listen:
  host: 0.0.0.0
  port: 0  # Random port

punchy:
  punch: true
  respond: true

relay:
  am_relay: false
  use_relays: true
  relays:
    - 10.8.0.1

tun:
  disabled: false
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    # Allow all from docker hosts
    - port: any
      proto: any
      groups:
        - docker
    # Allow HTTP/HTTPS from anywhere
    - port: 80
      proto: tcp
      host: any
    - port: 443
      proto: tcp
      host: any
```

### 6. Docker Compose Integration

```yaml
services:
  nebula:
    image: ghcr.io/slackhq/nebula:latest
    container_name: nebula
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    volumes:
      - ./nebula:/etc/nebula:ro
    command: -config /etc/nebula/config.yml
    networks:
      - nebula-net
      - proxy-network  # Join proxy network

  # Your services can now reach 10.8.0.x IPs
  npm:
    # ... config
    networks:
      - proxy-network

networks:
  proxy-network:
    driver: bridge
  nebula-net:
    driver: bridge
```

## NPM Configuration

In NPM, use Nebula IPs:

| Domain | Forward IP | Notes |
|--------|------------|-------|
| `app1.yourdomain.com` | `10.8.0.3` | apps-host-1 |
| `app2.yourdomain.com` | `10.8.0.4` | apps-host-2 |

## Advanced: Docker Network Routes

Route entire Docker networks through Nebula:

```bash
# On each host, after Nebula starts
sudo ip route add 10.8.0.0/24 dev nebula1

# Advertise Docker network to others
# Add to config.yml outbound firewall rules
```

## Security: Firewall Rules

Restrict by groups in `config.yml`:

```yaml
firewall:
  inbound:
    # Only proxy hosts can access management ports
    - port: 81
      proto: tcp
      groups:
        - proxy
    
    # Apps hosts can talk to each other
    - port: any
      proto: any
      groups:
        - apps
    
    # Public web services
    - port: 80
      proto: tcp
      host: any
    - port: 443
      proto: tcp
      host: any
```

## Comparison

| Feature | Nebula | Tailscale | WireGuard |
|---------|--------|-----------|-----------|
| Self-hosted | ✅ Full | ❌ Partial | ✅ Full |
| Centralized config | ✅ Yes | ✅ Yes | ❌ No |
| Auto NAT traversal | ✅ Yes | ✅ Yes | ❌ Manual |
| Built-in firewall | ✅ Yes | ✅ ACLs | ❌ No |
| Certificate rotation | ✅ Yes | ✅ Yes | ❌ Manual |
| Mobile clients | ✅ Yes | ✅ Yes | ✅ Yes |
