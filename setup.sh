#!/bin/bash

# NeoProxy Setup Script
# Generates secure secrets and prepares environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  NeoProxy - Setup Script"
echo "  NPM + Authentik with MFA"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: openssl is required but not installed.${NC}"
    exit 1
fi

# Generate secure secrets
echo -e "${YELLOW}Generating secure secrets...${NC}"

PG_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d "=+/" | cut -c1-50)

# Backup existing .env if present
if [ -f ".env" ]; then
    cp .env ".env.backup.$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}Existing .env backed up.${NC}"
fi

# Create .env file
cat > .env << EOF
# PostgreSQL Configuration
PG_PASS=${PG_PASS}
PG_USER=authentik
PG_DB=authentik

# Authentik Secret Key (50+ characters)
AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}

# Domain Configuration - CHANGE THESE
DOMAIN=yourdomain.com
AUTH_SUBDOMAIN=auth

# Email Configuration (optional - uncomment and fill for email support)
# SMTP_HOST=smtp.gmail.com
# SMTP_PORT=587
# SMTP_USERNAME=your_email@gmail.com
# SMTP_PASSWORD=your_app_password
# SMTP_USE_TLS=true
# SMTP_USE_SSL=false
# DEFAULT_FROM_EMAIL=noreply@yourdomain.com
EOF

echo -e "${GREEN}✓ Generated secure secrets${NC}"
echo ""

# Create necessary directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p data/{npm,letsencrypt,postgresql,redis,authentik/{media,certs,custom-templates}}
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Set proper permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chmod -R 755 data/
# PostgreSQL needs specific ownership (will be set by container)
echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

# Pull images
echo -e "${YELLOW}Pulling Docker images...${NC}"
docker compose pull
echo -e "${GREEN}✓ Images pulled${NC}"
echo ""

echo "=========================================="
echo -e "${GREEN}Setup complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. ${YELLOW}Edit .env file${NC} and update:"
echo "   - DOMAIN (your domain name)"
echo "   - AUTH_SUBDOMAIN (subdomain for Authentik)"
echo "   - Optional: SMTP settings for email"
echo ""
echo "2. ${YELLOW}Start services:${NC}"
echo "   docker compose up -d"
echo ""
echo "3. ${YELLOW}Access the admin interfaces:${NC}"
echo "   NPM:        http://localhost:81"
echo "              (default: admin@example.com / changeme)"
echo ""
echo "   Authentik:  http://localhost:9000"
echo "              (create admin account on first run)"
echo ""
echo "4. ${YELLOW}Configure DNS:${NC}"
echo "   Point your domain and auth subdomain to this server"
echo ""
echo "5. ${YELLOW}Follow the README.md${NC} for full configuration"
echo ""
echo "=========================================="
