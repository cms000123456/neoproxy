# High Availability Setup - Multi-Controller with VRRP

Run multiple NPM+Authentik controllers with automatic failover and data synchronization.

```
                          Internet
                             │
         ┌───────────────────┴───────────────────┐
         │         VRRP/Keepalived (Floating IP)  │
         │            203.0.113.10                │
         │         (Virtual IP/HA IP)             │
         └───────────────────┬───────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
       ┌────────────┐ ┌────────────┐ ┌────────────┐
       │ Controller 1│ │ Controller 2│ │ Controller 3│
       │  (MASTER)   │ │  (BACKUP)   │ │  (BACKUP)   │
       │             │ │             │ │             │
       │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────┐ │
       │ │   NPM   │ │ │ │   NPM   │ │ │ │   NPM   │ │
       │ │Authentik│ │ │ │Authentik│ │ │ │Authentik│ │
       │ └────┬────┘ │ │ └────┬────┘ │ │ └────┬────┘ │
       └──────┼──────┘ └──────┼──────┘ └──────┼──────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
                   ┌──────────▼──────────┐
                   │   Shared Storage    │
                   │ ┌─────────────────┐ │
                   │ │  SQLite (NPM)   │ │
                   │ │  Postgres (Auth)│ │
                   │ │  Let's Encrypt  │ │
                   │ └─────────────────┘ │
                   │   (GlusterFS/DRBD)  │
                   └─────────────────────┘
```

## Architecture Options

### Option 1: Shared Storage (GlusterFS) - Recommended

All controllers mount the same data directories via GlusterFS.

**Pros:**
- Single source of truth
- Automatic synchronization
- Works with SQLite

**Cons:**
- Network dependency for storage
- Slightly more complex setup

### Option 2: Active-Standby with DRBD

Block-level replication between primary and secondary.

**Pros:**
- Synchronous replication
- Works like local storage

**Cons:**
- Only 2 nodes active (others standby)
- More complex failover

### Option 3: Database Replication

Use PostgreSQL/MySQL instead of SQLite for NPM.

**Pros:**
- Native HA database
- Each node can have local SQLite

**Cons:**
- Requires NPM code changes
- More complex

## Quick Start - GlusterFS Shared Storage

### 1. Setup GlusterFS on All Controllers

**Controller 1, 2, 3:**

```bash
# Install GlusterFS
sudo apt-get update
sudo apt-get install -y glusterfs-server
sudo systemctl enable --now glusterd

# Create bricks
sudo mkdir -p /data/gluster/brick
```

**On Controller 1 only:**

```bash
# Probe peers
sudo gluster peer probe controller2
sudo gluster peer probe controller3

# Create replicated volume
sudo gluster volume create neoproxy-replica \
  replica 3 \
  controller1:/data/gluster/brick \
  controller2:/data/gluster/brick \
  controller3:/data/gluster/brick

# Start volume
sudo gluster volume start neoproxy-replica

# Mount on all controllers
sudo mkdir -p /mnt/neoproxy-data
sudo mount -t glusterfs controller1:/neoproxy-replica /mnt/neoproxy-data
```

### 2. Deploy Stack on All Controllers

**docker-compose.ha.yml:**

```yaml
version: "3.8"

services:
  keepalived:
    image: osixia/keepalived:latest
    container_name: keepalived
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - NET_BROADCAST
    network_mode: host
    environment:
      - KEEPALIVED_VIRTUAL_IP=203.0.113.10
      - KEEPALIVED_PRIORITY=100  # 100=MASTER, 90=BACKUP, 80=BACKUP
      - KEEPALIVED_INTERFACE=eth0
      - KEEPALIVED_ROUTER_ID=51
    volumes:
      - ./keepalived/keepalived.conf:/usr/local/etc/keepalived/keepalived.conf:ro

  npm:
    image: jc21/nginx-proxy-manager:latest
    container_name: npm
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    volumes:
      # Shared GlusterFS mount
      - /mnt/neoproxy-data/npm:/data
      - /mnt/neoproxy-data/letsencrypt:/etc/letsencrypt
    networks:
      - proxy-network
    depends_on:
      - authentik-server

  # ... rest of services using shared storage
```

### 3. Start Services

On all controllers:
```bash
docker compose -f docker-compose.ha.yml up -d
```

## VRRP Configuration

**keepalived.conf (MASTER - Controller 1):**

```conf
global_defs {
    router_id NPM_HA_1
}

vrrp_script check_npm {
    script "/usr/bin/docker ps | grep npm | grep healthy"
    interval 2
    weight -20
    fall 3
    rise 2
}

vrrp_instance VI_NPM {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass Secret123
    }
    
    virtual_ipaddress {
        203.0.113.10/24
    }
    
    track_script {
        check_npm
    }
    
    notify_master "/usr/local/bin/notify.sh master"
    notify_backup "/usr/local/bin/notify.sh backup"
    notify_fault "/usr/local/bin/notify.sh fault"
}
```

**keepalived.conf (BACKUP - Controller 2):**

```conf
global_defs {
    router_id NPM_HA_2
}

vrrp_script check_npm {
    script "/usr/bin/docker ps | grep npm | grep healthy"
    interval 2
    weight -20
    fall 3
    rise 2
}

vrrp_instance VI_NPM {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 90  # Lower than MASTER
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass Secret123
    }
    
    virtual_ipaddress {
        203.0.113.10/24
    }
    
    track_script {
        check_npm
    }
}
```

## Database HA Options

### Option A: Shared PostgreSQL (Simple)

Run PostgreSQL on one controller, use shared storage:

```yaml
  postgresql:
    image: postgres:16-alpine
    volumes:
      - /mnt/neoproxy-data/postgresql:/var/lib/postgresql/data
```

**Note:** If controller with Postgres fails, Authentik fails over but Postgres doesn't. Use Option B for true HA.

### Option B: PostgreSQL Streaming Replication

Primary-Replica setup with automatic failover using Patroni:

See [postgres-ha/](./postgres-ha/) for detailed setup.

### Option C: Each Controller Has Own DB

Each controller runs its own Authentik DB, sync via Authentik's built-in replication:

```yaml
# Each controller has unique DB
data-authentik-c1/  # Controller 1
data-authentik-c2/  # Controller 2
data-authentik-c3/  # Controller 3
```

Users must login to each controller separately. Best for complete isolation.

## Complete Working Example

See [docker-compose.ha.yml](./docker-compose.ha.yml) for full stack.

## Health Checks

The setup includes health checks for:

1. **Keepalived** monitors NPM container health
2. **If NPM fails** on MASTER, VRRP priority drops, BACKUP takes over
3. **Shared storage** ensures data consistency

## Failover Scenarios

| Scenario | Result | Recovery |
|----------|--------|----------|
| Controller 1 (MASTER) fails | Controller 2 becomes MASTER | Restart Controller 1, it becomes BACKUP |
| NPM container fails | Keepalived detects, failover initiated | Container restarts, may regain MASTER |
| GlusterFS split-brain | Quorum prevents data corruption | Manual intervention needed |
| Network partition | Split-brain prevention kicks in | Resolve network, Gluster heals |

## DNS Considerations

Point your domain to the **Virtual IP**:

```
yourdomain.com A 203.0.113.10
```

Not to individual controller IPs!

## Load Balancing vs HA

This setup provides **HA (failover)**, not load balancing:

- Only one controller active at a time
- Failover time: ~1-3 seconds (VRRP advertisement interval)
- All controllers share the load in ACTIVE-ACTIVE setup (more complex)

For load balancing, consider adding HAProxy/nginx layer above:

```
Internet ─► HAProxy ─► Controller 1 (active)
               │
               └───────► Controller 2 (active)
```

See [load-balanced/](./load-balanced/) for active-active setup.

## Monitoring

Add health check endpoint:

```bash
# Check which controller is MASTER
ip addr show eth0 | grep 203.0.113.10

# Check VRRP status
docker compose exec keepalived cat /var/run/keepalived.pid

# Check GlusterFS status
sudo gluster volume status
```

## Files

- [docker-compose.ha.yml](./docker-compose.ha.yml) - Full HA stack
- [keepalived/](./keepalived/) - VRRP configurations
- [gluster/](./gluster/) - Shared storage setup
- [drbd/](./drbd/) - Alternative block replication
