# Hub-and-Spoke Secure Proxy Architecture

Main host (Hub) runs NPM + Authentik + VPN, remote hosts (Spokes) connect and expose services securely without public exposure.

```
                                    Internet
                                       │
                                       ▼
                            ┌──────────────────────┐
                            │   Main Host (HUB)    │
                            │  ┌────────────────┐  │
                            │  │      NPM       │  │◄── Public entry point
                            │  │   (80/443/81)  │  │
                            │  └───────┬────────┘  │
                            │  ┌───────▼────────┐  │
                            │  │   Authentik    │  │
                            │  └───────┬────────┘  │
                            │  ┌───────▼────────┐  │
                            │  │Nebula/Lighthouse│ │◄── VPN Coordinator
                            │  │   (10.8.0.1)   │  │
                            └──┬───────┬───────────┘
                               │       │
              ┌────────────────┘       └────────────────┐
              │VPN Tunnels (encrypted)                  │
              ▼                                         ▼
    ┌───────────────────┐                    ┌───────────────────┐
    │  Remote Host 1    │                    │  Remote Host 2    │
    │  ┌─────────────┐  │                    │  ┌─────────────┐  │
    │  │   Nebula    │  │                    │  │   Nebula    │  │
    │  │ (10.8.0.2)  │  │                    │  │ (10.8.0.3)  │  │
    │  └──────┬──────┘  │                    │  └──────┬──────┘  │
    │         │routes   │                    │         │routes   │
    │  ┌──────▼──────┐  │                    │  ┌──────▼──────┐  │
    │  │  Docker Net │  │                    │  │  Docker Net │  │
    │  │172.20.0.0/16│  │                    │  │172.21.0.0/16│  │
    │  │             │  │                    │  │             │  │
    │  │ ┌─────────┐ │  │                    │  │ ┌─────────┐ │  │
    │  │ │ App A   │ │  │                    │  │ │ App B   │ │  │
    │  │ │ :8080   │ │  │                    │  │ │ :8080   │ │  │
    │  │ └─────────┘ │  │                    │  │ └─────────┘ │  │
    │  └─────────────┘  │                    │  └─────────────┘  │
    └───────────────────┘                    └───────────────────┘
    
    NPM proxies to:                          NPM proxies to:
    - 172.20.0.2:8080 (via 10.8.0.2)         - 172.21.0.2:8080 (via 10.8.0.3)
    - Port 3306, 5432, etc.                  - Same ports, different network!
```

## Key Features

- ✅ **Isolated networks**: Each remote host has its own 172.x.0.0/16
- ✅ **Same ports everywhere**: Host 1 and Host 2 can both use port 8080
- ✅ **No public exposure**: Apps have no `ports:` mapping
- ✅ **Direct routing**: NPM reaches containers by their Docker IP through VPN
- ✅ **Automatic discovery**: Nebula lighthouse coordinates connections

## Quick Start

### 1. Setup Hub (Main Host)

```bash
cd hub-spoke
./setup-hub.sh
docker compose up -d
```

### 2. Generate Spoke Configs

```bash
# For each remote host
./generate-spoke.sh host1 172.20.0.0/16  # Gets 10.8.0.2
./generate-spoke.sh host2 172.21.0.0/16  # Gets 10.8.0.3
./generate-spoke.sh host3 172.22.0.0/16  # Gets 10.8.0.4
```

### 3. Deploy to Remote Hosts

```bash
# Copy to remote host
scp -r spokes/host1 user@remote-host1:~/spoke/

# On remote host
ssh user@remote-host1
cd ~/spoke
docker compose up -d
```

### 4. Configure NPM Proxy Hosts

| Domain | Forward IP | Port | Notes |
|--------|------------|------|-------|
| `app1.yourdomain.com` | `172.20.0.2` | `8080` | Host 1 - App A |
| `app2.yourdomain.com` | `172.21.0.2` | `8080` | Host 2 - App B (same port!) |
| `db1.internal` | `172.20.0.3` | `5432` | Host 1 - Postgres |
| `db2.internal` | `172.21.0.3` | `5432` | Host 2 - Postgres (same port!) |

## Network Isolation

Each spoke has its own isolated Docker network:

```
Host 1: 172.20.0.0/16
  - Container A: 172.20.0.2
  - Container B: 172.20.0.3
  - Container C: 172.20.0.4

Host 2: 172.21.0.0/16
  - Container A: 172.21.0.2  (same service, different IP!)
  - Container B: 172.21.0.3
  - Container C: 172.21.0.4

Host 3: 172.22.0.0/16
  - Container A: 172.22.0.2  (same service, different IP!)
  ...
```

All reachable from NPM through the VPN tunnel!
