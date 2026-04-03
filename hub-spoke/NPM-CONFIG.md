# NPM Configuration for Hub-Spoke Architecture

## How It Works

1. NPM runs on the **Hub** host
2. Remote **Spoke** hosts connect via Nebula VPN
3. Each spoke has isolated Docker networks (172.20.x.x, 172.21.x.x, etc.)
4. NPM can reach container IPs through the VPN tunnel
5. **No ports exposed** on remote hosts - everything through VPN

## Container IP Reference

When you start containers on a spoke, they get IPs in order:

```
Spoke 1 (172.20.0.0/16):
  Gateway:    172.20.0.1
  Container1: 172.20.0.2  <- First app
  Container2: 172.20.0.3  <- Second app
  Container3: 172.20.0.4

Spoke 2 (172.21.0.0/16):
  Gateway:    172.21.0.1
  Container1: 172.21.0.2  <- First app (same port, different IP!)
  Container2: 172.21.0.3  <- Second app

Spoke 3 (172.22.0.0/16):
  Container1: 172.22.0.2  <- First app (same port again!)
```

## NPM Proxy Host Configuration

### Example 1: Same App on Multiple Hosts

Both Host 1 and Host 2 run nginx on port 80:

**Proxy Host 1:**
| Setting | Value |
|---------|-------|
| Domain Names | `site1.yourdomain.com` |
| Scheme | `http` |
| Forward Hostname/IP | `172.20.0.2` |
| Forward Port | `80` |

**Proxy Host 2:**
| Setting | Value |
|---------|-------|
| Domain Names | `site2.yourdomain.com` |
| Scheme | `http` |
| Forward Hostname/IP | `172.21.0.2` |
| Forward Port | `80` |

Same port, different networks, both work!

### Example 2: Multiple Apps on One Host

Host 1 has several services:

| Domain | Forward IP | Port | Service |
|--------|------------|------|---------|
| `app.yourdomain.com` | `172.20.0.2` | `8080` | Main app |
| `api.yourdomain.com` | `172.20.0.3` | `3000` | API service |
| `db-admin.yourdomain.com` | `172.20.0.4` | `8080` | Admin UI |

### Example 3: Database Access (Internal Only)

Don't expose databases publicly - use NPM for internal access or SSH tunnel:

```nginx
# In NPM Advanced tab - restrict to Authentik-authenticated users
set $authentik_url http://authentik-server:9000;
auth_request /outpost.goauthentik.io/auth/nginx;
error_page 401 = @authentik_login;

# Forward to Postgres on spoke 1
location / {
    proxy_pass http://172.20.0.5:5432;
}
```

## Finding Container IPs

From the **spoke** host:
```bash
# List all container IPs
docker network inspect app-network --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}'
```

From the **hub** host:
```bash
# Test connectivity
docker compose exec npm ping 172.20.0.2
docker compose exec npm wget -qO- http://172.20.0.2:80
```

## Adding SSL

Same as normal NPM - request Let's Encrypt certificates for your domains.

The fact that backend is on a VPN doesn't affect SSL termination at NPM.

## Troubleshooting

### Can't reach container IP

1. Check Nebula connection:
   ```bash
   # On hub
   ping 10.8.0.2  # Should work (spoke's VPN IP)
   ping 172.20.0.2  # Should work (container IP via routed subnet)
   ```

2. Check IP forwarding on spoke:
   ```bash
   # On spoke host
   sysctl net.ipv4.ip_forward  # Should be 1
   
   # Enable if needed
   sudo sysctl -w net.ipv4.ip_forward=1
   echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
   ```

3. Check container is on app-network:
   ```bash
   docker inspect <container> --format '{{json .NetworkSettings.Networks}}'
   ```

### Container IP changed after restart

Docker assigns IPs sequentially. To ensure consistent IPs, use static IPs:

```yaml
services:
  myapp:
    networks:
      app-network:
        ipv4_address: 172.20.0.10  # Fixed IP

networks:
  app-network:
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

Then in NPM: Forward to `172.20.0.10`

### Routes not appearing on hub

Check lighthouse config includes the spoke's subnet:
```yaml
# On hub: nebula/config.lighthouse.yml
tun:
  routes:
    - route: 172.20.0.0/16  # Spoke 1
    - route: 172.21.0.0/16  # Spoke 2
```

Restart lighthouse after changes.
