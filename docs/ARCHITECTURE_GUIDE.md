# Architecture Guide

Choose the right NeoProxy setup for your needs.

## Decision Tree

```
How many servers do you have?
│
├─ 1 server ───────────────────► STANDALONE
│                                  └─ Single host, simple setup
│
├─ 2-3 servers ────────────────┬─ HUB-SPOKE (recommended)
│   │                            │   └─ Central proxy, remote apps
│   │                            │
│   └─ Need HA failover? ──────┬─ HA with 2 nodes (DRBD)
│                                └─ Active-passive, shared storage
│
└─ 3+ servers ─────────────────┬─ HUB-SPOKE with HA hub
                                 │   └─ Multiple hubs with failover
                                 │
                                 └─ HA with 3 nodes (GlusterFS)
                                     └─ Full redundancy
```

---

## Setup Types

### 1. Standalone

**Best for:** Single server, development, simple setups

```
┌─────────────────────────────────────┐
│  ┌─────────┐  ┌──────────────┐     │
│  │   NPM   │  │  Authentik   │     │
│  │ :80/443 │  │   :9000      │     │
│  └────┬────┘  └──────────────┘     │
│       │                             │
│  ┌────▼────┐                       │
│  │  Apps   │                       │
│  └─────────┘                       │
└─────────────────────────────────────┘
```

**Pros:**
- ✅ Simplest setup
- ✅ Single point of management
- ✅ Minimal resource usage

**Cons:**
- ❌ Single point of failure
- ❌ Limited to one server's resources

**Start here:**
```bash
./setup.sh
# Select: 1 (Standalone)
```

---

### 2. Hub-Spoke

**Best for:** Multiple servers, microservices, distributed apps

```
                      Internet
                         │
                         ▼
              ┌────────────────────┐
              │       HUB          │
              │  ┌──────────────┐  │
              │  │ NPM+Authentik│  │
              │  │  Nebula VPN  │  │
              └──┬──────┬───────┘  │
                 │      │          │
        ┌────────┘      └────────┐
        │         VPN Tunnel     │
        ▼                        ▼
┌──────────────┐        ┌──────────────┐
│ SPOKE 1      │        │ SPOKE 2      │
│ 172.20.0.x   │        │ 172.21.0.x   │
│ ┌──────────┐ │        │ ┌──────────┐ │
│ │   App    │ │        │ │   App    │ │
│ └──────────┘ │        │ └──────────┘ │
└──────────────┘        └──────────────┘
```

**Pros:**
- ✅ Distribute apps across servers
- ✅ Same ports on each spoke
- ✅ Secure VPN between hosts
- ✅ Spokes need no public IPs

**Cons:**
- ❌ Hub is single point of failure
- ❌ More complex initial setup

**Start here:**
```bash
# On hub
./setup.sh
# Select: 2 (Hub)

# On each spoke
./setup.sh
# Select: 3 (Spoke)
```

---

### 3. High Availability (HA)

**Best for:** Production, critical services, zero downtime

#### Option A: 2 Controllers (DRBD)

```
         Internet
            │
    ┌───────┴───────┐
    │  Floating IP  │
    └───────┬───────┘
    ┌───────┴───────┐
┌───▼───┐     ┌─────▼────┐
│Ctrl 1 │◄───►│  Ctrl 2  │
│Active │ DRBD│ Standby  │
└───────┘     └──────────┘
```

**Pros:**
- ✅ Automatic failover
- ✅ Synchronous replication
- ✅ Zero data loss

**Cons:**
- ❌ Only 2 nodes
- ❌ Standby node idle
- ❌ More complex

#### Option B: 3+ Controllers (GlusterFS)

```
         Internet
            │
    ┌───────┴───────┐
    │  Floating IP  │
    └───────┬───────┘
    ┌───────┼───────┐
    ▼       ▼       ▼
┌──────┐┌──────┐┌──────┐
│Ctrl 1││Ctrl 2││Ctrl 3│
│Active││Backup││Backup│
└──┬───┘└──┬───┘└──┬───┘
   │       │       │
   └───────┼───────┘
           │
    ┌──────▼──────┐
    │  GlusterFS  │
    │   Cluster   │
    └─────────────┘
```

**Pros:**
- ✅ Automatic failover
- ✅ Multiple standby nodes
- ✅ Self-healing storage

**Cons:**
- ❌ Most complex setup
- ❌ Higher resource usage

**Start here:**
```bash
cd ha-setup
./setup-ha.sh
# Select: 1 (Setup shared storage)
```

---

## Comparison Table

| Feature | Standalone | Hub-Spoke | HA (2-node) | HA (3-node) |
|---------|------------|-----------|-------------|-------------|
| Servers | 1 | 2+ | 2 | 3+ |
| Complexity | Low | Medium | High | High |
| Failover | No | No | Yes | Yes |
| Data sync | N/A | VPN | DRBD | GlusterFS |
| Storage | Local | Local | Replicated | Distributed |
| Best for | Dev, small | Multi-host | Production | Enterprise |

---

## Scaling Considerations

### When to Upgrade

**Standalone → Hub-Spoke:**
- Running out of resources on one server
- Want to separate apps by function
- Need to isolate services

**Hub-Spoke → HA:**
- Hub becoming a bottleneck
- Need zero downtime
- Business critical services

### Hybrid Setup

You can combine approaches:

```
                    Internet
                       │
              ┌────────┴────────┐
              │   HA Hub Pair   │
              │ (Floating IP)   │
              └────────┬────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  Spoke 1    │ │  Spoke 2    │ │  Spoke 3    │
│ (Database)  │ │ (Apps)      │ │ (Workers)   │
└─────────────┘ └─────────────┘ └─────────────┘
```

---

## Resource Planning

### Minimum Specs by Role

| Role | CPU | RAM | Storage | Network |
|------|-----|-----|---------|---------|
| Standalone | 1 core | 2 GB | 20 GB | 100 Mbps |
| Hub | 2 cores | 4 GB | 40 GB | 1 Gbps |
| Spoke | 1 core | 2 GB | 20 GB | 100 Mbps |
| HA Controller | 2 cores | 4 GB | 40 GB | 1 Gbps |

### Scaling Tips

1. **Start small:** Use standalone, add spokes as needed
2. **Plan subnets:** Reserve IP ranges for future spokes
3. **Monitor hub:** If hub CPU > 70%, consider HA
4. **Storage:** Spokes can use less storage (no NPM/Authentik data)

---

## Migration Paths

### Standalone → Hub-Spoke

1. Keep standalone as hub
2. Move apps to new spoke
3. Update NPM proxy hosts to use spoke IPs

### Hub-Spoke → HA

1. Set up HA pair as new hub
2. Copy data to shared storage
3. Update spokes to connect to new hub
4. Update DNS to floating IP

---

## Recommendations by Use Case

| Use Case | Recommended Setup |
|----------|-------------------|
| Personal projects | Standalone |
| Small business | Hub + 1-2 spokes |
| Medium business | HA hub + multiple spokes |
| Enterprise | HA hub + spokes + monitoring |
| Development | Standalone per developer |
| CI/CD pipelines | Hub + ephemeral spokes |
| Multi-region | HA hub per region + spokes |
