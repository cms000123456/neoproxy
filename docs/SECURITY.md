# Security Hardening Guide

Best practices for securing your NeoProxy installation.

## Network Security

### Firewall Rules

Minimal required ports:

```bash
# UFW - Strict rules
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (restrict to your IP!)
sudo ufw allow from YOUR_IP to any port 22

# Allow web traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow NPM admin (restrict to your IP!)
sudo ufw allow from YOUR_IP to any port 81

# Allow VPN (hub only, restrict to spoke IPs if possible)
sudo ufw allow 4242/udp

# Enable
sudo ufw enable
```

### Fail2Ban

Protect against brute force:

```bash
sudo apt-get install -y fail2ban

# Create jail for NPM
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[npm]
enabled = true
port = http,https,81
filter = npm
logpath = /var/lib/docker/containers/*/*-json.log
maxretry = 5
EOF

# Create filter
mkdir -p /etc/fail2ban/filter.d
cat > /etc/fail2ban/filter.d/npm.conf << 'EOF'
[Definition]
failregex = ^.*"Bad password".client_ip": "<HOST>".*$
            ^.*"Invalid credentials".client_ip": "<HOST>".*$
ignoreregex =
EOF

sudo systemctl restart fail2ban
```

## NPM Security

### Change Default Password

Immediately after first login:

1. Login to NPM: `http://your-server:81`
2. Default: `admin@example.com` / `changeme`
3. Go to **Users > Edit > Change Password**
4. Use strong password (16+ chars)

### Disable Default User

Create new admin user, then disable default:

1. **Users > Add User**
   - Email: your-email@domain.com
   - Name: Your Name
   - Roles: Administrator
2. **Logout**, login with new user
3. **Users > Edit admin@example.com > Disabled**

### Enable Access Lists

Restrict NPM admin to specific IPs:

1. **Access Lists > Add Access List**
   - Name: Admin Only
   - Satisfy: All
   - Add Rule:
     - Action: Allow
     - Address: YOUR_IP/32
2. **Proxy Hosts > Edit NPM Admin Host**
   - Access List: Admin Only

### Force HTTPS

For all proxy hosts:

1. **Edit Proxy Host > SSL**
2. Enable:
   - ☑️ Force SSL
   - ☑️ HTTP/2 Support
   - ☑️ HSTS Enabled
   - ☑️ HSTS Subdomains

## Authentik Security

### Strong Admin Password

1. First login: Create strong admin password
2. **Settings > Change Password**

### Enable MFA for Admin

1. **Settings > MFA**
2. Add authenticator (TOTP or WebAuthn)
3. Store backup codes securely

### Enforce MFA for All Users

1. **Flows & Stages > default-authentication-flow**
2. Add **Authenticator Validation Stage**
3. Set as required

### Session Security

1. **System > Brands > Edit**
2. **Settings:**
   - Session length: 8 hours (or less)
   - Remember me: Disabled for admins

### Audit Logging

Enable comprehensive logging:

```yaml
# In docker-compose.yml
environment:
  AUTHENTIK_LOG_LEVEL: info
  AUTHENTIK_EVENTS__CONTEXTUAL: "true"
```

Review logs regularly:
- **Events > Logs** - Authentication attempts
- **Admin > System Tasks** - Background tasks

## Docker Security

### Run as Non-Root

```yaml
# Add to services
services:
  npm:
    user: "1000:1000"
  authentik-server:
    user: "1000:1000"
```

### Limit Resources

```yaml
services:
  npm:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

### Read-Only Filesystems

```yaml
services:
  npm:
    read_only: true
    tmpfs:
      - /tmp
      - /var/cache/nginx
```

## VPN Security (Hub-Spoke)

### Certificate Management

1. **Protect CA key:**
   ```bash
   chmod 600 nebula/ca.key
   chown root:root nebula/ca.key
   ```

2. **Regular rotation:**
   ```bash
   # Rotate spoke certs every 90 days
   ./generate-spoke.sh spoke1 172.20.0.0/16 10.8.0.2
   # Deploy and restart
   ```

3. **Revoke compromised certs:**
   ```bash
   # Add to CRL
   ./nebula/nebula-cert sign -revoke spoke1
   ```

### Firewall VPN Traffic

Restrict spoke access:

```yaml
# In nebula config
firewall:
  inbound:
    # Only allow hub to initiate connections
    - port: any
      proto: any
      groups:
        - hub
```

## SSL/TLS Best Practices

### Certificate Options

Priority (best to acceptable):

1. **Let's Encrypt** - Free, automated, trusted
2. **Commercial CA** - Warranty, support
3. **Private CA** - Internal use only

### Never Use

- ❌ Self-signed certificates in production
- ❌ Wildcard certs without proper management
- ❌ Expired certificates

### HSTS Preloading

For maximum security:

1. Enable HSTS in NPM for all hosts
2. After 6 months, submit to HSTS preload list:
   https://hstspreload.org/

## Secrets Management

### Environment Variables

```bash
# Set secure permissions
chmod 600 .env
chown root:root .env

# Never commit to git
echo ".env" >> .gitignore
```

### Docker Secrets (Swarm mode)

```yaml
# For Docker Swarm
secrets:
  db_password:
    external: true

services:
  authentik-server:
    secrets:
      - source: db_password
        target: /run/secrets/db_password
```

### HashiCorp Vault

For enterprise deployments, integrate with Vault:

```yaml
environment:
  AUTHENTIK_SECRET_KEY_FILE: /run/secrets/authentik_secret
```

## Monitoring & Alerting

### Log Aggregation

Forward logs to central system:

```yaml
logging:
  driver: fluentd
  options:
    fluentd-address: localhost:24224
    tag: neoproxy
```

### Security Alerts

Monitor for:
- Failed login attempts
- Certificate expirations
- Unusual traffic patterns
- VPN connection anomalies

### Automated Scanning

```bash
# Daily security scan with Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image jc21/nginx-proxy-manager:latest
```

## Updates & Patching

### Automated Updates

```bash
# Watchtower for automated updates
docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --cleanup \
  --schedule "0 0 4 * * *"  # Daily at 4 AM
```

### Manual Update Process

1. **Backup first:**
   ```bash
   ./backup.sh
   ```

2. **Check changelog:**
   - NPM: https://github.com/NginxProxyManager/nginx-proxy-manager/releases
   - Authentik: https://goauthentik.io/docs/releases

3. **Update:**
   ```bash
   docker compose pull
   docker compose up -d
   ```

4. **Verify:**
   ```bash
   docker compose ps
   docker compose logs --tail=50
   ```

## Security Checklist

- [ ] Firewall enabled with minimal rules
- [ ] Fail2Ban installed and configured
- [ ] Default NPM password changed
- [ ] Default NPM user disabled
- [ ] NPM admin restricted by IP
- [ ] HTTPS forced on all hosts
- [ ] HSTS enabled
- [ ] Authentik MFA enabled for admin
- [ ] Authentik MFA enforced for users
- [ ] Session timeouts configured
- [ ] Docker running as non-root (where possible)
- [ ] Resource limits set
- [ ] VPN certificates protected
- [ ] VPN certificate rotation scheduled
- [ ] Secrets in .env with 600 permissions
- [ ] .env in .gitignore
- [ ] Automated backups configured
- [ ] Log monitoring enabled
- [ ] Update process documented
- [ ] Security scan scheduled
