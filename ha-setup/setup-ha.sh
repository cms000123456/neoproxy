#!/bin/bash
# High Availability Setup Script for NeoProxy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "  NeoProxy High Availability Setup"
echo "=========================================="
echo ""

# Check if running as root for some operations
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Note: Some operations may require sudo${NC}"
fi

# Menu
echo "Select setup option:"
echo ""
echo "  1) Setup shared storage (GlusterFS)"
echo "  2) Configure this controller as MASTER"
echo "  3) Configure this controller as BACKUP"
echo "  4) Start HA stack"
echo "  5) Check HA status"
echo ""
read -p "Choice [1-5]: " CHOICE

case $CHOICE in
    1)
        echo -e "${BLUE}Setting up GlusterFS shared storage...${NC}"
        echo ""
        read -p "Enter controller IPs (space-separated): " -a CONTROLLERS
        ./gluster/setup-gluster.sh "${CONTROLLERS[@]}"
        ;;
    
    2)
        echo -e "${BLUE}Configuring as MASTER controller...${NC}"
        
        # Create .env
        if [ ! -f ".env" ]; then
            cat > .env << EOF
# MASTER Controller Configuration
CONTROLLER_ROLE=master
ROUTER_ID=51
PRIORITY=100
INTERFACE=eth0
VIRTUAL_IP=203.0.113.10
SHARED_DATA_PATH=/mnt/neoproxy-data
PG_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d "=+/" | cut -c1-50)
EOF
            echo -e "${GREEN}✓ Created .env for MASTER${NC}"
        fi
        
        # Copy keepalived config
        cp keepalived/keepalived-master.conf keepalived/keepalived.conf
        
        # Load .env values into keepalived config
        source .env
        sed -i "s/203.0.113.10/$VIRTUAL_IP/g" keepalived/keepalived.conf
        sed -i "s/eth0/$INTERFACE/g" keepalived/keepalived.conf
        sed -i "s/priority 100/priority $PRIORITY/g" keepalived/keepalived.conf
        
        echo -e "${GREEN}✓ Keepalived configured for MASTER${NC}"
        echo ""
        echo "Edit .env to customize settings, then run:"
        echo "  ./setup-ha.sh  # Start HA stack"
        ;;
    
    3)
        echo -e "${BLUE}Configuring as BACKUP controller...${NC}"
        
        read -p "Backup priority (90=first backup, 80=second): " BACKUP_PRIORITY
        read -p "Virtual IP (must match master): " VIRTUAL_IP
        
        # Create .env
        if [ ! -f ".env" ]; then
            cat > .env << EOF
# BACKUP Controller Configuration
CONTROLLER_ROLE=backup
ROUTER_ID=51
PRIORITY=$BACKUP_PRIORITY
INTERFACE=eth0
VIRTUAL_IP=$VIRTUAL_IP
SHARED_DATA_PATH=/mnt/neoproxy-data
PG_PASS=USE_SAME_AS_MASTER
AUTHENTIK_SECRET_KEY=USE_SAME_AS_MASTER
EOF
            echo -e "${YELLOW}⚠️  IMPORTANT: Update PG_PASS and AUTHENTIK_SECRET_KEY to match MASTER!${NC}"
            echo -e "${GREEN}✓ Created .env for BACKUP${NC}"
        fi
        
        # Copy keepalived config
        cp keepalived/keepalived-backup.conf keepalived/keepalived.conf
        
        # Load .env values into keepalived config
        source .env
        sed -i "s/203.0.113.10/$VIRTUAL_IP/g" keepalived/keepalived.conf
        sed -i "s/eth0/$INTERFACE/g" keepalived/keepalived.conf
        sed -i "s/priority 90/priority $PRIORITY/g" keepalived/keepalived.conf
        
        echo -e "${GREEN}✓ Keepalived configured for BACKUP${NC}"
        ;;
    
    4)
        echo -e "${BLUE}Starting HA stack...${NC}"
        
        # Check prerequisites
        if [ ! -f ".env" ]; then
            echo -e "${RED}Error: .env not found. Run setup first.${NC}"
            exit 1
        fi
        
        if [ ! -f "keepalived/keepalived.conf" ]; then
            echo -e "${RED}Error: keepalived.conf not found. Run setup first.${NC}"
            exit 1
        fi
        
        # Create required directories
        mkdir -p /mnt/neoproxy-data/{npm,letsencrypt,authentik,postgresql,redis}
        
        # Start stack
        docker compose -f docker-compose.ha.yml --profile hub up -d
        
        echo -e "${GREEN}✓ HA stack started!${NC}"
        echo ""
        echo "Checking status..."
        sleep 3
        docker compose -f docker-compose.ha.yml ps
        ;;
    
    5)
        echo -e "${BLUE}Checking HA status...${NC}"
        echo ""
        
        echo "Container Status:"
        docker compose -f docker-compose.ha.yml ps
        
        echo ""
        echo "Keepalived Status:"
        docker compose -f docker-compose.ha.yml logs --tail=10 keepalived
        
        echo ""
        echo "Virtual IP Assignment:"
        ip addr show | grep -E "(eth0|ens|enp)" -A 5 | grep "inet " || echo "Check with: ip addr show"
        
        echo ""
        echo "Shared Storage Mount:"
        df -h /mnt/neoproxy-data 2>/dev/null || echo "Not mounted at /mnt/neoproxy-data"
        ;;
    
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
