# Backup & Restore

Protect your NeoProxy configuration and data.

## What to Backup

| Component | Location | Critical? |
|-----------|----------|-----------|
| NPM Database | `data/npm/database.sqlite` | ✅ Yes |
| NPM Keys | `data/npm/keys/` | ✅ Yes |
| SSL Certificates | `data/letsencrypt/` | ✅ Yes |
| Authentik DB | `data/postgresql/` | ✅ Yes |
| Authentik Media | `data/authentik/media/` | ⚠️ Optional |
| Authentik Certs | `data/authentik/certs/` | ✅ Yes |
| VPN Certs | `nebula/*.crt`, `nebula/*.key` | ✅ Yes |
| Configuration | `.env`, `docker-compose*.yml` | ✅ Yes |

## Automated Backup

### Simple Daily Backup

Create `backup.sh`:

```bash
#!/bin/bash
# Daily backup script

BACKUP_DIR="/opt/backups/neoproxy"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup directory
mkdir -p "$BACKUP_DIR/$DATE"

# Stop services briefly for consistent backup
docker compose down

# Copy data
cp -r data "$BACKUP_DIR/$DATE/"
cp -r nebula "$BACKUP_DIR/$DATE/"
cp .env "$BACKUP_DIR/$DATE/"
cp docker-compose*.yml "$BACKUP_DIR/$DATE/" 2>/dev/null || true

# Create archive
cd "$BACKUP_DIR"
tar -czf "neoproxy-$DATE.tar.gz" "$DATE/"
rm -rf "$DATE/"

# Restart services
cd /opt/neoproxy
docker compose up -d

# Clean old backups
find "$BACKUP_DIR" -name "neoproxy-*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $BACKUP_DIR/neoproxy-$DATE.tar.gz"
```

Add to crontab:
```bash
# Daily at 2 AM
0 2 * * * /opt/neoproxy/backup.sh >> /var/log/neoproxy-backup.log 2>&1
```

### Live Backup (No Downtime)

For zero-downtime backup, use database-specific tools:

```bash
#!/bin/bash
# Live backup script

BACKUP_DIR="/opt/backups/neoproxy"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

# Backup NPM (SQLite - copy while running)
docker compose exec npm sqlite3 /data/database.sqlite ".backup /tmp/npm-backup.sqlite"
docker compose cp npm:/tmp/npm-backup.sqlite "$BACKUP_DIR/npm-$DATE.sqlite"

# Backup Authentik PostgreSQL
docker compose exec postgresql pg_dump -U authentik authentik > "$BACKUP_DIR/authentik-$DATE.sql"

# Backup files
tar -czf "$BACKUP_DIR/neoproxy-files-$DATE.tar.gz" \
  data/letsencrypt \
  data/authentik/certs \
  nebula/*.crt \
  nebula/*.key \
  .env \
  docker-compose*.yml

echo "Backup completed: $BACKUP_DIR/"
```

## Manual Backup

### Quick Full Backup

```bash
# Create backup directory
mkdir -p backup/$(date +%Y%m%d)

# Stop services
docker compose down

# Copy everything important
cp -r data backup/$(date +%Y%m%d)/
cp -r nebula backup/$(date +%Y%m%d)/
cp .env backup/$(date +%Y%m%d)/
cp docker-compose*.yml backup/$(date +%Y%m%d)/ 2>/dev/null || true

# Create archive
tar -czvf backup/neoproxy-$(date +%Y%m%d).tar.gz backup/$(date +%Y%m%d)/

# Cleanup
rm -rf backup/$(date +%Y%m%d)

# Restart
docker compose up -d
```

### Component-Specific Backup

#### NPM Only

```bash
# Backup
cp data/npm/database.sqlite backup/npm-$(date +%Y%m%d).sqlite
tar -czf backup/npm-certs-$(date +%Y%m%d).tar.gz data/letsencrypt/

# Restore
docker compose stop npm
cp backup/npm-YYYYMMDD.sqlite data/npm/database.sqlite
docker compose start npm
```

#### Authentik Only

```bash
# Backup database
docker compose exec postgresql pg_dump -U authentik authentik > backup/authentik-$(date +%Y%m%d).sql

# Backup media
tar -czf backup/authentik-media-$(date +%Y%m%d).tar.gz data/authentik/media/

# Restore
docker compose down
# Restore PostgreSQL data
docker compose up -d postgresql
sleep 10
docker compose exec -T postgresql psql -U authentik authentik < backup/authentik-YYYYMMDD.sql
# Restore media
tar -xzf backup/authentik-media-YYYYMMDD.tar.gz
docker compose up -d
```

## Remote Backup

### Sync to Remote Server

```bash
#!/bin/bash
# Backup and sync to remote

./backup.sh

# Sync to remote server
rsync -avz --delete /opt/backups/neoproxy/ user@backup-server:/backups/neoproxy/

# Or to S3
aws s3 sync /opt/backups/neoproxy/ s3://my-backup-bucket/neoproxy/
```

### Cloud Backup (S3)

```bash
#!/bin/bash
# Backup to S3 with encryption

BACKUP_FILE="neoproxy-$(date +%Y%m%d_%H%M%S).tar.gz"

# Create encrypted backup
tar -czf - data nebula .env docker-compose*.yml | \
  gpg --symmetric --cipher-algo AES256 -o "/tmp/$BACKUP_FILE.gpg"

# Upload to S3
aws s3 cp "/tmp/$BACKUP_FILE.gpg" s3://my-backup-bucket/neoproxy/

# Clean up
rm "/tmp/$BACKUP_FILE.gpg"

# Keep only last 30 days in S3
aws s3 ls s3://my-backup-bucket/neoproxy/ | \
  awk '$1 < "'$(date -d '30 days ago' +%Y-%m-%d)'" {print $4}' | \
  xargs -I {} aws s3 rm s3://my-backup-bucket/neoproxy/{}
```

## Restore

### Full Restore

```bash
# Stop services
docker compose down

# Remove current data (WARNING!)
rm -rf data
rm -rf nebula

# Extract backup
tar -xzvf backup/neoproxy-YYYYMMDD.tar.gz

# Move data back
mv backup/YYYYMMDD/data ./
mv backup/YYYYMMDD/nebula ./
cp backup/YYYYMMDD/.env ./
cp backup/YYYYMMDD/docker-compose*.yml ./ 2>/dev/null || true

# Start services
docker compose up -d
```

### Restore to New Server

1. **Install prerequisites** on new server
2. **Copy backup** to new server
3. **Extract and restore** as above
4. **Update configuration:**
   ```bash
   # Update IP in .env if changed
   nano .env
   
   # Update lighthouse IP if hub
   nano nebula/config.lighthouse.yml
   ```
5. **Start services**
6. **Update DNS** to point to new server

## HA Backup Considerations

### Shared Storage (GlusterFS)

GlusterFS provides built-in redundancy. Additional backup:

```bash
# Backup from any controller
tar -czf backup/ha-$(date +%Y%m%d).tar.gz /mnt/neoproxy-data/

# Or use GlusterFS snapshots
sudo gluster snapshot create neoproxy-backup neoproxy-data
```

### Before Major Changes

Always backup before:
- Upgrading versions
- Changing network configuration
- Modifying Authentik flows
- Adding new spokes

```bash
# Pre-change snapshot
docker compose down
tar -czf backup/pre-change-$(date +%Y%m%d-%H%M%S).tar.gz data nebula
docker compose up -d
```

## Testing Backups

Regularly test your backups!

```bash
# Monthly restore test
mkdir -p /tmp/restore-test
cd /tmp/restore-test
tar -xzvf /opt/backups/neoproxy/neoproxy-YYYYMMDD.tar.gz
# Verify files exist and are valid
ls -la data/npm/
sqlite3 data/npm/database.sqlite ".tables"
# Clean up
cd /
rm -rf /tmp/restore-test
```

## Backup Checklist

- [ ] Daily automated backups configured
- [ ] Backups stored off-site or in cloud
- [ ] Retention policy (30 days recommended)
- [ ] Monthly restore testing scheduled
- [ ] Backup notifications/alerts set up
- [ ] Encryption for sensitive backups
- [ ] Documented restore procedures
