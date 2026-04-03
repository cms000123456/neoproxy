# NPM Configuration Examples

This document shows how to configure various applications in NPM with Authentik authentication.

## 1. Basic Protected App (Whoami)

A simple test to verify auth is working.

### Docker Compose (add to your apps)
```yaml
services:
  whoami:
    image: traefik/whoami:latest
    networks:
      - proxy-network
```

### NPM Configuration

**Details Tab:**
- Domain Names: `whoami.yourdomain.com`
- Scheme: `http`
- Forward Hostname/IP: `whoami`
- Forward Port: `80`

**SSL Tab:**
- SSL Certificate: Request a new SSL certificate
- ☑️ Force SSL
- ☑️ HTTP/2 Support

**Advanced Tab:**
Paste the content of `../data/npm/custom_locations/authentik_forward.conf`

---

## 2. Jellyfin with Header Auth

### Jellyfin Configuration

In Jellyfin admin panel:
1. Go to **Dashboard > Plugins > Catalog**
2. Install **Auto Organize** (optional) and restart
3. Go to **Dashboard > Advanced > Networking**
4. Under **Known Proxies**, add NPM's IP

Or edit `system.xml`:
```xml
<KnownProxies>
  <string>npm</string>
</KnownProxies>
```

### NPM Configuration

**Details Tab:**
- Domain Names: `jellyfin.yourdomain.com`
- Forward Hostname/IP: `jellyfin`
- Forward Port: `8096`

**Advanced Tab:**
```nginx
# Authentik Forward Auth
set $authentik_url http://authentik-server:9000;
auth_request /outpost.goauthentik.io/auth/nginx;
error_page 401 = @authentik_login;

auth_request_set $auth_user $upstream_http_x_authentik_username;
auth_request_set $auth_email $upstream_http_x_authentik_email;

proxy_set_header X-authentik-username $auth_user;
proxy_set_header X-authentik-email $auth_email;

# Jellyfin-specific headers
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header Host $http_host;

# WebSocket support (for Jellyfin)
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

location /outpost.goauthentik.io/auth/nginx {
    internal;
    proxy_pass $authentik_url/outpost.goauthentik.io/auth/nginx;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
    proxy_set_header X-Original-Method $request_method;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP $remote_addr;
}

location @authentik_login {
    internal;
    return 302 $authentik_url/outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
}

location /outpost.goauthentik.io {
    proxy_pass $authentik_url/outpost.goauthentik.io;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

---

## 3. Nextcloud with OIDC

Nextcloud supports native OIDC authentication.

### Install OIDC App in Nextcloud

```bash
docker compose exec -u www-data nextcloud php occ app:user_oidc
```

### Authentik Configuration

1. In Authentik, go to **Applications > Providers > Create**
2. Select **OAuth2/OpenID Provider**
3. Configure:
   - **Name**: Nextcloud OIDC
   - **Client ID**: (copy this)
   - **Client Secret**: Generate and copy
   - **Redirect URIs**: `https://nextcloud.yourdomain.com/apps/user_oidc/code`

### NPM Configuration

**Details Tab:**
- Domain Names: `nextcloud.yourdomain.com`
- Forward Hostname/IP: `nextcloud`
- Forward Port: `80`

**Advanced Tab:**
For Nextcloud with OIDC, you may not need forward auth (OIDC handles it), but you can add it for extra protection:

```nginx
# Increase timeouts for file uploads
proxy_read_timeout 300;
proxy_connect_timeout 300;
proxy_send_timeout 300;

# Required for WebDAV
client_max_body_size 10G;

# Headers
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

---

## 4. Grafana with Auth Proxy

### Grafana Configuration

Edit `grafana.ini` or set environment variables:

```ini
[auth.proxy]
enabled = true
header_name = X-authentik-username
header_property = username
auto_sign_up = true
sync_ttl = 60
whitelist = npm,authentik-server,192.168.0.0/16,10.0.0.0/8
headers = Name:X-authentik-name|Email:X-authentik-email|Groups:X-authentik-groups
enable_login_token = false
```

Or environment variables:
```yaml
environment:
  - GF_AUTH_PROXY_ENABLED=true
  - GF_AUTH_PROXY_HEADER_NAME=X-authentik-username
  - GF_AUTH_PROXY_HEADER_PROPERTY=username
  - GF_AUTH_PROXY_AUTO_SIGN_UP=true
  - GF_AUTH_PROXY_WHITELIST=npm,authentik-server
```

### NPM Configuration

**Details Tab:**
- Domain Names: `grafana.yourdomain.com`
- Forward Hostname/IP: `grafana`
- Forward Port: `3000`

**Advanced Tab:**
```nginx
set $authentik_url http://authentik-server:9000;
auth_request /outpost.goauthentik.io/auth/nginx;
error_page 401 = @authentik_login;

auth_request_set $auth_user $upstream_http_x_authentik_username;
auth_request_set $auth_email $upstream_http_x_authentik_email;
auth_request_set $auth_name $upstream_http_x_authentik_name;

proxy_set_header X-authentik-username $auth_user;
proxy_set_header X-authentik-email $auth_email;
proxy_set_header X-authentik-name $auth_name;

# WebSocket for live dashboards
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

location /outpost.goauthentik.io/auth/nginx {
    internal;
    proxy_pass $authentik_url/outpost.goauthentik.io/auth/nginx;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
    proxy_set_header X-Original-Method $request_method;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

location @authentik_login {
    internal;
    return 302 $authentik_url/outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
}
```

---

## 5. Portainer with Team Mapping

### Portainer Configuration

No special config needed - Portainer can use headers or built-in auth.

### NPM Configuration

**Details Tab:**
- Domain Names: `portainer.yourdomain.com`
- Forward Hostname/IP: `portainer`
- Forward Port: `9000`

**Advanced Tab:**
```nginx
# Disable auth for Portainer API (optional)
set $authentik_url http://authentik-server:9000;

# Skip auth for API endpoints
location /api/ {
    proxy_pass http://portainer:9000/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}

# Auth for everything else
location / {
    auth_request /outpost.goauthentik.io/auth/nginx;
    error_page 401 = @authentik_login;
    
    proxy_pass http://portainer:9000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
}

location /outpost.goauthentik.io/auth/nginx {
    internal;
    proxy_pass $authentik_url/outpost.goauthentik.io/auth/nginx;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
}

location @authentik_login {
    internal;
    return 302 $authentik_url/outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
}
```

---

## Tips

### Debugging Headers

Use the `whoami` app to see what headers are passed:
```bash
curl -H "Host: whoami.yourdomain.com" http://localhost
```

Look for:
- `X-authentik-username`
- `X-authentik-email`
- `X-authentik-groups`

### Common Issues

1. **502 Bad Gateway**: App container not on `proxy-network`
2. **Redirect loop**: Check external URL uses HTTPS
3. **No headers**: Ensure `auth_request_set` is before `proxy_set_header`
4. **Auth not triggered**: Check location blocks don't override auth

### Testing Auth Flow

```bash
# 1. Test without cookies (should redirect)
curl -I https://app.yourdomain.com

# 2. Check authentik outpost is responding
docker compose exec npm wget -qO- http://authentik-server:9000/outpost.goauthentik.io/ping
```
