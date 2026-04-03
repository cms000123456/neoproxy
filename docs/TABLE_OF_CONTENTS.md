# NeoProxy Documentation

Complete guide for setting up and managing your secure reverse proxy infrastructure.

## 🚀 Getting Started

| Document | Description |
|----------|-------------|
| [README.md](../README.md) | Main documentation, quick start, features |
| [Prerequisites](PREREQUISITES.md) | System requirements, Docker setup |
| [Quick Start Guide](QUICKSTART.md) | Get running in 5 minutes |

## 📖 Core Documentation

| Document | Description |
|----------|-------------|
| [Environment Variables](ENVIRONMENT_VARIABLES.md) | All configuration options |
| [Architecture Guide](ARCHITECTURE_GUIDE.md) | Choose the right setup for your needs |
| [Authentik Setup Guide](../AUTHENTIK-GUIDE.md) | Configure SSO/MFA |
| [NPM Configuration Examples](../examples/npm-config-example.md) | Proxy host configurations |

## 🌐 Networking

| Document | Description |
|----------|-------------|
| [Cross-Host Proxying](cross-host-proxying.md) | Connect multiple Docker hosts |
| [Hub-Spoke Setup](../hub-spoke/README.md) | Multi-host VPN architecture |
| [DNS Options](../hub-spoke/dns-options/README.md) | Service discovery options |

## 🏗️ Advanced Setups

| Document | Description |
|----------|-------------|
| [High Availability](../ha-setup/README.md) | Multi-controller with VRRP failover |
| [Control Panel](../control-panel/README.md) | Unified dashboard |
| [SDN Examples](../sdn-examples/) | Tailscale, WireGuard, Nebula |

## 🔧 Operations

| Document | Description |
|----------|-------------|
| [Troubleshooting](TROUBLESHOOTING.md) | Common issues and solutions |
| [Backup & Restore](BACKUP_RESTORE.md) | Data protection procedures |
| [Upgrading](UPGRADING.md) | Version upgrade procedures |
| [Security Hardening](SECURITY.md) | Best practices |

## 📋 Reference

| Document | Description |
|----------|-------------|
| [Cheat Sheet](CHEATSHEET.md) | Quick command reference |
| [Makefile Commands](../Makefile) | Available make targets |
| [Deploy Key Setup](../.github/DEPLOY_KEY_SETUP.md) | Repository access |

## 🗺️ Architecture Diagrams

```
Standalone (Single Host)
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

Hub-Spoke (Multi-Host)
┌──────────┐     VPN      ┌──────────┐
│   HUB    │◄────────────►│  SPOKE   │
│ ┌──────┐ │              │ ┌──────┐ │
│ │ NPM  │ │              │ │ App  │ │
│ │ Auth │ │              │ └──────┘ │
│ │ VPN  │ │              └──────────┘
└─┬──────┘ │
  │        │
  └────────┼────────► More spokes...
           │
High Availability (Multi-Controller)
    ┌──────────────┐
    │  Floating IP │
    └──────┬───────┘
    ┌──────┴───────┐
┌───▼───┐  ┌───────▼──┐
│Ctrl 1 │  │  Ctrl 2  │
│(Active)│  │(Standby) │
└───────┘  └──────────┘
```

## 🔍 Finding Information

**I want to...**

- **Get started quickly** → [Quick Start Guide](QUICKSTART.md)
- **Understand which setup to use** → [Architecture Guide](ARCHITECTURE_GUIDE.md)
- **Connect multiple servers** → [Hub-Spoke Setup](../hub-spoke/README.md)
- **Add authentication to my apps** → [Authentik Setup Guide](../AUTHENTIK-GUIDE.md)
- **Fix something that's broken** → [Troubleshooting](TROUBLESHOOTING.md)
- **Backup my configuration** → [Backup & Restore](BACKUP_RESTORE.md)
- **Make it production-ready** → [High Availability](../ha-setup/README.md) + [Security Hardening](SECURITY.md)

## 💡 Common Workflows

### 1. Add a New Application

```
1. Deploy app on spoke (or hub)
2. Note container IP (e.g., 172.20.0.2)
3. Create proxy host in NPM
4. Enable Authentik auth (optional)
5. Test access
```

### 2. Add a New Spoke Host

```
1. On hub: ./generate-spoke.sh host2 172.21.0.0/16 10.8.0.3
2. Copy spokes/host2 to remote server
3. On spoke: ./setup.sh (select spoke)
4. Deploy containers
5. Configure NPM proxy hosts
```

### 3. Enable High Availability

```
1. Setup shared storage (GlusterFS)
2. Configure keepalived on each controller
3. Deploy HA stack
4. Test failover
5. Update DNS to floating IP
```

## 🆘 Getting Help

1. Check [Troubleshooting](TROUBLESHOOTING.md) for common issues
2. Review logs: `docker compose logs -f`
3. Check service health: `docker compose ps`
4. Verify network connectivity: `ping`, `curl`

## 📚 External Resources

- [Nginx Proxy Manager Docs](https://nginxproxymanager.com/guide/)
- [Authentik Documentation](https://docs.goauthentik.io/)
- [Nebula Documentation](https://github.com/slackhq/nebula/blob/master/README.md)
- [Docker Compose Reference](https://docs.docker.com/compose/)
