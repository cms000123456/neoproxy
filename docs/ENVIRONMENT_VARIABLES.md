# Environment Variables

Complete reference of all configuration options for NeoProxy.

## Core Variables (`.env`)

### Authentik Database

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `PG_PASS` | *generated* | PostgreSQL password | ✅ Yes |
| `PG_USER` | authentik | PostgreSQL username | No |
| `PG_DB` | authentik | PostgreSQL database name | No |

**Example:**
```bash
PG_PASS=your_secure_random_password_32_chars
PG_USER=authentik
PG_DB=authentik
```

### Authentik Security

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `AUTHENTIK_SECRET_KEY` | *generated* | Signing key for tokens (min 50 chars) | ✅ Yes |

**Security Note:** This key signs all Authentik tokens. If compromised, regenerate and restart all Authentik containers.

**Generate:**
```bash
openssl rand -base64 60 | tr -d "=+/" | cut -c1-50
```

### Hub Configuration (Inter-Host)

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `HUB_PUBLIC_IP` | *auto-detected* | Public IP for spoke connections | For Hub only |

**Auto-detection:** Uses `ifconfig.me` if available, falls back to manual entry.

### Email (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `SMTP_HOST` | - | SMTP server hostname |
| `SMTP_PORT` | 587 | SMTP port |
| `SMTP_USERNAME` | - | SMTP username |
| `SMTP_PASSWORD` | - | SMTP password or app token |
| `SMTP_USE_TLS` | true | Enable TLS |
| `SMTP_USE_SSL` | false | Enable SSL |
| `DEFAULT_FROM_EMAIL` | - | From address for emails |

**Example (Gmail):**
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=you@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_USE_TLS=true
DEFAULT_FROM_EMAIL=noreply@yourdomain.com
```

## HA Setup Variables (`ha-setup/.env`)

### Controller Identity

| Variable | Options | Description | Required |
|----------|---------|-------------|----------|
| `CONTROLLER_ROLE` | master, backup | Role in HA cluster | ✅ Yes |
| `ROUTER_ID` | 1-255 | Unique VRRP router ID | ✅ Yes |
| `PRIORITY` | 1-255 | VRRP priority (higher = preferred) | ✅ Yes |

**Priority Guidelines:**
- MASTER: 100
- First BACKUP: 90
- Second BACKUP: 80

### Network

| Variable | Default | Description |
|----------|---------|-------------|
| `INTERFACE` | eth0 | Network interface for VRRP |
| `VIRTUAL_IP` | - | Floating IP address |
| `VIRTUAL_IP_NETMASK` | 24 | Netmask for floating IP |

### Storage

| Variable | Default | Description |
|----------|---------|-------------|
| `SHARED_DATA_PATH` | ./data | Path to shared storage |
| `GLUSTER_VOLUME` | neoproxy-data | GlusterFS volume name |
| `GLUSTER_CONTROLLERS` | - | Comma-separated controller IPs |

## Docker Compose Variables

### NPM Service

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_SQLITE_FILE` | /data/database.sqlite | SQLite database path |
| `DISABLE_IPV6` | true | Disable IPv6 support |

### Authentik Server

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTHENTIK_REDIS__HOST` | redis | Redis hostname |
| `AUTHENTIK_POSTGRESQL__HOST` | postgresql | PostgreSQL hostname |
| `AUTHENTIK_POSTGRESQL__USER` | authentik | DB username |
| `AUTHENTIK_POSTGRESQL__NAME` | authentik | DB name |
| `AUTHENTIK_POSTGRESQL__PASSWORD` | - | DB password |
| `AUTHENTIK_SECRET_KEY` | - | Signing key |
| `AUTHENTIK_ERROR_REPORTING__ENABLED` | false | Send error reports |
| `AUTHENTIK_AVATARS` | initials | Avatar type (initials, gravatar, none) |
| `AUTHENTIK_LOG_LEVEL` | info | Log level (debug, info, warning, error) |

### Nebula (VPN)

| Variable | Default | Description |
|----------|---------|-------------|
| `TS_AUTHKEY` | - | Tailscale auth key (if using Tailscale) |

## Complete Example `.env`

```bash
# ============================================================================
# NeoProxy Configuration
# ============================================================================

# Authentik Database
PG_PASS=xK9#mP2$vL5@nQ8&wR4!cF7*
PG_USER=authentik
PG_DB=authentik

# Authentik Security (KEEP SECRET!)
AUTHENTIK_SECRET_KEY=AbCdEfGhIjKlMnOpQrStUvWxYz1234567890AbCdEfGhIjKlMn

# Hub Configuration (only for hub mode)
HUB_PUBLIC_IP=203.0.113.10

# Email Configuration (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=admin@yourdomain.com
SMTP_PASSWORD=app_specific_password
SMTP_USE_TLS=true
DEFAULT_FROM_EMAIL=noreply@yourdomain.com
```

## HA Setup Example `.env`

```bash
# ============================================================================
# HA Controller Configuration
# ============================================================================

# Controller Role
CONTROLLER_ROLE=master
ROUTER_ID=51
PRIORITY=100

# Network
INTERFACE=eth0
VIRTUAL_IP=203.0.113.10
VIRTUAL_IP_NETMASK=24

# Storage
SHARED_DATA_PATH=/mnt/neoproxy-data
GLUSTER_VOLUME=neoproxy-data
GLUSTER_CONTROLLERS=192.168.1.10,192.168.1.11,192.168.1.12

# Authentik (SAME ON ALL CONTROLLERS!)
PG_PASS=same_secure_password_on_all
AUTHENTIK_SECRET_KEY=same_50_char_key_on_all_controllers

# Notifications
SLACK_WEBHOOK=https://hooks.slack.com/services/xxx
NOTIFICATION_EMAIL=admin@yourdomain.com
```

## Variable Precedence

1. **Environment variables** (highest priority)
2. **`.env` file** (loaded by docker compose)
3. **Default values** in docker-compose.yml (lowest priority)

## Security Best Practices

1. **Keep `.env` file secure:**
   ```bash
   chmod 600 .env
   ```

2. **Never commit `.env`:**
   Already in `.gitignore`

3. **Rotate secrets regularly:**
   ```bash
   # Generate new secret
   openssl rand -base64 60 | tr -d "=+/" | cut -c1-50
   
   # Update .env
   # Restart services
   docker compose up -d
   ```

4. **Use different secrets per environment:**
   - Production: Strong random secrets
   - Staging: Different from production
   - Development: Can be simpler

## Troubleshooting Variables

### Check loaded variables

```bash
# View all environment variables
docker compose exec npm env

# Check specific variable
docker compose exec npm printenv AUTHENTIK_SECRET_KEY
```

### Debug mode

```bash
# Enable debug logging
export AUTHENTIK_LOG_LEVEL=debug
docker compose up -d
```
