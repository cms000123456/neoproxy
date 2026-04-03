#!/bin/bash
# Check hub and spoke connectivity

echo "=========================================="
echo "  Hub-Spoke Network Status"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running on hub
if [ -f "docker-compose.yml" ] && grep -q "nebula-lighthouse" docker-compose.yml 2>/dev/null; then
    echo -e "${YELLOW}Running on HUB${NC}"
    echo ""
    
    # Check lighthouse
    echo "Nebula Lighthouse:"
    if docker compose ps nebula-lighthouse | grep -q "running"; then
        echo -e "  Status: ${GREEN}Running${NC}"
        echo -n "  VPN IP: "
        docker compose exec nebula-lighthouse ip addr show nebula1 2>/dev/null | grep "inet " | awk '{print $2}' || echo "N/A"
    else
        echo -e "  Status: ${RED}Not running${NC}"
    fi
    echo ""
    
    # Check NPM
    echo "Nginx Proxy Manager:"
    if docker compose ps npm | grep -q "running"; then
        echo -e "  Status: ${GREEN}Running${NC}"
    else
        echo -e "  Status: ${RED}Not running${NC}"
    fi
    echo ""
    
    # Check Nebula status from lighthouse
    echo "Connected Spokes:"
    docker compose exec nebula-lighthouse nebula-cert sign -list 2>/dev/null | grep -E "^\s+" | head -20 || echo "  (cert list not available)"
    echo ""
    
    # Show routes
    echo "Routing table (Nebula subnets):"
    ip route | grep "10.8.0" || true
    ip route | grep "172.2" || true
    echo ""
    
    # Test connectivity to common spoke IPs
    echo "Connectivity tests:"
    for ip in 10.8.0.2 10.8.0.3 10.8.0.4 172.20.0.2 172.21.0.2; do
        if ping -c 1 -W 2 $ip &>/dev/null; then
            echo -e "  $ip: ${GREEN}REACHABLE${NC}"
        else
            echo -e "  $ip: ${RED}unreachable${NC}"
        fi
    done

# Check if running on spoke
elif [ -f "docker-compose.yml" ] && grep -q "app-network" docker-compose.yml 2>/dev/null; then
    echo -e "${YELLOW}Running on SPOKE${NC}"
    echo ""
    
    # Check nebula
    echo "Nebula Client:"
    if docker compose ps nebula | grep -q "running"; then
        echo -e "  Status: ${GREEN}Running${NC}"
        echo -n "  VPN IP: "
        docker compose exec nebula ip addr show nebula1 2>/dev/null | grep "inet " | awk '{print $2}' || echo "N/A"
        echo -n "  Lighthouse: "
        docker compose exec nebula ping -c 1 10.8.0.1 &>/dev/null && echo -e "${GREEN}Connected${NC}" || echo -e "${RED}Disconnected${NC}"
    else
        echo -e "  Status: ${RED}Not running${NC}"
    fi
    echo ""
    
    # Show local containers
    echo "Local containers:"
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -v nebula || true
    echo ""
    
    # Show container IPs
    echo "Container IPs:"
    docker network inspect app-network --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}' 2>/dev/null || echo "  (network not found)"
    echo ""
    
    # Show routes being advertised
    echo "Routes advertised to hub:"
    docker network inspect app-network --format '{{range .IPAM.Config}}{{.Subnet}}{{println}}{{end}}' 2>/dev/null || true
fi

echo ""
echo "=========================================="
