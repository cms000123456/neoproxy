# Prerequisites

System requirements and setup instructions for NeoProxy.

## Minimum Requirements

### Hardware

| Setup Type | CPU | RAM | Storage | Network |
|------------|-----|-----|---------|---------|
| Standalone | 1 core | 2 GB | 10 GB | 100 Mbps |
| Hub | 2 cores | 4 GB | 20 GB | 1 Gbps |
| Hub + HA | 2 cores | 4 GB | 20 GB | 1 Gbps per controller |
| Spoke | 1 core | 1 GB | 5 GB | 100 Mbps |

### Software

- **OS**: Linux (Ubuntu 20.04+, Debian 11+, RHEL 8+, CentOS 8+)
- **Docker**: 20.10.0 or later
- **Docker Compose**: 2.0.0 or later (plugin or standalone)
- **Kernel**: 3.10+ (5.x recommended)

## Installation

### 1. Install Docker

**Ubuntu/Debian:**

```bash
# Remove old versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Install dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify
sudo docker --version
sudo docker compose version
```

**RHEL/CentOS/Rocky:**

```bash
# Add Docker repository
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable
sudo systemctl start docker
sudo systemctl enable docker

# Verify
sudo docker --version
sudo docker compose version
```

### 2. Add User to Docker Group (Optional)

```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Apply changes (log out and back in, or)
newgrp docker

# Test
docker ps
```

### 3. Install Additional Tools

```bash
# Ubuntu/Debian
sudo apt-get install -y curl wget git openssl net-tools

# RHEL/CentOS
sudo yum install -y curl wget git openssl net-tools
```

### 4. Verify Kernel Modules (for VPN)

```bash
# Check if TUN/TAP is available
ls /dev/net/tun

# If not loaded:
sudo modprobe tun

# Make permanent
echo "tun" | sudo tee /etc/modules-load.d/nebula.conf
```

## Network Requirements

### Standalone Setup

| Port | Direction | Service | Notes |
|------|-----------|---------|-------|
| 80 | Inbound | HTTP | Redirects to HTTPS |
| 443 | Inbound | HTTPS | Main web traffic |
| 81 | Inbound | NPM Admin | Restrict access |

### Hub Setup

| Port | Direction | Service | Notes |
|------|-----------|---------|-------|
| 80 | Inbound | HTTP | Public |
| 443 | Inbound | HTTPS | Public |
| 81 | Inbound | NPM Admin | Restrict to admin IPs |
| 4242/UDP | Inbound | Nebula VPN | Open to all spokes |
| 9000 | Internal | Authentik | Don't expose publicly |

### HA Setup

| Port | Direction | Service | Notes |
|------|-----------|---------|-------|
| 80 | Inbound | HTTP | Via floating IP |
| 443 | Inbound | HTTPS | Via floating IP |
| 81 | Inbound | NPM Admin | Via floating IP |
| 4242/UDP | Inbound | Nebula VPN | All controllers |
| 24007 | Between nodes | GlusterFS | If using Gluster |
| 24008 | Between nodes | GlusterFS | If using Gluster |

## Firewall Configuration

### UFW (Ubuntu/Debian)

```bash
# Allow SSH (don't lock yourself out!)
sudo ufw allow ssh

# Allow web traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow NPM admin (restrict to your IP if possible)
sudo ufw allow 81/tcp

# Allow Nebula VPN (hub only)
sudo ufw allow 4242/udp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### FirewallD (RHEL/CentOS)

```bash
# Allow web traffic
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=81/tcp

# Allow Nebula VPN (hub only)
sudo firewall-cmd --permanent --add-port=4242/udp

# Reload
sudo firewall-cmd --reload

# Check status
sudo firewall-cmd --list-all
```

## DNS Requirements

### For Production Use

You'll need:

1. **A domain name** (e.g., `yourdomain.com`)
2. **DNS A records** pointing to your server(s)

Example DNS configuration:

```dns
# Point to hub IP (or floating IP for HA)
yourdomain.com        A    203.0.113.10
auth.yourdomain.com   A    203.0.113.10
app1.yourdomain.com   A    203.0.113.10
app2.yourdomain.com   A    203.0.113.10

# For internal use (optional)
hub.internal          A    10.8.0.1
spoke1.internal       A    10.8.0.2
spoke2.internal       A    10.8.0.3
```

## SSL/TLS Certificates

### Let's Encrypt (Recommended)

Requirements:
- Domain must resolve to your server's public IP
- Port 80 must be accessible from the internet
- No firewall blocking ACME challenges

### Custom Certificates

If using your own certificates:
- Place in `data/custom_ssl/` directory
- Supports PEM format
- Include full chain + private key

## Troubleshooting Prerequisites

### Docker won't start

```bash
# Check logs
sudo journalctl -u docker.service

# Verify kernel supports cgroup v2 (optional)
mount | grep cgroup
```

### Port already in use

```bash
# Check what's using port 80/443
sudo netstat -tlnp | grep -E ':80|:443'
sudo ss -tlnp | grep -E ':80|:443'

# Kill process or change port
sudo systemctl stop apache2  # If Apache is running
sudo systemctl stop nginx    # If Nginx is running
```

### Insufficient permissions

```bash
# Fix Docker socket permissions
sudo chmod 666 /var/run/docker.sock

# Or add user to docker group
sudo usermod -aG docker $USER
```

## Next Steps

Once prerequisites are met:

1. [Quick Start Guide](QUICKSTART.md) - Get running in 5 minutes
2. [Architecture Guide](ARCHITECTURE_GUIDE.md) - Choose your setup
3. [README.md](../README.md) - Full documentation
