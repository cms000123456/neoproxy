# Troubleshooting Guide

Common issues and their solutions.

## Quick Diagnostics

```bash
# Check all services
docker compose ps

# View recent logs
docker compose logs --tail=50

# Check specific service
docker compose logs npm

# System resources
docker stats --no-stream
```

---

## NPM Issues

### Can't access NPM admin (port 81)

**Symptoms:** Connection refused on port 81

**Diagnosis:**
```bash
docker compose ps npm
docker compose logs npm
sudo netstat -tlnp | grep :81
```

**Solutions:**

1. **Container not running:**
   ```bash
   docker compose up -d npm
   ```

2. **Port already in use:**
   ```bash
   # Find process using port 81
   sudo lsof -i :81
   # Stop conflicting service
   sudo systemctl stop apache2 nginx
   ```

3. **Database locked:**
   ```bash
   # SQLite lock issue
   docker compose down
   rm data/npm/database.sqlite
   docker compose up -d
   # Note: You'll need to reconfigure NPM
   ```

### Default login doesn't work

**Default credentials:** `admin@example.com` / `changeme`

**If login fails:**
```bash
# Reset to default
docker compose down
rm data/npm/database.sqlite
rm -rf data/npm/keys
docker compose up -d
# Wait 30 seconds, try again
```

### SSL certificate fails

**Symptoms:** Let's Encrypt validation fails

**Check:**
```bash
# Domain resolves to server?
nslookup yourdomain.com

# Port 80 accessible?
curl -I http://yourdomain.com

# Firewall allows port 80?
sudo ufw status
```

**Solutions:**

1. **DNS not propagated:**
   ```bash
   # Wait for DNS propagation
   # Check with: dig yourdomain.com
   ```

2. **Firewall blocking:**
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

3. **Rate limited by Let's Encrypt:**
   ```bash
   # Wait 1 hour before retrying
   # Check limits: https://letsencrypt.org/docs/rate-limits/
   ```

---

## Authentik Issues

### Can't access Authentik (port 9000)

**Check:**
```bash
docker compose ps authentik-server
docker compose logs authentik-server
```

**Database connection error:**
```bash
# Check PostgreSQL
docker compose ps postgresql
docker compose logs postgresql

# Reset database (WARNING: loses all data)
docker compose down
rm -rf data/postgresql
./setup.sh
```

### First-time setup wizard not appearing

**Clear browser cache** or try:
```bash
# Force wizard
# Go to: http://localhost:9000/if/flow/initial-setup/
```

### MFA not working

1. **Check user has MFA device:**
   - Admin: Directory > Users > [user] > MFA

2. **Check flow has MFA stage:**
   - Admin: Flows & Stages > default-authentication-flow
   - Ensure "Authenticator Validation Stage" is included

3. **Time sync issues:**
   ```bash
   # Sync system time
   sudo ntpdate pool.ntp.org
   ```

---

## VPN/Inter-Host Issues

### Spoke can't connect to hub

**Symptoms:** Spoke shows "Disconnected" or timeout

**Diagnosis on Hub:**
```bash
# Check Nebula running
docker compose ps nebula-lighthouse

# Check port 4242 open
sudo netstat -uln | grep 4242

# Check firewall
sudo ufw status | grep 4242
```

**Diagnosis on Spoke:**
```bash
# Check Nebula logs
docker compose -f docker-compose.spoke.yml logs nebula

# Ping hub VPN IP
ping 10.8.0.1
```

**Solutions:**

1. **Firewall blocking on hub:**
   ```bash
   sudo ufw allow 4242/udp
   # or
   sudo firewall-cmd --add-port=4242/udp --permanent
   sudo firewall-cmd --reload
   ```

2. **Wrong public IP in config:**
   ```bash
   # Update config.lighthouse.yml with correct IP
   sed -i 's/OLD_IP/NEW_IP/g' nebula/config.lighthouse.yml
   docker compose restart nebula-lighthouse
   ```

3. **Certificate mismatch:**
   ```bash
   # Regenerate spoke certificate
   ./generate-spoke.sh spoke1 172.20.0.0/16 10.8.0.2
   # Redeploy spoke
   ```

### Can't reach spoke containers from hub

**Check routing:**
```bash
# From hub, can you reach spoke VPN IP?
ping 10.8.0.2

# Can you reach spoke container IP?
ping 172.20.0.2
```

**Fix routing:**
```bash
# On spoke host, enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.conf

# Check container is on app-network
docker network inspect app-network
```

---

## HA/Keepalived Issues

### Floating IP not moving on failover

**Check VRRP status:**
```bash
# On all controllers
docker compose -f docker-compose.ha.yml logs keepalived

# Check IP assignment
ip addr show | grep VIRTUAL_IP
```

**Solutions:**

1. **Different auth passwords:**
   ```bash
   # Ensure keepalived.conf has same auth_pass on all nodes
   ```

2. **Different router_id:**
   ```bash
   # virtual_router_id must be same on all nodes
   # But each node should have unique ROUTER_ID env var
   ```

3. **Firewall blocking VRRP:**
   ```bash
   # Allow VRRP (protocol 112)
   sudo ufw allow from any to any proto 112
   ```

### Split-brain (both think they're MASTER)

**Causes:**
- Network partition between controllers
- Firewall blocking VRRP advertisements

**Fix:**
```bash
# Restart keepalived on all nodes
docker compose -f docker-compose.ha.yml restart keepalived

# Check GlusterFS status
sudo gluster volume status
```

---

## Performance Issues

### NPM slow/unresponsive

**Check resources:**
```bash
docker stats npm --no-stream
top
```

**Solutions:**

1. **High CPU:**
   ```bash
   # Check for request floods
   docker compose logs npm | grep "error"
   
   # Limit resources
   # Add to docker-compose.yml:
   # deploy:
   #   resources:
   #     limits:
   #       cpus: '2.0'
   ```

2. **High memory:**
   ```bash
   # Restart to clear memory
   docker compose restart npm
   ```

### Authentik slow login

**Check database:**
```bash
# PostgreSQL performance
docker compose exec postgresql psql -U authentik -c "SELECT * FROM pg_stat_activity;"
```

**Solutions:**

1. **Database maintenance:**
   ```bash
   docker compose exec postgresql vacuumdb -U authentik -d authentik
   ```

2. **Increase cache:**
   ```bash
   # Add to environment
   AUTHENTIK_CACHE_TIMEOUT=3600
   ```

---

## Data/Storage Issues

### Permission denied errors

**Fix permissions:**
```bash
# Set correct ownership
sudo chown -R $USER:$USER ./data
chmod -R 755 ./data

# For GlusterFS
sudo chown -R 1000:1000 /mnt/neoproxy-data
```

### Database corruption

**SQLite (NPM):**
```bash
# Backup first
cp data/npm/database.sqlite data/npm/database.sqlite.bak

# Try to repair
sqlite3 data/npm/database.sqlite ".recover" | sqlite3 data/npm/database.sqlite.new
mv data/npm/database.sqlite.new data/npm/database.sqlite
```

**PostgreSQL (Authentik):**
```bash
# Check integrity
docker compose exec postgresql pg_dump -U authentik authentik > /dev/null

# If corrupted, restore from backup
docker compose down
rm -rf data/postgresql
cp -r backup/postgresql data/
docker compose up -d
```

---

## Getting More Help

### Collect debug info

```bash
# Create debug bundle
mkdir -p debug
docker compose ps > debug/ps.txt
docker compose logs > debug/logs.txt
docker version > debug/docker-version.txt
docker info > debug/docker-info.txt
ip addr > debug/ip-addr.txt
ip route > debug/ip-route.txt
tar -czvf debug-$(date +%Y%m%d).tar.gz debug/
```

### Useful commands

```bash
# Restart everything
docker compose down
docker compose up -d

# Force recreate
docker compose up -d --force-recreate

# Clean unused
docker system prune -f

# Check disk space
df -h
docker system df
```
