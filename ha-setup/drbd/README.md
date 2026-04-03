# DRBD Setup (Alternative to GlusterFS)

DRBD (Distributed Replicated Block Device) provides block-level replication for synchronous data mirroring.

## When to Use DRBD

- ✅ Need synchronous replication (zero data loss)
- ✅ Only 2 controllers (active-passive)
- ✅ Performance critical workloads
- ❌ Not recommended for >2 nodes

## Architecture

```
┌──────────────────┐                      ┌──────────────────┐
│  Controller 1    │◄────── DRBD ────────►│  Controller 2    │
│  (PRIMARY)       │    Synchronous       │  (SECONDARY)     │
│                  │    Replication       │                  │
│ ┌──────────────┐ │                      │ ┌──────────────┐ │
│ │ /dev/drbd0   │ │                      │ │ /dev/drbd0   │ │
│ │  (data)      │ │                      │ │  (data)      │ │
│ └──────┬───────┘ │                      │ └──────┬───────┘ │
│        │         │                      │        │         │
│   ┌────▼────┐    │                      │   ┌────▼────┐    │
│   │  NPM    │    │                      │   │  NPM    │    │
│   │  Data   │    │                      │   │  Data   │    │
│   └─────────┘    │                      │   └─────────┘    │
└──────────────────┘                      └──────────────────┘
```

## Quick Setup

### 1. Install DRBD

On both controllers:

```bash
# Ubuntu/Debian
sudo apt-get install -y drbd-utils

# RHEL/CentOS
sudo yum install -y drbd-utils kmod-drbd
```

### 2. Create LVM Volume (optional but recommended)

```bash
# Create logical volume for DRBD
sudo lvcreate -L 100G -n drbd0 vg0
```

### 3. Configure DRBD

**/etc/drbd.d/neoproxy.res** (on both nodes):

```
resource neoproxy {
    protocol C;
    
    on controller1 {
        device /dev/drbd0;
        disk /dev/vg0/drbd0;  # or /dev/sdb1
        address 192.168.1.10:7789;
        meta-disk internal;
    }
    
    on controller2 {
        device /dev/drbd0;
        disk /dev/vg0/drbd0;
        address 192.168.1.11:7789;
        meta-disk internal;
    }
}
```

### 4. Initialize and Start

On both nodes:
```bash
sudo drbdadm create-md neoproxy
sudo drbdadm up neoproxy
```

On primary only:
```bash
sudo drbdadm primary --force neoproxy
```

### 5. Format and Mount

```bash
sudo mkfs.ext4 /dev/drbd0
sudo mkdir -p /mnt/neoproxy-data
sudo mount /dev/drbd0 /mnt/neoproxy-data
```

## Integration with NeoProxy

Use DRBD mount as shared storage:

```bash
# In .env
SHARED_DATA_PATH=/mnt/neoproxy-data
```

## Failover with Pacemaker (Optional)

For automatic failover, use Pacemaker:

```bash
sudo apt-get install -y pacemaker corosync

# Configure cluster resources for DRBD + NeoProxy
```

## Comparison: DRBD vs GlusterFS

| Feature | DRBD | GlusterFS |
|---------|------|-----------|
| Replication level | Block | File |
| Synchronous | ✅ Yes | ⚠️ Configurable |
| Multi-node (>2) | ❌ No | ✅ Yes |
| Complexity | Higher | Lower |
| Performance | Better for DB | Good for general |
| Split-brain | Needs quorum | Self-healing |

## Recommendation

- **2 controllers only**: Use DRBD for better performance
- **3+ controllers**: Use GlusterFS
- **Simple setup**: Use GlusterFS
