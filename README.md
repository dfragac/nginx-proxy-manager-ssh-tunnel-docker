# Nginx Proxy Manager with SSH Tunnel

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Nginx](https://img.shields.io/badge/nginx-%23009639.svg?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org/)
[![SSH](https://img.shields.io/badge/SSH-4D4D4D?style=for-the-badge&logo=openssh&logoColor=white)](https://www.openssh.com/)

A Docker container that extends the popular [Nginx Proxy Manager](https://nginxproxymanager.com/) with built-in SSH tunneling capabilities. This solution allows you to securely expose your local services through a remote server using SSH reverse tunnels, eliminating the need for public IP addresses or complex firewall configurations.

⚠️ **Warning**: This project is intended for advanced users familiar with Docker, Nginx, and SSH. Ensure you understand the security implications of exposing services over the internet.

⚠️ **Disclaimer**: This project is not affiliated with or endorsed by the original Nginx Proxy Manager developers. It is a personal extension that adds SSH tunneling functionality.

ℹ️ **Note regarding limitations**: There's a caveat regarding the use of this container. It is designed to work with a remote server that has SSH access. The SSH tunnel is established from the container to the remote server, allowing you to expose local services securely. If you need to use lower ports (like 80 or 443) on the remote server, you must ensure that the remote server allows SSH reverse tunneling and that the necessary ports are open. SSH tunneling does not propagate the original IP address of the client, so all requests will appear to come from the remote server's IP or localhost IP. This is a common limitation of SSH reverse tunnels.

## 🚀 Features

- **Full Nginx Proxy Manager functionality** - Complete web-based proxy management (including SSL certificate management, access control, and more... see [Nginx Proxy Manager](https://nginxproxymanager.com/))
- **Automatic SSH tunneling** - Establishes and maintains SSH reverse tunnels
- **SSL/TLS support** - Let's Encrypt integration through tunneled connections
- **Self-healing tunnels** - Automatic reconnection and health monitoring
- **SSH key management** - Automatic key generation and deployment
- **Password or key-based authentication** - Flexible SSH authentication methods
- **Configurable monitoring** - Customizable health check intervals and failure thresholds
- **Docker Compose ready** - Easy deployment with provided configuration

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Environment Variables](#environment-variables)
- [Volume Mapping](#volume-mapping)
- [SSH Key Management](#ssh-key-management)
- [Monitoring and Logs](#monitoring-and-logs)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

## 📋 Prerequisites

- Docker and Docker Compose installed
- A remote server with SSH access (VPS, cloud instance, etc.). Its possible to use the cheapest VPS available, it will no require much (if any) resources.
- SSH access to the remote server (password or key-based)
- Basic understanding of Docker networking and SSH

## 🚀 Quick Start

1. **Clone or download** this repository to your local machine.

2. **Edit the docker-compose.yml** file and configure the required environment variables and ports. You can use the comments in the file as a guide. Here is an example of the minimal configuration:

```yaml
ports:
  - '81:81' # Nginx Proxy Manager admin interface
environment:
  SSH_SERVER: 'your-server.example.com'  # Your remote server hostname/IP
```

3. **Start the container:**

```bash
docker-compose up -d
```

4. **Wait for the container to initialize**. It may take a few moments for the SSH tunnel to establish and for Nginx Proxy Manager to become available. You can check the logs with:

```bash
docker-compose logs -f
```

5. **Access the admin interface** at `http://localhost:81`

6. **Configure Nginx Proxy Manager:** Folow the instructions well documented in the [Nginx Proxy Manager documentation](https://nginxproxymanager.com/guide/) to set up your proxies, SSL certificates, and other configurations.

> ⚠️ **Important**: Change the default admin credentials immediately after first login! 😉

## ⚙️ Configuration

The container is configured entirely through environment variables in the `docker-compose.yml` file (You can use, if you prefer, set a `.env` on the root folder of the project to manage your environment variables). This allows you to customize the SSH tunnel settings, Nginx Proxy Manager ports, and other options without modifying the Dockerfile or entrypoint scripts.

The container uses the `s6-overlay` (Used by the original Nginx Proxy Manager docker image) for process management and service supervision, ensuring that the SSH tunnel is established before Nginx Proxy Manager starts.

## 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_SERVER` | **Required** | Remote server hostname or IP address |
| `SSH_PORT` | `22` | SSH server port |
| `SSH_USER` | `root` | SSH username for authentication |
| `SSH_PASSWORD` | `null` | SSH password (optional if using keys) |
| `SSH_CHECK_INTERVAL` | `60` | Tunnel health check interval (seconds) |
| `SSH_MAX_FAILURES` | `5` | Max consecutive failures before error |
| `LOCAL_HTTP_PORT` | `80` | Local HTTP port to tunnel |
| `LOCAL_HTTPS_PORT` | `443` | Local HTTPS port to tunnel |
| `REMOTE_HTTP_PORT` | `80` | Remote HTTP port binding |
| `REMOTE_HTTPS_PORT` | `443` | Remote HTTPS port binding |
| `DISABLE_IPV6` | `false` | Disable IPv6 in Nginx if needed |

## 💾 Volume Mapping

The following volumes can be mapped for data persistence:

```yaml
volumes:
  - ./data:/data # Nginx Proxy Manager data
  - ./letsencrypt:/etc/letsencrypt  # SSL certificates
  - ./ssh-tunnel/keys:/ssh-tunnel/keys # SSH keys persistence
```

### Volume Descriptions

- **`./data`** - Contains all Nginx Proxy Manager configuration, databases, and logs
- **`./letsencrypt`** - Stores Let's Encrypt SSL certificates
- **`./ssh-tunnel/keys`** - SSH key storage for tunnel authentication

## 🔐 SSH Key Management

The container handles SSH key management automatically:

### Automatic Key Generation

If no SSH keys exist, the container will:
1. Generate a new RSA 4096-bit key pair
2. Display the public key for manual installation
3. Optionally copy the key automatically (if password provided)

### Manual Key Installation

You can ssh into the remote server and copy the public key shown in the logs directly into the `~/.ssh/authorized_keys` file or, follow these steps:

1. **View the generated public key** in the container logs
2. **Copy the key** to your remote server:

```bash
# On your remote server
echo "ssh-rsa AAAAB3NzaC1yc2EAA..." >> ~/.ssh/authorized_keys
```

3. **Set correct permissions:**

```bash
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

### Using Existing Keys

To use existing SSH keys:

1. Place your private key as `tunnel_rsa_key` in the `ssh-tunnel/keys/` directory
2. Ensure the corresponding public key is installed on the remote server
3. Set appropriate file permissions (600 for private key)

## 📊 Monitoring and Logs

### Container Logs

View real-time logs to monitor tunnel status:

```bash
docker-compose logs -f
```

### Log Events

The container logs include:
- SSH tunnel connection status
- Health check results
- Automatic reconnection attempts
- Error conditions and warnings

### Nginx Proxy Manager Logs

Access detailed Nginx logs in the mapped data volume:
- `./data/logs/` - Contains all proxy and access logs
- Individual host logs are separated by proxy configuration

## 🔧 Troubleshooting

### Common Issues

#### SSH Connection Failures

```bash
# Check SSH connectivity from host
ssh -p 22 user@your-server.example.com

# Verify SSH key permissions
ls -la ssh-tunnel/keys/
```

#### Port Already in Use

```bash
# Check what's using port 81
netstat -tulpn | grep :81

# Stop conflicting services
sudo systemctl stop apache2  # Example
```

#### Container Won't Start

```bash
# Check Docker logs
docker-compose logs -f

# Verify Docker Compose syntax
docker-compose config
```

### SSH Server Configuration

Ensure your remote server accepts reverse tunnels:

```bash
# In /etc/ssh/sshd_config
GatewayPorts yes
AllowTcpForwarding yes

# Restart SSH service
sudo systemctl restart sshd
```

### Network Connectivity

Test connectivity between container and remote server:

```bash
# From inside the container
docker-compose exec nginx-proxy-manager nc -zv your-server.example.com 22
```

## 🔒 Security Considerations

- **Change default credentials** immediately after deployment
- **Use strong SSH passwords** or preferably SSH keys
- **Limit SSH access** on your remote server (whitelist IPs if possible)
- **Regular updates** - Keep the base images updated
- **Monitor logs** for suspicious connection attempts
- **Firewall configuration** - Only expose necessary ports on remote server

## 🏗️ Architecture

```
┌─────────────────┐    SSH Tunnel    ┌─────────────────┐
│   Local Docker  │◄─────────────────►│  Remote Server  │
│                 │                   │                 │
│ ┌─────────────┐ │                   │ ┌─────────────┐ │
│ │   Nginx     │ │ HTTP:80  ──────── │ │   Port 80   │ │
│ │   Proxy     │ │ HTTPS:443 ─────── │ │   Port 443  │ │
│ │   Manager   │ │ Admin:81          │ └─────────────┘ │
│ └─────────────┘ │                   │                 │
│                 │                   │   Internet      │
└─────────────────┘                   └─────────────────┘
        │                                       ▲
        │ Local Access                          │
        ▼                                       │
┌─────────────────┐                   ┌─────────────────┐
│   Your Apps     │                   │   Public Users  │
│   (localhost)   │                   │   (via tunnel)  │
└─────────────────┘                   └─────────────────┘
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Nginx Proxy Manager](https://nginxproxymanager.com/) - The excellent web-based proxy manager
- [jc21/nginx-proxy-manager](https://github.com/jc21/nginx-proxy-manager) - Base Docker image
- [AutoSSH](https://www.harding.motd.ca/autossh/) - Reliable SSH tunnel maintenance

## 🔗 Related Projects

- [Nginx Proxy Manager](https://nginxproxymanager.com/)
- [Traefik](https://traefik.io/) - Alternative reverse proxy
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) - Alternative tunneling solution

---

**Made with ❤️ for the self-hosting community**
