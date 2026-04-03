# Control Panel Options for NeoProxy

Unified dashboards to manage your hub-spoke infrastructure.

## Option 1: Homer (Recommended - Simple)

A clean, static dashboard with links to all your services and status indicators.

```
┌─────────────────────────────────────────────────────────┐
│  🏠 NeoProxy Control Panel                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  🌐 Proxy Services           🔐 Authentication          │
│  ┌─────────┐ ┌─────────┐    ┌─────────┐                │
│  │   NPM   │ │  SSL    │    │Authentik│                │
│  │ Status● │ │ Certs   │    │  Users  │                │
│  └─────────┘ └─────────┘    └─────────┘                │
│                                                         │
│  🖥️ Infrastructure          📊 Monitoring               │
│  ┌─────────┐ ┌─────────┐    ┌─────────┐                │
│  │ Nebula  │ │ Spokes  │    │Portainer│                │
│  │  VPN    │ │ Status  │    │ Docker  │                │
│  └─────────┘ └─────────┘    └─────────┘                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Features
- Quick links to all services
- Status indicators (online/offline)
- Organized by category
- Customizable theme
- Works behind Authentik

See [homer/](./homer/) for setup.

---

## Option 2: Portainer (Full Docker Management)

Manage Docker containers across ALL hosts (hub + spokes) from one UI.

```
┌─────────────────────────────────────────────────────────┐
│  🐳 Portainer - Multi-Host Docker Management            │
├─────────────────────────────────────────────────────────┤
│  Environment: Hub (localhost) ◀────────── active        │
│  Environment: Spoke-1 (10.8.0.2) ◀─────── connected     │
│  Environment: Spoke-2 (10.8.0.3) ◀─────── connected     │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Containers (across all hosts)                    │    │
│  │ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐    │    │
│  │ │  npm   │ │authentik│ │ whoami │ │ webapp │    │    │
│  │ │  🟢    │ │   🟢   │ │   🟢   │ │   🟢   │    │    │
│  │ │ Hub    │ │  Hub   │ │ Spoke1 │ │ Spoke2 │    │    │
│  │ └────────┘ └────────┘ └────────┘ └────────┘    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### Features
- Start/stop containers on any host
- View logs from remote containers
- Deploy stacks across the infrastructure
- Monitor resource usage
- Access container consoles

See [portainer/](./portainer/) for setup.

---

## Option 3: Custom Status Panel (Lightweight)

A minimal, custom-built panel showing:
- VPN connection status
- Spoke host health
- Service endpoints
- Quick action buttons

See [custom/](./custom/) for setup.

---

## Recommendation

| Use Case | Recommended Panel |
|----------|-------------------|
| Just need quick links | **Homer** |
| Manage containers remotely | **Portainer** |
| Minimal resource usage | **Custom** |
| Full infrastructure view | **Portainer + Homer** |

## Integration with Authentik

All panels can be protected behind Authentik:

1. Create a "Control Panel" application in Authentik
2. Point it to your panel URL
3. Only authenticated users can access the dashboard
4. Different groups can see different links (with Homer groups)
