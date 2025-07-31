# Emberchat Deployment Guide

Deploy Emberchat to your VPS using Kamal (formerly MRSK) for a simple, Docker-based deployment.

## Prerequisites

1. **VPS Requirements:**
   - Ubuntu 20.04+ or similar Linux distribution
   - At least 1GB RAM (2GB+ recommended)
   - Docker installed
   - SSH access with sudo privileges

2. **Local Requirements:**
   - Ruby 3.0+ (for Kamal)
   - Docker (for building images)
   - SSH access to your VPS

## Quick Start

### 1. Install Kamal

```bash
gem install kamal
```

### 2. Configure Your Deployment

Copy and customize the environment file:

```bash
cp .env.example .env
```

Edit `.env` with your values:

```bash
# Generate a secret key base
mix phx.gen.secret

# Add it to .env
SECRET_KEY_BASE=your_generated_secret_here
PHX_HOST=your-domain.com
```

### 3. Update Deployment Configuration

Edit `config/deploy.yml`:

```yaml
servers:
  web:
    - your.vps.ip.address  # Replace with your VPS IP

proxy:
  host: your-domain.com    # Replace with your domain

registry:
  username: your-docker-username  # For Docker Hub
```

### 4. Deploy

Use the deployment helper script:

```bash
# Initial setup (run once)
./deploy.sh setup

# Deploy your application
./deploy.sh deploy
```

## Detailed Configuration

### Environment Variables

Required variables in `.env`:

| Variable | Description | Example |
|----------|-------------|---------|
| `SECRET_KEY_BASE` | Phoenix secret key | Generate with `mix phx.gen.secret` |
| `PHX_HOST` | Your domain name | `emberchat.yourdomain.com` |
| `DATABASE_PATH` | SQLite database path | `/app/data/emberchat.db` |

Optional variables:

| Variable | Description |
|----------|-------------|
| `DOCKER_PASSWORD` | Docker Hub access token |
| `GITHUB_TOKEN` | GitHub Container Registry token |
| `MAILGUN_API_KEY` | For email notifications |
| `MAILGUN_DOMAIN` | Mailgun domain |

### Server Setup

Your VPS needs:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Add deploy user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Docker Registry Options

#### Option 1: Docker Hub (Public)

```yaml
# In config/deploy.yml
registry:
  username: your-dockerhub-username
  password:
    - DOCKER_PASSWORD
```

#### Option 2: GitHub Container Registry (Recommended)

```yaml
# In config/deploy.yml
registry:
  server: ghcr.io
  username: your-github-username  
  password:
    - GITHUB_TOKEN
```

Generate a GitHub Personal Access Token with `read:packages` and `write:packages` permissions.

#### Option 3: Self-hosted Registry

```yaml
# In config/deploy.yml
registry:
  server: registry.yourdomain.com
  username: your-username
  password:
    - REGISTRY_PASSWORD
```

## Deployment Commands

### Using the Helper Script

```bash
# Show help
./deploy.sh

# Initial deployment setup
./deploy.sh setup

# Deploy application
./deploy.sh deploy

# Restart application
./deploy.sh restart

# View logs
./deploy.sh logs

# Open remote console
./deploy.sh console

# Rollback to previous version
./deploy.sh rollback

# Check status
./deploy.sh status

# Remove deployment (careful!)
./deploy.sh remove
```

### Direct Kamal Commands

```bash
# Setup infrastructure
kamal setup

# Deploy
kamal deploy

# Check details
kamal details

# View logs
kamal app logs

# Execute commands
kamal app exec "bin/emberchat eval 'IO.puts(:hello)'"

# Open console
kamal app exec --interactive --reuse "bin/emberchat remote"
```

## SSL/HTTPS Setup

Kamal automatically configures SSL via Traefik proxy. Ensure your domain points to your VPS IP address.

For custom SSL certificates:

```yaml
# In config/deploy.yml
proxy:
  ssl: true
  host: your-domain.com
  ssl_certificate_path: /path/to/cert.pem
  ssl_certificate_key_path: /path/to/key.pem
```

## Database Management

The SQLite database is persisted in a Docker volume. To backup:

```bash
# Access the container
kamal app exec --interactive "sqlite3 /app/data/emberchat.db .dump" > backup.sql

# Restore from backup
cat backup.sql | kamal app exec --interactive "sqlite3 /app/data/emberchat.db"
```

## Monitoring and Logs

```bash
# Follow live logs
kamal app logs --follow

# Check resource usage
kamal app exec "top"

# Check disk usage
kamal app exec "df -h"
```

## Troubleshooting

### Common Issues

1. **Build fails with "permission denied"**
   ```bash
   # Ensure Docker is running and user is in docker group
   sudo usermod -aG docker $USER
   # Then logout and login again
   ```

2. **Database connection issues**
   - Check `DATABASE_PATH` environment variable
   - Ensure the data volume is mounted correctly

3. **SSL certificate issues**
   - Verify your domain DNS points to the VPS
   - Check Traefik logs: `kamal traefik logs`

4. **Container won't start**
   ```bash
   # Check container logs
   kamal app logs
   
   # Check if all environment variables are set
   kamal app exec "env"
   ```

### Getting Help

- Check logs: `./deploy.sh logs`
- Verify configuration: `kamal config`
- Test connection: `kamal app exec "curl http://localhost:4000"`

## Updating

To deploy updates:

```bash
git pull origin main
./deploy.sh deploy
```

Kamal performs zero-downtime deployments by default.

## Security Notes

- Never commit `.env` to version control
- Use strong passwords and SSH keys
- Keep your VPS updated: `sudo apt update && sudo apt upgrade`
- Consider setting up a firewall: `sudo ufw enable`
- Regularly backup your database

## Performance Tuning

For high-traffic deployments:

```yaml
# In config/deploy.yml
env:
  clear:
    POOL_SIZE: 20  # Increase database connections
    
# Scale containers
servers:
  web:
    - server1.example.com
    - server2.example.com
    options:
      "add-host": "host.docker.internal:host-gateway"
```

## Cost Estimation

- **Small VPS (1GB RAM)**: $5-10/month
- **Medium VPS (2GB RAM)**: $10-20/month  
- **Domain**: $10-15/year
- **SSL Certificate**: Free (Let's Encrypt via Traefik)

**Total**: ~$60-240/year for a complete deployment.