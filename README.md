# NeoProxy - Nginx Proxy Manager with Authentik SSO/MFA

A complete reverse proxy solution with authentication and multi-factor authentication (MFA) support using Nginx Proxy Manager and Authentik.

## Features

- 🚀 **Nginx Proxy Manager** - Easy-to-use web UI for reverse proxy management
- 🔐 **Authentik Identity Provider** - Enterprise-grade authentication & authorization
- 🔢 **Multi-Factor Authentication** - TOTP, WebAuthn, SMS, and more
- 📱 **User Portal** - Centralized application dashboard for users
- 📝 **Application Proxy** - Protect any app behind SSO
- 🔄 **Automatic SSL** - Let's Encrypt integration
- 👥 **Group/Role Management** - Granular access control

## Architecture

```
┌─────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   Client    │─────▶│  Nginx Proxy    │─────▶│  Authentik      │
│             │      │  Manager (NPM)  │      │  (Auth Portal)  │
└─────────────┘      └─────────────────┘      └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  Protected      │
                       │  Applications   │
                       └─────────────────┘
```

## Quick Start

### 1. Prerequisites

- Docker & Docker Compose installed
- Ports 80, 443, and 81 available
- A domain name (for production)

### 2. Initial Setup

```bash
# Clone/setup this directory
cd neoproxy

# Generate secure secrets
./setup.sh

# Or manually update .env file with secure values:
# - PG_PASS: PostgreSQL password
# - AUTHENTIK_SECRET_KEY: 50+ character random string
```

### 3. Start Services

```bash
docker compose up -d
```

### 4. Initial Configuration

1. **Access NPM Admin**: http://localhost:81
   - Default login: `admin@example.com` / `changeme`
   - Change password immediately

2. **Access Authentik**: http://localhost:9000 (or via NPM proxy)
   - First-time setup: create admin account
   - Configure your domain in System > Brands

### 5. Configure Authentik Provider

1. In Authentik Admin, go to **Applications > Providers**
2. Create a **Proxy Provider**
   - Name: `NPM Forward Auth`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Internal host: `http://npm:81`
   - External host: `https://apps.yourdomain.com`

3. Create an **Application**
   - Name: `Protected Apps`
   - Provider: Select the one you just created

### 6. Configure NPM Proxy Host with Auth

1. In NPM, create a Proxy Host:
   - Domain Names: `app.yourdomain.com`
   - Forward Hostname/IP: `your-backend-app`
   - Forward Port: `8080` (or app port)
   - Enable SSL (Let's Encrypt)

2. In the **Advanced** tab, paste the content from:
   ```
   ./data/npm/custom_locations/authentik_forward.conf
   ```

3. Save and test

## MFA Configuration

### Available MFA Methods

1. **TOTP (Time-based One-Time Password)**
   - Google Authenticator, Authy, Bitwarden, etc.
   
2. **WebAuthn/FIDO2**
   - YubiKey, Touch ID, Windows Hello
   
3. **SMS (via Twilio)**
   - Requires Twilio configuration

4. **Email OTP**
   - Requires email provider setup

### Enabling MFA

1. User logs into Authentik
2. Go to **Settings > MFA**
3. Add authenticator method
4. Follow setup wizard

### Enforcing MFA (Recommended)

1. In Authentik, go to **Flows & Stages**
2. Edit the `default-authentication-flow`
3. Add a **Authenticator Validation Stage**
4. Configure device classes required

## Protecting Applications

### Method 1: Forward Auth (Recommended)

Applications authenticate through Authentik transparently. Users see:
1. Access app URL
2. Redirect to Authentik login if not authenticated
3. MFA prompt (if configured)
4. Redirect back to app (now logged in)

### Method 2: Proxy Provider with Outpost

For applications supporting headers:
```nginx
# Headers passed to backend:
X-authentik-username: john.doe
X-authentik-email: john@example.com
X-authentik-groups: admins,users
X-authentik-uid: abc123
```

### Method 3: OAuth/OIDC

For apps with native SSO support:
- Configure Authentik as OIDC provider
- Use standard OAuth2/OIDC flow

## Configuration Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | All services configuration |
| `.env` | Environment variables (secrets) |
| `data/npm/custom_locations/authentik_forward.conf` | Standard auth forwarding |
| `data/npm/custom_locations/authentik_forward_strict.conf` | Enhanced security mode |

## Security Best Practices

1. **Change Default Passwords** - Immediately after first login
2. **Use Strong Secrets** - Run `./setup.sh` to generate
3. **Enable MFA for Admin** - Protect your admin accounts
4. **Use Strict Mode** - For sensitive applications
5. **Regular Updates** - Keep images updated
6. **Backup Data** - Regular backups of `./data`
7. **Use HTTPS** - Always use SSL in production

## Backup & Restore

### Backup

```bash
# Stop services
docker compose down

# Backup data directory
tar -czvf neoproxy-backup-$(date +%Y%m%d).tar.gz ./data

# Restart
docker compose up -d
```

### Restore

```bash
# Stop services
docker compose down

# Restore data
rm -rf ./data
tar -xzvf neoproxy-backup-20240101.tar.gz

# Restart
docker compose up -d
```

## Troubleshooting

### Authentik not accessible

```bash
# Check logs
docker compose logs -f authentik-server

# Verify database connection
docker compose exec authentik-server ak healthcheck
```

### Auth forwarding not working

1. Check Authentik outpost is running
2. Verify NPM can reach Authentik: `docker compose exec npm ping authentik-server`
3. Check custom location configuration
4. Verify Provider URL matches external host

### SSL certificate issues

1. Ensure port 80 is publicly accessible
2. Check DNS A record points to server
3. Verify in NPM: `SSL Certificates > Add`

## Advanced Configuration

### Custom Branding

Edit `./data/authentik/custom-templates/` and mount to container.

### LDAP Integration

Uncomment the `authentik-ldap` service in `docker-compose.yml`.

### Radius Support

Add the Radius outpost service for network device authentication.

### Email Configuration

Edit `.env` with SMTP settings for password resets and notifications.

## Ports Reference

| Port | Service | Description |
|------|---------|-------------|
| 80 | NPM | HTTP traffic |
| 443 | NPM | HTTPS traffic |
| 81 | NPM | Admin UI |
| 9000 | Authentik | Auth server (internal) |

## Hub-and-Spoke Multi-Host Architecture

For proxying containers across multiple Docker hosts securely:

```
┌─────────────────────────────────────────────────────────────┐
│                         HUB (Main Host)                      │
│  ┌─────────┐    ┌──────────┐    ┌──────────────────────┐   │
│  │   NPM   │◄──►│Authentik │◄──►│  Nebula Lighthouse   │   │
│  │(Public) │    │   (MFA)  │    │     (VPN)            │   │
│  └────┬────┘    └──────────┘    └──────────┬───────────┘   │
│       │                                     │                │
│       └─────────────────────────────────────┘                │
│                         │                                   │
└─────────────────────────┼───────────────────────────────────┘
                          │ VPN Tunnels (encrypted)
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   Spoke Host 1  │ │   Spoke Host 2  │ │   Spoke Host 3  │
│ 172.20.0.0/16   │ │ 172.21.0.0/16   │ │ 172.22.0.0/16   │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │
│ │  Container A│ │ │ │  Container A│ │ │ │  Container A│ │
│ │   :8080     │ │ │ │   :8080     │ │ │ │   :8080     │ │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │
│ │  Container B│ │ │ │  Container B│ │ │ │  Container B│ │
│ │   :5432     │ │ │ │   :5432     │ │ │ │   :5432     │ │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │
└─────────────────┘ └─────────────────┘ └─────────────────┘
     No ports exposed!    No ports exposed!    No ports exposed!
```

**Features:**
- Each spoke has isolated Docker networks
- Same ports can be used on every host (8080, 5432, etc.)
- No public exposure - containers accessible only via VPN
- NPM on hub proxies to container IPs through encrypted tunnels

See [`hub-spoke/`](./hub-spoke/) directory for complete setup.

## Resources

- [Nginx Proxy Manager Docs](https://nginxproxymanager.com/guide/)
- [Authentik Documentation](https://docs.goauthentik.io/)
- [Authentik GitHub](https://github.com/goauthentik/authentik)

## License

This configuration is provided as-is for your own infrastructure setup.
