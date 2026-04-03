# NeoProxy Cheat Sheet

Quick reference for common commands.

## Docker Compose

### Basic Operations

```bash
# Start all services
docker compose up -d

# Start with specific profile
docker compose --profile hub up -d
docker compose --profile panel up -d

# Stop all
docker compose down

# Restart service
docker compose restart npm
docker compose restart authentik-server

# View logs
docker compose logs -f
docker compose logs -f npm
docker compose logs --tail=100

# Check status
docker compose ps
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
```

### Spoke Operations

```bash
# Start spoke
docker compose -f docker-compose.spoke.yml up -d

# View spoke logs
docker compose -f docker-compose.spoke.yml logs -f

# Restart spoke VPN
docker compose -f docker-compose.spoke.yml restart nebula
```

## NPM Management

### Container Operations

```bash
# Enter NPM container
docker compose exec npm sh

# Test proxy from inside
docker compose exec npm wget -qO- http://target:port

# Check NPM config
docker compose exec npm cat /data/database.sqlite
```

### Database

```bash
# Backup NPM database
cp data/npm/database.sqlite backup/npm-$(date +%Y%m%d).sqlite

# Reset to defaults (WARNING: loses config)
rm data/npm/database.sqlite
rm -rf data/npm/keys
docker compose restart npm
```

## Authentik Management

### Container Operations

```bash
# Run Django shell
docker compose exec authentik-server ak shell

# Run management commands
docker compose exec authentik-server ak manage <command>

# Check health
docker compose exec authentik-server ak healthcheck

# Export config
docker compose exec authentik-server ak export_blueprint default > blueprint.yaml
```

### Database

```bash
# Backup database
docker compose exec postgresql pg_dump -U authentik authentik > backup/authentik-$(date +%Y%m%d).sql

# Restore database
docker compose exec -T postgresql psql -U authentik authentik < backup/authentik-YYYYMMDD.sql
```

## VPN/Nebula

### Hub (Lighthouse)

```bash
# List certificates
./nebula/nebula-cert sign -list

# View lighthouse config
cat nebula/config.lighthouse.yml

# Check lighthouse logs
docker compose logs nebula-lighthouse -f

# View connected nodes
docker compose exec nebula-lighthouse nebula-cert sign -list
```

### Spoke

```bash
# Check VPN connection
docker compose -f docker-compose.spoke.yml logs nebula

# Test connectivity to hub
docker compose -f docker-compose.spoke.yml exec nebula ping 10.8.0.1

# View spoke config
cat nebula/config.yml
```

## Networking

### Docker Networks

```bash
# List networks
docker network ls

# Inspect network
docker network inspect proxy-network
docker network inspect app-network

# View container IPs
docker network inspect proxy-network --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}'
```

### Connectivity Tests

```bash
# From hub to spoke container
docker compose exec npm ping 172.20.0.2
docker compose exec npm wget -qO- http://172.20.0.2:80

# From spoke to hub
docker compose -f docker-compose.spoke.yml exec nebula ping 10.8.0.1
```

## SSL/Let's Encrypt

### Certificate Management

```bash
# List certs
docker compose exec npm ls -la /etc/letsencrypt/live/

# Renew manually
docker compose exec npm certbot renew

# Force renew
docker compose exec npm certbot renew --force-renew

# View cert info
docker compose exec npm openssl x509 -in /etc/letsencrypt/live/domain.com/fullchain.pem -text -noout
```

## Backup & Restore

### Quick Backup

```bash
# Full backup
tar -czvf backup-$(date +%Y%m%d-%H%M%S).tar.gz data/

# Automated backup script
#!/bin/bash
DATE=$(date +%Y%m%d)
mkdir -p backups/$DATE
cp -r data/npm backups/$DATE/
cp -r data/authentik backups/$DATE/
cp -r data/postgresql backups/$DATE/
tar -czf backups/backup-$DATE.tar.gz backups/$DATE/
rm -rf backups/$DATE
```

### Restore

```bash
# Stop services
docker compose down

# Restore from backup
rm -rf data
tar -xzvf backup-YYYYMMDD.tar.gz

# Start services
docker compose up -d
```

## HA Operations

### Keepalived

```bash
# View VRRP status
docker compose -f docker-compose.ha.yml logs keepalived

# Check floating IP
ip addr show | grep VIRTUAL_IP

# Force failover (lower priority)
docker compose -f docker-compose.ha.yml stop keepalived
```

### GlusterFS

```bash
# Check volume status
sudo gluster volume status

# Check peer status
sudo gluster peer status

# Heal volume
sudo gluster volume heal neoproxy-data

# View heal info
sudo gluster volume heal neoproxy-data info
```

## Debugging

### Logs

```bash
# All services
docker compose logs --tail=500 > debug.log

# Specific timeframe
docker compose logs --since=10m

# With timestamps
docker compose logs -t --tail=100
```

### System Info

```bash
# Docker info
docker info
docker version

# System resources
docker stats --no-stream
df -h
free -h

# Network info
ip addr
ip route
netstat -tlnp
```

### Clean Up

```bash
# Remove unused containers
docker container prune -f

# Remove unused images
docker image prune -f

# Remove unused volumes
docker volume prune -f

# Full cleanup (DANGER: removes unused everything)
docker system prune -f
```

## File Locations

### Configuration

```
./.env                           # Environment variables
./docker-compose.yml             # Main stack
./docker-compose.spoke.yml       # Spoke stack
./docker-compose.ha.yml          # HA stack
./nebula/config.lighthouse.yml   # VPN hub config
./nebula/config.yml              # VPN spoke config
```

### Data

```
./data/npm/database.sqlite       # NPM database
./data/npm/keys/                 # NPM encryption keys
./data/letsencrypt/              # SSL certificates
./data/postgresql/               # Authentik database
./data/authentik/media/          # Authentik uploads
./data/redis/                    # Redis data
```

## Environment Variables Quick Ref

```bash
# Edit config
nano .env

# Reload services after edit
docker compose up -d

# View current values
docker compose exec npm env
docker compose exec authentik-server env
```

## Common Port Reference

| Port | Service | Usage |
|------|---------|-------|
| 80 | NPM | HTTP |
| 443 | NPM | HTTPS |
| 81 | NPM | Admin UI |
| 4242/UDP | Nebula | VPN |
| 9000 | Authentik | Auth (internal) |
| 8080 | Homer | Control panel |
