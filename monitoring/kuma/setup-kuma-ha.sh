#!/bin/bash
# Setup Kuma for High Availability

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "  Kuma HA Setup"
echo "=========================================="
echo ""

cd "$(dirname "$0")/../.."

# Check if running as part of HA
if [ ! -f "ha-setup/.env" ]; then
    echo -e "${YELLOW}Warning: HA setup not detected${NC}"
    echo "Kuma HA works best with shared storage from HA setup."
    echo ""
fi

echo "Select Kuma backend:"
echo ""
echo "  1) SQLite (simple, shared via GlusterFS)"
echo "  2) PostgreSQL (better concurrency)"
echo ""
read -p "Choice [1-2]: " BACKEND

case $BACKEND in
    1)
        echo -e "${BLUE}Setting up Kuma with SQLite...${NC}"
        
        # Create kuma directory in shared storage
        mkdir -p ${SHARED_DATA_PATH:-./data}/kuma
        
        # Add to HA docker-compose
        cat >> ha-setup/docker-compose.ha.yml << 'EOF'

  # Uptime Kuma - Monitoring
  kuma:
    image: louislam/uptime-kuma:latest
    container_name: kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - ${SHARED_DATA_PATH:-./data}/kuma:/app/data
    networks:
      - proxy-network
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3001"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
        
        echo -e "${GREEN}✓ Kuma added to HA stack${NC}"
        echo ""
        echo "Start with:"
        echo "  cd ha-setup && docker compose -f docker-compose.ha.yml up -d"
        ;;
    
    2)
        echo -e "${BLUE}Setting up Kuma with PostgreSQL...${NC}"
        
        # Generate password
        KUMA_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
        
        # Add to HA .env
        echo "KUMA_DB_PASS=$KUMA_PASS" >> ha-setup/.env
        
        # Create directories
        mkdir -p ${SHARED_DATA_PATH:-./data}/kuma-uploads
        mkdir -p ${SHARED_DATA_PATH:-./data}/kuma-db
        
        # Add to HA docker-compose
        cat >> ha-setup/docker-compose.ha.yml << 'EOF'

  # Uptime Kuma with PostgreSQL
  kuma:
    image: louislam/uptime-kuma:latest
    container_name: kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - ${SHARED_DATA_PATH:-./data}/kuma-uploads:/app/data/upload
    environment:
      UPTIME_KUMA_DB_TYPE: postgres
      UPTIME_KUMA_DB_HOSTNAME: kuma-db
      UPTIME_KUMA_DB_PORT: 5432
      UPTIME_KUMA_DB_NAME: kuma
      UPTIME_KUMA_DB_USERNAME: kuma
      UPTIME_KUMA_DB_PASSWORD: ${KUMA_DB_PASS}
    networks:
      - proxy-network
      - kuma-db
    depends_on:
      - kuma-db

  kuma-db:
    image: postgres:16-alpine
    container_name: kuma-db
    restart: unless-stopped
    volumes:
      - ${SHARED_DATA_PATH:-./data}/kuma-db:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: kuma
      POSTGRES_USER: kuma
      POSTGRES_PASSWORD: ${KUMA_DB_PASS}
    networks:
      - kuma-db

networks:
  kuma-db:
    driver: bridge
EOF
        
        echo -e "${GREEN}✓ Kuma with PostgreSQL added to HA stack${NC}"
        echo ""
        echo "Database password saved to ha-setup/.env"
        ;;
    
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo -e "${GREEN}Kuma HA setup complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Start the stack:"
echo "   cd ha-setup"
echo "   docker compose -f docker-compose.ha.yml up -d"
echo ""
echo "2. Access Kuma on the floating IP:"
echo "   http://VIRTUAL_IP:3001"
echo ""
echo "3. Complete initial setup on the active controller"
echo ""
echo "4. Configure monitors for:"
echo "   - NPM: http://npm:81"
echo "   - Authentik: http://authentik-server:9000/-/health/"
echo "   - Spokes: ping 172.20.0.1, 172.21.0.1, etc."
echo ""
echo "5. Add notification channels (Slack, Email, etc.)"
echo ""
