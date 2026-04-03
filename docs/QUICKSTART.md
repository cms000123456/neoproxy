# Quick Start Guide

Get NeoProxy running in 5 minutes.

## Choose Your Setup

| I want to... | Setup Type | Time |
|--------------|------------|------|
| Proxy apps on one server | [Standalone](#standalone) | 3 min |
| Connect multiple servers | [Hub-Spoke](#hub-spoke) | 10 min |
| Production with failover | [High Availability](#high-availability) | 30 min |

---

## Standalone

Single server with NPM + Authentik.

```bash
# 1. Clone repository
git clone git@github.com:cms000123456/neoproxy.git
cd neoproxy

# 2. Run setup
./setup.sh
# Select option 1 (Standalone)

# 3. Access services
# NPM:        http://localhost:81 (default login: admin@example.com / changeme)
# Authentik:  http://localhost:9000 (create admin on first run)
```

### Add Your First App

```bash
# 1. Deploy an app
docker run -d --name myapp --network neoproxy_proxy-network nginx:alpine

# 2. Get container IP
docker inspect myapp --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
# Example: 172.20.0.2

# 3. In NPM (http://localhost:81):
#    - Go to Hosts > Proxy Hosts > Add
#    - Domain: myapp.local
#    - Forward IP: 172.20.0.2 (from above)
#    - Forward Port: 80
#    - Save

# 4. Add to /etc/hosts:
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts

# 5. Visit http://myapp.local
```

---

## Hub-Spoke

Main proxy (hub) with remote application servers (spokes).

### On Hub (Main Server)

```bash
# 1. Setup hub
cd neoproxy
./setup.sh
# Select option 2 (Hub)

# 2. Note your public IP
 curl -s ifconfig.me
# Example: 203.0.113.10

# 3. Generate spoke config
./generate-spoke.sh spoke1 172.20.0.0/16 10.8.0.2
# Creates: spokes/spoke1/
```

### On Spoke (Remote Server)

```bash
# 1. Copy config from hub
scp -r user@hub:~/neoproxy/spokes/spoke1 ~/neoproxy-spoke
cd ~/neoproxy-spoke

# 2. Setup spoke
./setup.sh
# Select option 3 (Spoke)
# Enter hub IP: 203.0.113.10

# 3. Deploy an app
cat > docker-compose.override.yml << 'EOF'
version: "3.8"
services:
  myapp:
    image: nginx:alpine
    networks:
      - app-network
EOF
docker compose up -d

# 4. Get container IP
docker inspect neoproxy-spoke-myapp-1 --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
# Example: 172.20.0.2
```

### Back on Hub

```bash
# In NPM (http://localhost:81):
# 1. Create Proxy Host
#    - Domain: myapp.example.com
#    - Forward IP: 172.20.0.2 (spoke container IP)
#    - Forward Port: 80
# 2. Enable SSL
# 3. Save
```

---

## High Availability

Multiple controllers with automatic failover.

### Prerequisites

- 2 or 3 servers (controllers)
- Shared storage (GlusterFS) or DRBD
- Floating IP capability (VRRP)

### Setup

```bash
# On all controllers
sudo apt-get install -y glusterfs-server

# On controller 1
./ha-setup/gluster/setup-gluster.sh 192.168.1.10 192.168.1.11 192.168.1.12

# On each controller
cd ha-setup
./setup-ha.sh
# Select: 2 (MASTER on controller 1), 3 (BACKUP on others)

# Start HA
./setup-ha.sh
# Select: 4 (Start HA stack)
```

### Verify

```bash
# Check which controller is active
ip addr show | grep 203.0.113.10

# Stop controller 1, verify controller 2 takes over
```

---

## Quick Commands

```bash
# View all services
docker compose ps

# View logs
docker compose logs -f

# Restart a service
docker compose restart npm

# Update images
docker compose pull
docker compose up -d

# Backup data
tar -czvf backup-$(date +%Y%m%d).tar.gz ./data

# Check VPN status (hub-spoke)
docker compose exec nebula-lighthouse nebula-cert sign -list
```

## Next Steps

1. **[Configure Authentik](../AUTHENTIK-GUIDE.md)** - Add SSO/MFA
2. **[Add More Apps](../examples/npm-config-example.md)** - Proxy configuration examples
3. **[Set up Control Panel](../control-panel/)** - Unified dashboard

## Common Issues

### Can't access NPM on port 81

```bash
# Check if running
docker compose ps npm

# Check logs
docker compose logs npm

# Ensure port not in use
sudo netstat -tlnp | grep :81
```

### Spoke can't connect to hub

```bash
# Check firewall on hub
sudo ufw status | grep 4242

# Verify Nebula is running on hub
docker compose ps nebula-lighthouse

# Check spoke logs
docker compose -f docker-compose.spoke.yml logs nebula
```

### SSL certificate fails

```bash
# Ensure domain points to server IP
nslookup yourdomain.com

# Check port 80 is accessible
curl -I http://yourdomain.com/.well-known/acme-challenge/test
```
