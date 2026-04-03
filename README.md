# NeoProxy

Nginx Proxy Manager + Authentik SSO/MFA with secure inter-host container networking.

```
                                    Internet
                                       │
                                       ▼
                            ┌──────────────────────┐
                            │   HUB (This Stack)   │
                            │  ┌────────────────┐  │
                            │  │      NPM       │  │◄── Public entry
                            │  │   (80/443/81)  │  │
                            │  └───────┬────────┘  │
                            │  ┌───────▼────────┐  │
                            │  │   Authentik    │  │
                            │  └───────┬────────┘  │
                            │  ┌───────▼────────┐  │
                            │  │Nebula Lighthouse │ │◄── VPN Coordinator
                            │  │   (10.8.0.1)   │  │
                            └──┬───────┬───────────┘
                               │       │
              ┌────────────────┘       └────────────────┐
              │         Encrypted VPN Tunnels           │
              ▼                                         ▼
    ┌───────────────────┐                    ┌───────────────────┐
    │   SPOKE Host 1    │                    │   SPOKE Host 2    │
    │ 172.20.0.0/16     │                    │ 172.21.0.0/16     │
    │ ┌─────────────┐   │                    │ ┌─────────────┐   │
    │ │  Container  │   │                    │ │  Container  │   │
    │ │   :8080     │   │                    │ │   :8080     │   │
    │ └─────────────┘   │                    │ └─────────────┘   │
    │ (no public ports!)│                    │ (no public ports!)│
    └───────────────────┘                    └───────────────────┘
```

## Features

- 🚀 **Nginx Proxy Manager** - Easy reverse proxy management
- 🔐 **Authentik** - SSO, MFA, user management
- 🌐 **Inter-Host Networking** - Connect multiple Docker hosts securely
- 🔒 **No Public Exposure** - Remote containers accessible only via VPN
- 📊 **Control Panel** - Unified dashboard for all services
- 🔄 **Same Ports Everywhere** - Each host can use the same ports (8080, 5432, etc.)

## Quick Start

### 1. Clone and Setup

```bash
git clone git@github.com:cms000123456/neoproxy.git
cd neoproxy
./setup.sh
```

### 2. Choose Mode

The setup script offers three modes:

| Mode | Use Case |
|------|----------|
| **Standalone** | Single host with NPM + Authentik |
| **Hub** | Main proxy that accepts connections from remote hosts |
| **Spoke** | Remote host that connects to a hub |

### 3. Hub Setup (Main Host)

```bash
./setup.sh
# Select option 2 (Hub)
```

This starts:
- NPM on ports 80/443/81
- Authentik on port 9000
- Nebula lighthouse on port 4242/UDP

### 4. Generate Spoke Configs

```bash
# Generate config for each remote host
./generate-spoke.sh host1 172.20.0.0/16 10.8.0.2
./generate-spoke.sh host2 172.21.0.0/16 10.8.0.3
./generate-spoke.sh host3 172.22.0.0/16 10.8.0.4
```

### 5. Deploy Spokes

```bash
# Copy to remote host
scp -r spokes/host1 user@remote-host:/opt/neoproxy/

# On remote host
ssh user@remote-host
cd /opt/neoproxy
./setup.sh
# Select option 3 (Spoke)
```

### 6. Configure NPM

In NPM, proxy to remote container IPs:

| Domain | Forward IP | Port | Notes |
|--------|------------|------|-------|
| `app1.yourdomain.com` | `172.20.0.2` | `8080` | Host 1 - no public exposure! |
| `app2.yourdomain.com` | `172.21.0.2` | `8080` | Host 2 - same port, different IP! |

## Architecture

### Hub (Main Host)

```yaml
# docker-compose.yml
services:
  npm:              # Reverse proxy
  authentik-server: # Authentication
  authentik-worker: # Background tasks
  nebula-lighthouse:# VPN coordinator
```

### Spoke (Remote Host)

```yaml
# docker-compose.spoke.yml
services:
  nebula:           # VPN client (connects to hub)
  your-apps:        # Your containers (no ports exposed!)
```

## Network Isolation

Each spoke gets its own isolated Docker network:

```
Spoke 1: 172.20.0.0/16
  ├─ Container A: 172.20.0.2
  ├─ Container B: 172.20.0.3
  └─ Container C: 172.20.0.4

Spoke 2: 172.21.0.0/16
  ├─ Container A: 172.21.0.2  (same service, different network!)
  ├─ Container B: 172.21.0.3
  └─ Container C: 172.21.0.4
```

All accessible from the hub through encrypted VPN tunnels!

## Control Panel

Optional unified dashboard:

```bash
# Start with control panel
docker compose --profile hub --profile panel up -d
```

Access at `http://localhost:8080` (or proxy through NPM)

## Commands

```bash
# Start hub
docker compose --profile hub up -d

# Start spoke
docker compose -f docker-compose.spoke.yml up -d

# View status
docker compose ps

# Check VPN status
docker compose exec nebula-lighthouse nebula-cert sign -list

# Generate new spoke
./generate-spoke.sh <name> <subnet> <ip>

# View logs
docker compose logs -f
```

## Security

- 🔐 All inter-host traffic encrypted via Nebula (WireGuard-based)
- 🛡️ Remote containers have **no exposed ports** - only accessible via VPN
- 🔑 Certificate-based authentication for VPN
- 🔒 Authentik provides SSO/MFA for web applications
- 📝 Audit logging via Authentik

## High Availability (Optional)

For production deployments, run multiple controllers with automatic failover:

```
                       Internet
                          │
              ┌───────────┴───────────┐
              │   VRRP/Keepalived      │
              │   Floating IP          │
              └───────────┬───────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   ┌────────────┐  ┌────────────┐  ┌────────────┐
   │Controller 1│  │Controller 2│  │Controller 3│
   │  (MASTER)  │  │  (BACKUP)  │  │  (BACKUP)  │
   └──────┬─────┘  └──────┬─────┘  └──────┬─────┘
          │               │               │
          └───────────────┼───────────────┘
                          │
                 ┌────────▼────────┐
                 │  Shared Storage │
                 │ (GlusterFS/DRBD)│
                 └─────────────────┘
```

See [ha-setup/](ha-setup/) for complete HA configuration.

## File Structure

```
neoproxy/
├── docker-compose.yml           # Hub stack
├── docker-compose.spoke.yml     # Spoke stack
├── setup.sh                     # Interactive setup
├── generate-spoke.sh            # Generate spoke configs
├── nebula/                      # VPN certificates & configs
├── ha-setup/                    # High Availability setup
│   ├── docker-compose.ha.yml
│   ├── keepalived/              # VRRP configuration
│   ├── gluster/                 # Shared storage
│   └── setup-ha.sh
├── spokes/                      # Generated spoke packages
├── data/                        # Persistent data
├── control-panel/               # Optional dashboard
└── docs/                        # Documentation
```

## Documentation

| Document | Description |
|----------|-------------|
| [Table of Contents](docs/TABLE_OF_CONTENTS.md) | Navigate all documentation |
| [Quick Start](docs/QUICKSTART.md) | Get running in 5 minutes |
| [Prerequisites](docs/PREREQUISITES.md) | System requirements |
| [Architecture Guide](docs/ARCHITECTURE_GUIDE.md) | Choose your setup |
| [Environment Variables](docs/ENVIRONMENT_VARIABLES.md) | All config options |
| [Authentik Setup Guide](AUTHENTIK-GUIDE.md) | Configure SSO/MFA |
| [Cross-Host Proxying](docs/cross-host-proxying.md) | Detailed networking |
| [NPM Configuration Examples](examples/npm-config-example.md) | Proxy examples |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues |
| [Backup & Restore](docs/BACKUP_RESTORE.md) | Data protection |
| [Security Hardening](docs/SECURITY.md) | Best practices |
| [Cheat Sheet](docs/CHEATSHEET.md) | Quick commands |
| [Control Panel Options](control-panel/) | Dashboard setup |
| [High Availability Setup](ha-setup/) | Multi-controller HA |
| [Monitoring](monitoring/) | Uptime monitoring with Kuma |

## Ports

| Port | Service | Description |
|------|---------|-------------|
| 80 | NPM | HTTP traffic |
| 443 | NPM | HTTPS traffic |
| 81 | NPM | Admin UI |
| 4242/UDP | Nebula | VPN communication |
| 9000 | Authentik | Auth server (internal) |

## License

MIT - See repository for details.
