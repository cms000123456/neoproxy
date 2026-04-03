# Authentik Configuration Guide

This guide walks you through configuring Authentik for use with Nginx Proxy Manager.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Creating a Proxy Provider](#creating-a-proxy-provider)
3. [Setting Up MFA](#setting-up-mfa)
4. [Configuring NPM](#configuring-npm)
5. [Advanced Configuration](#advanced-configuration)

---

## Initial Setup

### 1. First Login

After starting services:

1. Navigate to `http://localhost:9000` (or your configured auth domain)
2. Click "Create Account" to create the admin user
3. Complete the wizard with your admin details

### 2. System Configuration

Go to **Admin Interface > System > Brands**

Edit the default brand:
- **Title**: Your Organization Name
- **Domain**: Your auth domain (e.g., `auth.yourdomain.com`)
- **Web Certificate**: Select or upload SSL certificate
- **Default**: Checked

Save changes.

---

## Creating a Proxy Provider

### 1. Create the Provider

Navigate to **Applications > Providers > Create**

Select **Proxy Provider**

**General Settings:**
- **Name**: `NPM Forward Auth`
- **Authorization flow**: `default-provider-authorization-implicit-consent` (or explicit if you want consent screen)

**Protocol Settings:**
- **Internal host**: URL accessible from NPM (e.g., `http://authentik-server:9000`)
- **External host**: Public URL (e.g., `https://auth.yourdomain.com`)
- **Skip path regex**: Paths that bypass auth (e.g., health checks)

### 2. Create the Application

Navigate to **Applications > Applications > Create**

- **Name**: `Protected Apps`
- **Slug**: `protected-apps`
- **Provider**: Select `NPM Forward Auth`
- **Policy engine mode**: `ANY` (any policy must match) or `ALL` (all policies must match)

### 3. Create an Outpost

Navigate to **Applications > Outposts > Create**

- **Name**: `npm-outpost`
- **Type**: `Proxy`
- **Providers**: Select `NPM Forward Auth`
- **Integration**: `docker-compose` (or `local` if on same host)

**Note**: When using docker-compose, the outpost runs within the Authentik server container automatically.

---

## Setting Up MFA

### Enable MFA Globally

1. Go to **Flows & Stages**
2. Find `default-authentication-flow`
3. Click **Stage Bindings**
4. Add a new binding:
   - **Stage**: Create or select `default-authenticator-validation`
   - **Order**: After password stage (e.g., 20)
   - **Enabled**: Checked

### Available MFA Methods

Users can configure MFA in their **Settings > MFA** page:

| Method | Description | Setup |
|--------|-------------|-------|
| TOTP | Time-based codes (Google Auth, Authy) | Scan QR code |
| WebAuthn | Hardware keys (YubiKey, Touch ID) | Register device |
| SMS | Text message codes | Configure Twilio first |
| Email OTP | Email-based codes | Configure SMTP first |
| Static Tokens | Backup codes | Generate and save |

### Enforcing MFA

To require MFA for specific applications:

1. Go to **Applications > Applications**
2. Edit your application
3. Go to **Policy / Group / User Bindings**
4. Add a policy:
   - **Type**: Expression Policy
   - **Expression**: `return request.user.ak_groups.filter(name="mfa-enforced").exists()`

Or use the built-in `require_mfa` policy if available.

---

## Configuring NPM

### Step 1: Create Proxy Host

In Nginx Proxy Manager:

1. Go to **Hosts > Proxy Hosts > Add**
2. **Domain Names**: `app.yourdomain.com`
3. **Scheme**: `http` (or `https`)
4. **Forward Hostname/IP**: Your app container/service name
5. **Forward Port**: Your app port
6. Enable **Block Common Exploits**
7. Save

### Step 2: Add SSL

1. Edit the proxy host
2. Go to **SSL** tab
3. Select your certificate (or request Let's Encrypt)
4. Enable:
   - ☑️ Force SSL
   - ☑️ HTTP/2 Support
   - ☑️ HSTS Enabled
5. Save

### Step 3: Add Authentication

1. Edit the proxy host
2. Go to **Advanced** tab
3. Paste the content from:
   ```bash
   cat data/npm/custom_locations/authentik_forward.conf
   ```
4. Save

### Testing

1. Visit `https://app.yourdomain.com`
2. Should redirect to Authentik login
3. After login, redirects back to app
4. App receives authentication headers

---

## Advanced Configuration

### Conditional Authentication

Bypass auth for specific IPs:

```nginx
# In NPM Advanced tab
set $authentik_url http://authentik-server:9000;

# Skip auth for local network
if ($remote_addr ~ ^(192\.168\.1\.|10\.0\.0\.)) {
    set $auth_skip 1;
}

error_page 401 = @authentik_login;
auth_request /outpost.goauthentik.io/auth/nginx;
auth_request_set $auth_user $upstream_http_x_authentik_username;

proxy_set_header X-authentik-username $auth_user;

location /outpost.goauthentik.io/auth/nginx {
    internal;
    if ($auth_skip) {
        return 200;
    }
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

### Group-Based Access

Restrict access by Authentik groups:

1. In Authentik, go to **Applications > Applications**
2. Edit your application
3. Go to **Policy Bindings**
4. Add policy:
   - **Type**: Group Membership Policy
   - **Group**: Select allowed group
   - **Action**: `positive_result` (allow) or `negative_result` (deny)

### Header-Based Auth for Apps

Many apps support header authentication:

**Example - Grafana:**
```ini
[auth.proxy]
enabled = true
header_name = X-authentik-username
header_property = username
auto_sign_up = true
```

**Example - Jellyfin:**
```xml
<PluginConfiguration>
  <EnableAuthentication>true</EnableAuthentication>
  <AuthHeaderName>X-authentik-username</AuthHeaderName>
</PluginConfiguration>
```

### Multiple Applications

Create separate providers for different apps:

1. **Public Apps** - No authentication
2. **Internal Apps** - Basic auth
3. **Sensitive Apps** - MFA required + strict mode

### Logging & Monitoring

View auth logs in Authentik:
- **Events > Logs** - All authentication events
- **System > Tasks** - Background task status

Enable verbose logging:
```yaml
# In docker-compose.yml
environment:
  AUTHENTIK_LOG_LEVEL: debug
```

---

## Troubleshooting

### "Authentication failed" errors

1. Check Authentik outpost is running: `docker compose logs authentik-server`
2. Verify provider URL matches external host
3. Check browser console for CORS errors

### Infinite redirect loop

1. Ensure external host URL uses HTTPS
2. Check NPM SSL configuration
3. Verify `X-Forwarded-Proto` header is set

### MFA not working

1. Check user's MFA devices in admin: **Directory > Users > [user] > MFA**
2. Verify MFA stage is bound to authentication flow
3. Check if TOTP time is synchronized

### Headers not reaching app

1. Ensure auth_request_set variables are set
2. Verify proxy_set_header lines are present
3. Check app container can see headers: `docker compose exec app env`

---

## Next Steps

- Configure [email for notifications](./README.md#email-configuration)
- Set up [LDAP integration](./README.md#ldap-integration) for network devices
- Explore [Authentik Blueprints](https://docs.goauthentik.io/developer-docs/blueprints/) for infrastructure-as-code
