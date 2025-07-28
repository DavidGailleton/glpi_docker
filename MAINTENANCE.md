# GLPI Docker Maintenance Guide

This guide covers the maintenance tools and procedures for the GLPI Docker setup.

## Quick Reference

### Using Make (Recommended)
```bash
make help         # Show all available commands
make setup        # Initial setup
make up           # Start containers
make update       # Update with backup
make clean        # Clean (keep data)
make clean-all    # Clean everything
```

### Manual Scripts
- **Windows**: Use PowerShell scripts (`scripts/*.ps1`)
- **Linux/macOS**: Use bash scripts (`scripts/*.sh`)

## Cleanup Tools

### scripts/cleanup.ps1 / scripts/cleanup.sh

These scripts help clean up Docker containers, volumes, and temporary files.

#### Usage
```bash
# Windows PowerShell
.\scripts\cleanup.ps1 [-KeepVolumes] [-KeepData] [-Force]

# Linux/macOS
./scripts/cleanup.sh [--keep-volumes] [--keep-data] [--force]
```

#### Options
- **KeepVolumes/--keep-volumes**: Preserve Docker volumes (database and GLPI files)
- **KeepData/--keep-data**: Keep all data (volumes and .env file)
- **Force/--force**: Skip all confirmation prompts

#### What it cleans:
1. Docker containers
2. Docker volumes (unless --keep-volumes)
3. SSL certificates
4. .env file (unless --keep-data)
5. Docker system (unused images, networks, etc.)
6. PHP-FPM build cache

## Update Tools

### scripts/update.ps1 / scripts/update.sh

These scripts help update the GLPI Docker setup safely.

#### Usage
```bash
# Windows PowerShell
.\scripts\update.ps1 [-Backup] [-NoBackup] [-Force]

# Linux/macOS
./scripts/update.sh [--backup] [--no-backup] [--force]
```

#### Options
- **Backup/--backup**: Create backup before updating
- **NoBackup/--no-backup**: Skip backup creation
- **Force/--force**: Skip all confirmation prompts

#### Update process:
1. Creates backup (if requested)
2. Pulls latest Docker images
3. Rebuilds PHP-FPM if Dockerfile changed
4. Stops containers
5. Starts containers with new images
6. Checks container health
7. Optionally configures Redis

## Makefile Commands

The Makefile provides easy-to-use commands for common tasks:

### Setup & Start
- `make setup` - Initial setup (create .env, generate SSL)
- `make up` - Start all containers
- `make down` - Stop and remove containers
- `make start` - Start stopped containers
- `make stop` - Stop running containers
- `make restart` - Restart all containers

### Monitoring
- `make status` - Show container status
- `make logs` - Show container logs
- `make logs-f` - Follow container logs

### Maintenance
- `make update` - Update containers and images
- `make backup` - Create backup of data and configs
- `make clean` - Clean containers (keep data)
- `make clean-all` - Clean everything (REMOVES ALL DATA!)

### Database
- `make db-shell` - Access MariaDB shell
- `make db-backup` - Backup database only

### GLPI
- `make glpi-shell` - Access GLPI container shell
- `make redis-config` - Configure Redis cache

## Best Practices

### Regular Maintenance
1. **Weekly**: Check container logs for errors
   ```bash
   make logs
   ```

2. **Monthly**: Update containers and create backup
   ```bash
   make update  # This includes backup
   ```

3. **Quarterly**: Clean Docker system
   ```bash
   make clean
   ```

### Before Major Updates
1. Create a full backup:
   ```bash
   make backup
   ```

2. Test in a development environment first

3. Review GLPI changelog for breaking changes

### Backup Strategy
- Backups are stored in `backup_YYYYMMDD_HHMMSS/` directories
- Database dumps can be created separately with `make db-backup`
- Consider off-site backup for production data

### Troubleshooting

#### Containers won't start
```bash
make logs            # Check error messages
make clean          # Clean and restart
make up
```

#### Database connection issues
1. Check .env file for correct credentials
2. Ensure MariaDB container is running:
   ```bash
   docker-compose ps mariadb
   ```

#### SSL certificate problems
```bash
# Regenerate certificates
./scripts/generate-self-signed-cert.sh  # or .ps1 for Windows
make restart
```

## Security Notes

1. **Never commit .env file** - Contains passwords
2. **Change default passwords** immediately after setup
3. **Keep SSL certificates secure** - Already in .gitignore
4. **Regular updates** - Apply security patches promptly

## Disaster Recovery

### Full Recovery Process
1. Install Docker and Docker Compose
2. Clone the repository
3. Restore .env file from backup
4. Restore SSL certificates (or regenerate)
5. Start containers: `make up`
6. Restore database from backup:
   ```bash
   docker-compose exec -T mariadb mysql -u root -p < backup/glpi_database.sql
   ```
7. Restore GLPI files if needed

### Quick Recovery
If you have recent backups:
```bash
# 1. Restore configuration files
cp backup_*/env .env
cp -r backup_*/nginx-conf.d/* nginx/conf.d/
cp -r backup_*/php-conf.d/* php-fpm/conf.d/

# 2. Start containers
make up

# 3. Restore database
cat backup_*/glpi_database.sql | docker-compose exec -T mariadb mysql -u root -p
```

## Additional Notes

- The `.gitignore` file has been updated to exclude all sensitive and temporary files
- Build hashes are tracked to avoid unnecessary PHP-FPM rebuilds
- All scripts support both interactive and automated modes
- Compatible with CI/CD pipelines using the --force flag 