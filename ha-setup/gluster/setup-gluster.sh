#!/bin/bash
# Setup GlusterFS for shared storage across controllers

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
CONTROLLERS=("$@")
VOLUME_NAME="neoproxy-data"
BRICK_PATH="/data/gluster/brick"
MOUNT_PATH="/mnt/neoproxy-data"

if [ ${#CONTROLLERS[@]} -lt 2 ]; then
    echo "Usage: ./setup-gluster.sh controller1 controller2 [controller3]"
    echo "Example: ./setup-gluster.sh 192.168.1.10 192.168.1.11 192.168.1.12"
    exit 1
fi

echo "=========================================="
echo "  GlusterFS Setup for NeoProxy HA"
echo "=========================================="
echo "Controllers: ${CONTROLLERS[@]}"
echo ""

# Install GlusterFS
echo -e "${YELLOW}Installing GlusterFS...${NC}"
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y glusterfs-server
elif command -v yum &> /dev/null; then
    sudo yum install -y glusterfs-server
else
    echo -e "${RED}Unsupported package manager${NC}"
    exit 1
fi

sudo systemctl enable --now glusterd

# Create brick directory
echo -e "${YELLOW}Creating brick directory...${NC}"
sudo mkdir -p $BRICK_PATH

# Get hostname
MY_IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}This host IP: $MY_IP${NC}"

# If this is the first controller, probe peers and create volume
if [ "$MY_IP" = "${CONTROLLERS[0]}" ]; then
    echo -e "${YELLOW}This is the first controller - setting up cluster...${NC}"
    
    # Probe other controllers
    for controller in "${CONTROLLERS[@]:1}"; do
        echo "Probing $controller..."
        sudo gluster peer probe $controller
    done
    
    # Wait for peers to connect
    echo "Waiting for peers..."
    sleep 5
    
    # Check peer status
    sudo gluster peer status
    
    # Create replicated volume
    echo -e "${YELLOW}Creating replicated volume...${NC}"
    
    BRICKS=""
    for controller in "${CONTROLLERS[@]}"; do
        BRICKS="$BRICKS $controller:$BRICK_PATH"
    done
    
    sudo gluster volume create $VOLUME_NAME \
        replica ${#CONTROLLERS[@]} \
        transport tcp \
        $BRICKS \
        force
    
    # Start volume
    sudo gluster volume start $VOLUME_NAME
    
    # Enable options for better performance with SQLite
    echo -e "${YELLOW}Tuning volume for database workloads...${NC}"
    sudo gluster volume set $VOLUME_NAME network.ping-timeout 5
    sudo gluster volume set $VOLUME_NAME performance.write-behind off
    sudo gluster volume set $VOLUME_NAME performance.open-behind off
    sudo gluster volume set $VOLUME_NAME performance.quick-read off
    sudo gluster volume set $VOLUME_NAME performance.read-ahead off
    sudo gluster volume set $VOLUME_NAME performance.io-cache off
    sudo gluster volume set $VOLUME_NAME performance.stat-prefetch off
    
    echo -e "${GREEN}Volume created and started!${NC}"
    sudo gluster volume info
else
    echo -e "${YELLOW}Waiting for first controller to set up cluster...${NC}"
    echo "Run this script on ${CONTROLLERS[0]} first, then run on other controllers."
fi

# Mount the volume
echo -e "${YELLOW}Mounting GlusterFS volume...${NC}"
sudo mkdir -p $MOUNT_PATH

# Add to fstab if not already there
if ! grep -q "$MOUNT_PATH" /etc/fstab; then
    echo "${CONTROLLERS[0]}:/$VOLUME_NAME $MOUNT_PATH glusterfs defaults,_netdev,backup-volfile-servers=${CONTROLLERS[1]} 0 0" | sudo tee -a /etc/fstab
fi

# Mount
sudo mount -t glusterfs ${CONTROLLERS[0]}:/$VOLUME_NAME $MOUNT_PATH

# Create data directories
echo -e "${YELLOW}Creating data directories...${NC}"
sudo mkdir -p $MOUNT_PATH/{npm,letsencrypt,authentik,postgresql,redis}
sudo chmod 755 $MOUNT_PATH/*

echo ""
echo "=========================================="
echo -e "${GREEN}GlusterFS setup complete!${NC}"
echo "=========================================="
echo ""
echo "Volume mounted at: $MOUNT_PATH"
echo ""
echo "Check status:"
echo "  sudo gluster volume status"
echo "  sudo gluster volume info"
echo "  df -h $MOUNT_PATH"
echo ""
echo "To use in docker-compose, set:"
echo "  SHARED_DATA_PATH=/mnt/neoproxy-data"
