#!/bin/bash
# Setup script for HUB (Main Host with NPM)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  Hub Setup - Main Proxy Host"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "Error: Docker not installed"
    exit 1
fi

# Create directories
mkdir -p {nebula,data/{npm,letsencrypt,authentik,postgresql,redis},spokes}

# Download Nebula
echo -e "${YELLOW}Downloading Nebula...${NC}"
if [ ! -f "nebula/nebula" ]; then
    curl -L -o nebula.tar.gz "https://github.com/slackhq/nebula/releases/latest/download/nebula-linux-amd64.tar.gz"
    tar -xzf nebula.tar.gz -C nebula/
    rm nebula.tar.gz
    chmod +x nebula/nebula nebula/nebula-cert
fi
echo -e "${GREEN}✓ Nebula downloaded${NC}"

# Generate CA
if [ ! -f "nebula/ca.crt" ]; then
    echo -e "${YELLOW}Generating Certificate Authority...${NC}"
    ./nebula/nebula-cert ca -name "HubSpokeNetwork"
    echo -e "${GREEN}✓ CA created${NC}"
    echo "  IMPORTANT: Backup ca.key securely!"
fi

# Generate lighthouse certificate
if [ ! -f "nebula/lighthouse.crt" ]; then
    echo -e "${YELLOW}Generating Lighthouse certificate...${NC}"
    ./nebula/nebula-cert sign -name "lighthouse" -ip "10.8.0.1/24" -groups "lighthouse,hub"
    echo -e "${GREEN}✓ Lighthouse cert created${NC}"
fi

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me || echo "YOUR_PUBLIC_IP")

echo ""
echo "Public IP: $PUBLIC_IP"
echo ""

# Create lighthouse config
cat > nebula/config.lighthouse.yml << EOF
pki:
  ca: /config/ca.crt
  cert: /config/lighthouse.crt
  key: /config/lighthouse.key

static_host_map:
  "10.8.0.1": ["$PUBLIC_IP:4242"]

lighthouse:
  am_lighthouse: true
  interval: 60
  serve_dns: true
  dns:
    host: 0.0.0.0
    port: 53

listen:
  host: 0.0.0.0
  port: 4242

punchy:
  punch: true
  respond: true

relay:
  am_relay: true
  use_relays: true

tun:
  disabled: false
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300
  routes:
    - mtu: 1300
      route: 172.20.0.0/16
    - mtu: 1300
      route: 172.21.0.0/16
    - mtu: 1300
      route: 172.22.0.0/16
    - mtu: 1300
      route: 172.23.0.0/16
    - mtu: 1300
      route: 172.24.0.0/16

logging:
  level: info
  format: text

firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    - port: any
      proto: any
      host: any
EOF

echo -e "${GREEN}✓ Lighthouse config created${NC}"

# Create .env
if [ ! -f ".env" ]; then
    cat > .env << EOF
# Authentik Secrets
PG_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d "=+/" | cut -c1-50)

# Nebula
NEBULA_PUBLIC_IP=$PUBLIC_IP
EOF
    echo -e "${GREEN}✓ .env created${NC}"
fi

# Create generate-spoke.sh
cat > generate-spoke.sh << 'SCRIPT'
#!/bin/bash
# Generate spoke configuration for a remote host

SPOKE_NAME=$1
DOCKER_SUBNET=$2
SPOKE_IP=$3

if [ -z "$SPOKE_NAME" ] || [ -z "$DOCKER_SUBNET" ] || [ -z "$SPOKE_IP" ]; then
    echo "Usage: ./generate-spoke.sh <name> <docker-subnet> <nebula-ip>"
    echo "Example: ./generate-spoke.sh host1 172.20.0.0/16 10.8.0.2"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Generate certificate
./nebula/nebula-cert sign -name "$SPOKE_NAME" -ip "$SPOKE_IP/24" -groups "spoke,docker"

# Create spoke directory
mkdir -p "spokes/$SPOKE_NAME/nebula"

# Copy certificates
cp "nebula/ca.crt" "spokes/$SPOKE_NAME/nebula/"
cp "nebula/${SPOKE_NAME}.crt" "spokes/$SPOKE_NAME/nebula/"
cp "nebula/${SPOKE_NAME}.key" "spokes/$SPOKE_NAME/nebula/"

# Get lighthouse IP
LIGHTHOUSE_IP=$(grep "10.8.0.1" nebula/config.lighthouse.yml | head -1 | sed 's/.*\"\(.*\)\".*/\1/')

# Create spoke config
cat > "spokes/$SPOKE_NAME/nebula/config.yml" << EOF
pki:
  ca: /config/ca.crt
  cert: /config/${SPOKE_NAME}.crt
  key: /config/${SPOKE_NAME}.key

static_host_map:
  "10.8.0.1": ["$LIGHTHOUSE_IP"]

lighthouse:
  hosts:
    - "10.8.0.1"
  interval: 60

listen:
  host: 0.0.0.0
  port: 0

punchy:
  punch: true
  respond: true

relay:
  am_relay: false
  use_relays: true
  relays:
    - 10.8.0.1

tun:
  disabled: false
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    - port: any
      proto: any
      host: any
EOF

# Create spoke docker-compose
cat > "spokes/$SPOKE_NAME/docker-compose.yml" << EOF
version: "3.8"

services:
  nebula:
    image: ghcr.io/slackhq/nebula:latest
    container_name: nebula
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - ./nebula:/config:ro
    command: -config /config/config.yml
    networks:
      - nebula-net
      - app-network

  # Example app - replace with your services
  whoami:
    image: traefik/whoami:latest
    container_name: whoami
    networks:
      - app-network
    # NO ports exposed - accessible only via VPN

networks:
  app-network:
    driver: bridge
    ipam:
      config:
        - subnet: $DOCKER_SUBNET

  nebula-net:
    driver: bridge
EOF

# Create README for spoke
cat > "spokes/$SPOKE_NAME/README.txt" << EOF
SPOKE: $SPOKE_NAME
=================
Nebula IP: $SPOKE_IP
Docker Subnet: $DOCKER_SUBNET

To deploy:
1. Copy this folder to remote host
2. Run: docker compose up -d

The nebula container will:
- Connect to lighthouse at $LIGHTHOUSE_IP
- Advertise routes for $DOCKER_SUBNET
- Allow NPM on hub to reach containers

Container IPs will be in $DOCKER_SUBNET range.
First container typically gets: ${DOCKER_SUBNET%.*/*}.2
EOF

echo "✓ Spoke '$SPOKE_NAME' created in spokes/$SPOKE_NAME/"
echo "  Nebula IP: $SPOKE_IP"
echo "  Docker subnet: $DOCKER_SUBNET"
SCRIPT

chmod +x generate-spoke.sh

echo -e "${GREEN}✓ generate-spoke.sh created${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}Hub setup complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Start the hub:"
echo "   docker compose up -d"
echo ""
echo "2. Open firewall port 4242/UDP:"
echo "   sudo ufw allow 4242/udp"
echo ""
echo "3. Generate spoke configs:"
echo "   ./generate-spoke.sh host1 172.20.0.0/16 10.8.0.2"
echo "   ./generate-spoke.sh host2 172.21.0.0/16 10.8.0.3"
echo ""
echo "4. Deploy spokes:"
echo "   scp -r spokes/host1 user@remote1:~/spoke"
echo "   ssh user@remote1 'cd ~/spoke && docker compose up -d'"
echo ""
echo "5. In NPM, proxy to container IPs:"
echo "   http://172.20.0.2:80  (host1 whoami)"
echo "   http://172.21.0.2:80  (host2 whoami)"
echo ""
