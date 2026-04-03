# WireGuard Mesh - Self-Hosted Option

Direct WireGuard tunnels between hosts. More control, but manual configuration.

## Overview

```
┌─────────────────────────────────────┐
│      WireGuard Full Mesh            │
│                                     │
│   ┌─────┐      ┌─────┐      ┌─────┐│
│   │HostA│◄────►│HostB│◄────►│HostC││
│   │ WG  │      │ WG  │      │ WG  ││
│   └──┬──┘      └──┬──┘      └──┬──┘│
│      │            │            │   │
│   10.8.1.1    10.8.1.2    10.8.1.3 │
└─────────────────────────────────────┘
```

## Quick Setup

### 1. Generate Keys

```bash
# On each host, generate WireGuard keys
wg genkey | tee privatekey | wg pubkey > publickey
```

### 2. Docker Compose

Add to each host:

```yaml
services:
  wireguard:
    image: linuxserver/wireguard:latest
    container_name: wireguard
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - ./wireguard:/config
      - /lib/modules:/lib/modules:ro
    ports:
      - "51820:51820/udp"
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    networks:
      - proxy-network
      - wg-net

networks:
  wg-net:
    driver: bridge
    ipam:
      config:
        - subnet: 10.8.1.0/24
```

### 3. Configuration Files

**Host A** (`wireguard/wg0.conf`):
```ini
[Interface]
PrivateKey = <HostA_PRIVATE_KEY>
Address = 10.8.1.1/24
ListenPort = 51820
DNS = 1.1.1.1

[Peer]
# Host B
PublicKey = <HostB_PUBLIC_KEY>
AllowedIPs = 10.8.1.2/32, 172.20.0.0/16  # WG IP + Docker network
Endpoint = hostb.example.com:51820
PersistentKeepalive = 25

[Peer]
# Host C
PublicKey = <HostC_PUBLIC_KEY>
AllowedIPs = 10.8.1.3/32, 172.21.0.0/16
Endpoint = hostc.example.com:51820
PersistentKeepalive = 25
```

**Host B** (`wireguard/wg0.conf`):
```ini
[Interface]
PrivateKey = <HostB_PRIVATE_KEY>
Address = 10.8.1.2/24
ListenPort = 51820

[Peer]
# Host A
PublicKey = <HostA_PUBLIC_KEY>
AllowedIPs = 10.8.1.1/32, 172.20.0.0/16
Endpoint = hosta.example.com:51820
PersistentKeepalive = 25
```

### 4. Enable IP Forwarding

```bash
# On each host
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Make permanent
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
```

## NPM Configuration

In NPM, use WireGuard IPs:

| Domain | Forward IP | Port |
|--------|------------|------|
| `app1.yourdomain.com` | `10.8.1.2` | `8080` |
| `app2.yourdomain.com` | `10.8.1.3` | `8080` |

## Routing Docker Networks

To route entire Docker networks through WireGuard:

```bash
# On Host A - route to Host B's Docker network
sudo ip route add 172.20.0.0/16 via 10.8.1.2

# Or use iptables for NAT
sudo iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
```

## Comparison with Tailscale

| Feature | WireGuard | Tailscale |
|---------|-----------|-----------|
| Setup | Manual | Automatic |
| Encryption | ✅ WireGuard | ✅ WireGuard |
| Key management | Manual | Automatic |
| NAT traversal | Manual | Automatic |
| Mobile apps | Official | Official |
| Cost | Free | Free tier |
| Self-hosted | ✅ Yes | Partial |
