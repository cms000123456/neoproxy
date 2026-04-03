#!/bin/bash

# NeoProxy Setup Script
# Sets up NPM + Authentik with optional inter-host VPN

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  NeoProxy Setup"
echo "  NPM + Authentik + Inter-Host VPN"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker not installed${NC}"
    exit 1
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p data/{npm,letsencrypt,authentik,postgresql,redis,npm/custom_locations}
mkdir -p nebula spokes control-panel/homer/assets
echo -e "${GREEN}✓ Directories created${NC}"

# Download Nebula
echo -e "${YELLOW}Checking Nebula...${NC}"
if [ ! -f "nebula/nebula" ]; then
    echo "Downloading Nebula..."
    curl -sL -o nebula.tar.gz "https://github.com/slackhq/nebula/releases/latest/download/nebula-linux-amd64.tar.gz"
    tar -xzf nebula.tar.gz -C nebula/
    rm nebula.tar.gz
    chmod +x nebula/nebula nebula/nebula-cert
    echo -e "${GREEN}✓ Nebula downloaded${NC}"
else
    echo -e "${GREEN}✓ Nebula already present${NC}"
fi

# Generate secrets if not exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Generating secrets...${NC}"
    cat > .env << EOF
# Authentik Secrets
PG_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d "=+/" | cut -c1-50)

# Hub Configuration (for inter-host setup)
HUB_PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_PUBLIC_IP")
EOF
    echo -e "${GREEN}✓ .env created${NC}"
fi

# Setup mode selection
echo ""
echo "Select setup mode:"
echo "  1) Standalone (single host only)"
echo "  2) Hub (main proxy + accepts remote hosts)"
echo "  3) Spoke (connects to a hub)"
echo ""
read -p "Choice [1-3]: " MODE

case $MODE in
    1)
        echo -e "${BLUE}Setting up STANDALONE mode...${NC}"
        docker compose up -d
        echo -e "${GREEN}✓ Standalone stack started${NC}"
        ;;
    
    2)
        echo -e "${BLUE}Setting up HUB mode...${NC}"
        
        # Get public IP
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")
        if [ -z "$PUBLIC_IP" ]; then
            read -p "Enter your public IP or domain: " PUBLIC_IP
        fi
        
        # Generate CA if needed
        if [ ! -f "nebula/ca.crt" ]; then
            echo "Generating Certificate Authority..."
            ./nebula/nebula-cert ca -name "NeoProxyNetwork"
            echo -e "${GREEN}✓ CA created${NC}"
            echo "  IMPORTANT: Backup nebula/ca.key securely!"
        fi
        
        # Generate lighthouse certificate
        if [ ! -f "nebula/lighthouse.crt" ]; then
            echo "Generating lighthouse certificate..."
            ./nebula/nebula-cert sign -name "lighthouse" -ip "10.8.0.1/24" -groups "lighthouse,hub"
            echo -e "${GREEN}✓ Lighthouse cert created${NC}"
        fi
        
        # Create lighthouse config
        sed "s/PUBLIC_IP/$PUBLIC_IP/g" nebula/config.lighthouse.yml.template > nebula/config.lighthouse.yml
        echo -e "${GREEN}✓ Lighthouse config created${NC}"
        
        # Start with hub profile
        docker compose --profile hub up -d
        echo -e "${GREEN}✓ Hub stack started${NC}"
        
        # Open firewall port
        echo ""
        echo -e "${YELLOW}Opening firewall port 4242/UDP...${NC}"
        if command -v ufw &> /dev/null; then
            sudo ufw allow 4242/udp || true
        elif command -v firewall-cmd &> /dev/null; then
            sudo firewall-cmd --add-port=4242/udp --permanent || true
            sudo firewall-cmd --reload || true
        fi
        
        echo ""
        echo -e "${GREEN}Hub is ready to accept spoke connections!${NC}"
        echo ""
        echo "Generate spoke configs with:"
        echo "  ./generate-spoke.sh <name> <subnet> <ip>"
        echo ""
        echo "Example:"
        echo "  ./generate-spoke.sh host1 172.20.0.0/16 10.8.0.2"
        ;;
    
    3)
        echo -e "${BLUE}Setting up SPOKE mode...${NC}"
        
        read -p "Enter hub public IP or domain: " HUB_IP
        read -p "Enter this spoke's name (e.g., host1): " SPOKE_NAME
        read -p "Enter Docker subnet (e.g., 172.20.0.0/16): " SPOKE_SUBNET
        read -p "Enter Nebula IP (e.g., 10.8.0.2): " NEBULA_IP
        
        # Check if certificates exist
        if [ ! -f "nebula/${SPOKE_NAME}.crt" ]; then
            echo -e "${YELLOW}WARNING: Certificate for ${SPOKE_NAME} not found!${NC}"
            echo "Run this on the HUB first:"
            echo "  ./generate-spoke.sh ${SPOKE_NAME} ${SPOKE_SUBNET} ${NEBULA_IP}"
            echo ""
            read -p "Press enter when certificates are ready..."
        fi
        
        # Create spoke config
        sed -e "s/PUBLIC_IP/$HUB_IP/g" \
            -e "s/SPOKE_NAME/$SPOKE_NAME/g" \
            nebula/config.spoke.yml.template > nebula/config.yml
        
        # Update docker-compose.spoke.yml with subnet
        sed -i "s|172.20.0.0/16|$SPOKE_SUBNET|g" docker-compose.spoke.yml
        
        # Start spoke
        docker compose -f docker-compose.spoke.yml up -d
        echo -e "${GREEN}✓ Spoke connected to hub${NC}"
        ;;
    
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Create generate-spoke script if not exists
if [ ! -f "generate-spoke.sh" ]; then
cat > generate-spoke.sh << 'SCRIPT'
#!/bin/bash
# Generate spoke configuration on the HUB

SPOKE_NAME=$1
SPOKE_SUBNET=$2
NEBULA_IP=$3

if [ -z "$SPOKE_NAME" ] || [ -z "$SPOKE_SUBNET" ] || [ -z "$NEBULA_IP" ]; then
    echo "Usage: ./generate-spoke.sh <name> <subnet> <nebula-ip>"
    echo "Example: ./generate-spoke.sh host1 172.20.0.0/16 10.8.0.2"
    exit 1
fi

if [ ! -f "nebula/nebula-cert" ]; then
    echo "Error: Nebula not found. Run setup first."
    exit 1
fi

# Generate certificate
./nebula/nebula-cert sign -name "$SPOKE_NAME" -ip "$NEBULA_IP/24" -groups "spoke,docker"

# Create spoke package
mkdir -p "spokes/$SPOKE_NAME/nebula"
cp "nebula/ca.crt" "spokes/$SPOKE_NAME/nebula/"
cp "nebula/${SPOKE_NAME}.crt" "spokes/$SPOKE_NAME/nebula/"
cp "nebula/${SPOKE_NAME}.key" "spokes/$SPOKE_NAME/nebula/"

# Get hub IP from config
HUB_IP=$(grep "10.8.0.1" nebula/config.lighthouse.yml | head -1 | sed 's/.*\[\"\([^\"]*\\)\"\].*/\1/')

# Create spoke config
sed -e "s/PUBLIC_IP/$HUB_IP/g" \
    -e "s/SPOKE_NAME/$SPOKE_NAME/g" \
    nebula/config.spoke.yml.template > "spokes/$SPOKE_NAME/nebula/config.yml"

# Copy docker-compose
cp docker-compose.spoke.yml "spokes/$SPOKE_NAME/"
sed -i "s|172.20.0.0/16|$SPOKE_SUBNET|g" "spokes/$SPOKE_NAME/docker-compose.spoke.yml"

# Create README
cat > "spokes/$SPOKE_NAME/README.txt" << EOF
SPOKE: $SPOKE_NAME
=================
Nebula IP: $NEBULA_IP
Docker Subnet: $SPOKE_SUBNET
Hub: $HUB_IP

Deploy to remote host:
  scp -r spokes/$SPOKE_NAME user@remote:/opt/neoproxy/
  ssh user@remote 'cd /opt/neoproxy && docker compose up -d'

Container will be accessible from hub at:
  ${SPOKE_SUBNET%.*/*}.2, .3, .4, etc.
EOF

echo "✓ Spoke '$SPOKE_NAME' created in spokes/$SPOKE_NAME/"
echo "  Nebula IP: $NEBULA_IP"
echo "  Docker subnet: $SPOKE_SUBNET"
SCRIPT
chmod +x generate-spoke.sh
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Setup complete!${NC}"
echo "=========================================="
echo ""

case $MODE in
    1)
        echo "Services:"
        echo "  NPM:        http://localhost:81"
        echo "  Authentik:  http://localhost:9000"
        ;;
    2)
        echo "Hub Services:"
        echo "  NPM:        http://localhost:81"
        echo "  Authentik:  http://localhost:9000"
        echo "  Nebula VPN: Port 4242/UDP"
        echo ""
        echo "Next: Generate spoke configs"
        echo "  ./generate-spoke.sh host1 172.20.0.0/16 10.8.0.2"
        ;;
    3)
        echo "Spoke connected! Services on this host"
        echo "are now accessible from the hub via VPN."
        ;;
esac

echo ""
