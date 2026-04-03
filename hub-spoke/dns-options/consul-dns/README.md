# Consul DNS Setup

Automatic container discovery with DNS resolution.

## How It Works

1. **Registrator** watches Docker socket for container start/stop
2. When container starts, it registers with Consul with its IP and ports
3. **Consul DNS** responds to queries like `whoami.service.consul → 172.20.0.2`
4. **NPM** uses Consul as DNS server to resolve container names

## Setup

### Hub

```bash
cd hub-spoke/dns-options/consul-dns
docker compose -f docker-compose.hub.yml up -d
```

Access Consul UI: http://hub-ip:8500

### Spoke

```bash
# Set the host IP for the subnet
export HOST_IP=172.20.0.1  # Gateway IP of this spoke's network

docker compose -f docker-compose.spoke.yml up -d
```

## DNS Names

Containers get DNS records automatically:

| Container | Environment Variable | DNS Name | Resolves To |
|-----------|---------------------|----------|-------------|
| whoami | SERVICE_NAME=whoami | `whoami.service.consul` | Container IP |
| webapp | SERVICE_NAME=webapp | `webapp.service.consul` | Container IP |

## NPM Configuration

In NPM, use Consul DNS names:

| Domain | Forward Hostname | Port |
|--------|-----------------|------|
| `whoami.example.com` | `whoami.service.consul` | `80` |
| `site.example.com` | `webapp.service.consul` | `80` |

## Testing DNS

From hub:
```bash
# Query Consul DNS
docker compose exec npm nslookup whoami.service.consul 10.8.0.1

# Should return the container IP from spoke 1
dig @10.8.0.1 whoami.service.consul
```

## Custom Names

You can also register custom DNS entries:

```bash
# From any spoke or hub
curl -X PUT http://10.8.0.1:8500/v1/catalog/register \
  -d '{
    "Node": "spoke1",
    "Address": "172.20.0.2",
    "Service": {
      "Service": "myapp",
      "Port": 8080
    }
  }'
```

Now `myapp.service.consul` resolves to `172.20.0.2:8080`.
