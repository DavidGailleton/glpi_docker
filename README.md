# GLPI Docker Setup

A Docker Compose setup for GLPI with Redis caching, MariaDB, and HTTPS support.

## Features

- **GLPI 10.0.18** with PHP 8.3
- **MariaDB 11.4** for database
- **Redis 7.0** for caching
- **Nginx** with HTTPS support
- **Automatic Redis cache configuration** on container startup
- **Timezone configuration** for all containers
- **SSL/HTTPS support** with self-signed or custom certificates

## Quick Start

1. **Create environment file:**
   Create a `.env` file with the following content:
   ```bash
   # Timezone configuration
   TZ=Europe/Paris

   # MariaDB configuration
   MARIADB_ROOT_PASSWORD=change_this_root_password
   MARIADB_DATABASE=glpi
   MARIADB_USER=glpi_user
   MARIADB_PASSWORD=change_this_password

   # GLPI database configuration
   GLPI_DB_HOST=mariadb
   GLPI_DB_PORT=3306
   GLPI_DB_NAME=glpi
   GLPI_DB_USER=glpi_user
   GLPI_DB_PASSWORD=change_this_password
   ```
   **Important:** Change all passwords before using!

2. **Generate SSL certificates:**
   ```bash
   # Windows PowerShell
   .\scripts\generate-self-signed-cert.ps1
   
   # Linux/macOS/WSL
   ./scripts/generate-self-signed-cert.sh
   ```

3. **Start the containers:**
   ```bash
   docker-compose up -d
   ```

4. **Access GLPI:**
   - HTTPS: https://glpi.localhost
   - HTTP automatically redirects to HTTPS

## Redis Cache Configuration

### Automatic Configuration
The Redis cache is automatically configured when the PHP container starts if GLPI is already installed. This is handled by the `docker-entrypoint.sh` script.

### Manual Configuration
If you need to manually configure or reconfigure the Redis cache:

**Windows PowerShell:**
```powershell
.\scripts\configure-redis-cache.ps1
```

**Linux/macOS/WSL:**
```bash
./scripts/configure-redis-cache.sh
```

### How it Works
1. The `docker-entrypoint.sh` script runs when the PHP container starts
2. It waits for Redis and MariaDB to be ready
3. If GLPI is installed (config file exists), it runs:
   ```bash
   php bin/console cache:configure --context core --dsn redis://redis:6379/1
   ```
4. The cache configuration is stored in GLPI's config

## Container Services

### PHP-FPM
- **Image:** Custom build based on `php:8.3-fpm-alpine`
- **Extensions:** GD, intl, mysqli, pdo_mysql, exif, bz2, zip, ldap, opcache, sodium, redis, apcu
- **Exposed Port:** 9000
- **Features:**
  - Automatic Redis cache configuration on startup
  - Pre-configured with required PHP extensions
  - Optimized for GLPI

### Nginx
- **Image:** `nginx:stable-alpine`
- **Ports:** 80 (HTTP), 443 (HTTPS)
- **Features:**
  - HTTPS with modern TLS configuration
  - HTTP to HTTPS redirect
  - Security headers
  - Optimized for GLPI

### MariaDB
- **Image:** `mariadb:11.4`
- **Port:** 3306
- **Volume:** `glpi-db` for data persistence

### Redis
- **Image:** `redis:7.0-alpine`
- **Port:** 6379
- **Volume:** `redis-cache` for data persistence
- **Usage:** GLPI cache backend

## Timezone Configuration

All containers are configured with the same timezone (default: `Europe/Paris`). To change:

1. Edit `docker-compose.yml`
2. Update the `TZ` environment variable for each service
3. Restart containers: `docker-compose restart`

Common timezone values:
- `Europe/Paris`
- `America/New_York`
- `Asia/Tokyo`
- `UTC`

## SSL/HTTPS Configuration

### Using Self-Signed Certificates
Self-signed certificates are suitable for development and testing:

```bash
# Generate certificates (choose your platform)
.\generate-self-signed-cert.ps1  # Windows
./generate-self-signed-cert.sh    # Linux/macOS
```

### Using Custom Certificates
1. Place your certificates in `nginx/ssl/`:
   - `cert.pem` - Your SSL certificate
   - `key.pem` - Your private key

2. Restart nginx:
   ```bash
   docker-compose restart nginx
   ```

See [nginx/ssl/README-SSL.md](nginx/ssl/README-SSL.md) for detailed SSL configuration instructions.

## Volumes

- `glpi-root`: GLPI application files
- `marketplace`: GLPI marketplace plugins
- `config`: GLPI configuration
- `var-lib-glpi`: GLPI data (uploads, cache, sessions, etc.)
- `glpi-db`: MariaDB database files
- `redis-cache`: Redis persistent data

## Maintenance

### View logs
```bash
# All containers
docker-compose logs -f

# Specific service
docker-compose logs -f php
docker-compose logs -f nginx
```

### Access container shell
```bash
# PHP container (as root)
docker-compose exec php sh

# PHP container (as www-data user)
docker-compose exec php su -s /bin/sh www-data

# Other containers
docker-compose exec nginx sh
docker-compose exec mariadb bash
docker-compose exec redis sh
```

### Backup database
```bash
docker-compose exec mariadb mysqldump -u root -p glpi > backup.sql
```

### Clear Redis cache
```bash
docker-compose exec redis redis-cli FLUSHALL
```

## Troubleshooting

### Redis cache not configured
If the automatic configuration fails, run the manual configuration script:
```bash
./scripts/configure-redis-cache.sh  # or .ps1 for Windows
```

### Certificate issues
- Check nginx logs: `docker-compose logs nginx`
- Verify certificates exist in `nginx/ssl/`
- Ensure proper permissions on certificate files

### Container startup issues
1. Check logs: `docker-compose logs [service-name]`
2. Ensure all required ports are free
3. Verify `.env` file exists with proper values

## Maintenance & Updates

This project includes comprehensive maintenance tools to make updates and cleanup easier:

### Quick Commands (Using Make)
```bash
make help       # Show all available commands
make update     # Update containers with automatic backup
make backup     # Create backup of data and configs
make clean      # Clean containers (preserves data)
make clean-all  # Clean everything including data
```

### Manual Scripts
- **Windows**: `.\scripts\cleanup.ps1`, `.\scripts\update.ps1`
- **Linux/macOS**: `./scripts/cleanup.sh`, `./scripts/update.sh`

### Key Features
- **Automatic backups** before updates
- **Smart cleanup** with data preservation options
- **Build cache management** for PHP-FPM
- **Health checks** after updates
- **Force mode** for CI/CD pipelines

For detailed maintenance procedures, see [MAINTENANCE.md](MAINTENANCE.md).

## Security Notes

1. **Never commit** `.env` file or SSL certificates to version control
2. Change default passwords in production
3. Use proper SSL certificates from a CA for production
4. Restrict database ports in production environments

## License

This Docker setup is provided as-is. GLPI is licensed under GPL v2+. 