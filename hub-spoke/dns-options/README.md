# DNS Advertising Options for Hub-Spoke Architecture

Instead of using static IPs (172.20.0.2), use DNS names like `app.host1.internal` that automatically resolve to container IPs.

## Option 1: Nebula Built-in DNS (Simplest)

Nebula has a built-in DNS server on the lighthouse.

### Setup

**Hub (lighthouse config):**
```yaml
lighthouse:
  serve_dns: true
  dns:
    host: 0.0.0.0
    port: 53
  # Static DNS entries for spokes
  hosts:
    - 10.8.0.2  # These get DNS entries automatically
    - 10.8.0.3
```

**Spokes get automatic DNS:**
- `host1.nebula` → 10.8.0.2
- `host2.nebula` → 10.8.0.3

### Limitations
- Only resolves Nebula VPN IPs (10.8.0.x), not container IPs
- No automatic container registration

---

## Option 2: Consul + Consul-Template (Recommended)

Full service discovery with automatic DNS and health checks.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      HUB (Consul Server)                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   NPM       │  │  Authentik  │  │Consul Server│     │
│  │             │  │             │  │   (DNS)     │     │
│  │ Resolves:   │  │             │  │             │     │
│  │ app.host1.  │  │             │  │ Serves:     │     │
│  │  internal   │  │             │  │ *.internal  │     │
│  └─────────────┘  └─────────────┘  └──────┬──────┘     │
└───────────────────────────────────────────┼─────────────┘
                                            │
              ┌─────────────────────────────┼─────────────┐
              │         Queries             │             │
              ▼                             ▼             ▼
    ┌──────────────────┐        ┌──────────────────┐
    │   Spoke Host 1   │        │   Spoke Host 2   │
    │ ┌──────────────┐ │        │ ┌──────────────┐ │
    │ │Consul Client │ │        │ │Consul Client │ │
    │ │  + Registrator│ │        │ │  + Registrator│ │
    │ └──────┬───────┘ │        │ └──────┬───────┘ │
    │        │ watches  │        │        │ watches  │
    │  ┌─────▼──────┐   │        │  ┌─────▼──────┐   │
    │  │Containers  │   │        │  │Containers  │   │
    │  │Auto-registered│ │        │  │Auto-registered│ │
    │  └────────────┘   │        │  └────────────┘   │
    └──────────────────┘        └──────────────────┘
```

### How It Works

1. **Registrator** container watches Docker events on each spoke
2. When a container starts, it registers with Consul: `name: app, ip: 172.20.0.2, port: 8080`
3. **Consul DNS** serves records: `app.host1.internal → 172.20.0.2`
4. **NPM** uses Consul DNS to resolve container names

### Setup

See [consul-dns/](./consul-dns/) directory for complete setup.

---

## Option 3: CoreDNS + etcd (Lightweight)

Similar to Consul but lighter weight using CoreDNS.

```yaml
# CoreDNS config
. {
    etcd {
        path /skydns
        endpoint http://etcd:2379
    }
    forward . 8.8.8.8
}
```

Containers register themselves or via sidecar to etcd, CoreDNS serves the records.

---

## Option 4: Docker Swarm Native DNS

If using Docker Swarm instead of standalone Docker:

```bash
# Initialize swarm on hub
docker swarm init --advertise-addr 10.8.0.1

# Join spokes
docker swarm join --token <token> 10.8.0.1:2377
```

**Automatic DNS:**
- Service name resolves across the swarm overlay network
- `http://myservice` works from any node
- Built-in service discovery

See [swarm-overlay/](./swarm-overlay/) for setup.

---

## Option 5: Simple DNSMasq with Static Entries

For small setups, manual but simple:

```bash
# On hub, install dnsmasq
# Add to /etc/dnsmasq.conf

# Spoke 1 containers
host-record=app.host1.internal,172.20.0.2
host-record=db.host1.internal,172.20.0.3

# Spoke 2 containers  
host-record=app.host2.internal,172.21.0.2
host-record=db.host2.internal,172.21.0.3
```

NPM containers use this DNS server.

---

## Comparison

| Feature | Nebula DNS | Consul | CoreDNS | Swarm | DNSMasq |
|---------|------------|--------|---------|-------|---------|
| Auto container discovery | ❌ | ✅ | ✅ | ✅ | ❌ |
| Health checks | ❌ | ✅ | ❌ | ✅ | ❌ |
| Multi-datacenter | ❌ | ✅ | ✅ | ❌ | ❌ |
| Complexity | Low | Medium | Medium | Low* | Low |
| Self-hosted | ✅ | ✅ | ✅ | ✅ | ✅ |
| Container name as DNS | ❌ | ✅ | ✅ | ✅ | Manual |

*Swarm requires cluster mode

## Recommendation

- **Small setup (< 10 services)**: Use Nebula DNS + static /etc/hosts entries
- **Medium setup (10-50 services)**: Use Consul for full service discovery
- **Already using Swarm**: Use native Swarm DNS
- **Simple and static**: Use DNSMasq with manual entries
