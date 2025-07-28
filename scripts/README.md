# GLPI Docker Scripts

This directory contains all the scripts for managing the GLPI Docker setup.

## Maintenance Scripts

### cleanup.ps1 / cleanup.sh
Clean up Docker containers, volumes, and temporary files.
- **Usage**: `.\cleanup.ps1 [-KeepVolumes] [-KeepData] [-Force]`
- **Purpose**: Remove containers, volumes, SSL certificates, and system cleanup

### update.ps1 / update.sh
Update the GLPI Docker setup with backup capabilities.
- **Usage**: `.\update.ps1 [-Backup] [-NoBackup] [-Force]`
- **Purpose**: Pull latest images, rebuild containers, and update the setup

## Configuration Scripts

### configure-redis-cache.ps1 / configure-redis-cache.sh
Configure Redis cache for GLPI performance optimization.
- **Usage**: Run after GLPI initial setup
- **Purpose**: Enable and configure Redis caching in GLPI

### generate-self-signed-cert.ps1 / generate-self-signed-cert.sh
Generate self-signed SSL certificates for HTTPS support.
- **Usage**: Run during initial setup
- **Purpose**: Create SSL certificates for secure HTTPS access

## Timezone Configuration Scripts

### configure-timezone-database.ps1 / configure-timezone-database.sh
Advanced timezone database configuration for GLPI.
- **Usage**: Use if experiencing timezone-related issues
- **Purpose**: Fix timezone data in MariaDB

### configure-timezone-database-simple.ps1 / configure-timezone-database-simple.sh
Simplified timezone configuration.
- **Usage**: Easier alternative to the full timezone script
- **Purpose**: Basic timezone setup for most use cases

### configure-timezone-database-linux.ps1
Linux-specific timezone configuration (PowerShell version).
- **Usage**: For PowerShell users on Linux systems
- **Purpose**: Cross-platform timezone configuration

### check-timezone-status.sh
Check the current timezone configuration status.
- **Usage**: Diagnostic tool for timezone issues
- **Purpose**: Verify timezone settings are correct

## Usage Notes

### For Windows Users
Use the `.ps1` PowerShell scripts:
```powershell
.\scripts\cleanup.ps1
.\scripts\update.ps1 -Backup
.\scripts\generate-self-signed-cert.ps1
```

### For Linux/macOS Users
Use the `.sh` bash scripts:
```bash
./scripts/cleanup.sh --keep-volumes
./scripts/update.sh --backup
./scripts/generate-self-signed-cert.sh
```

## Script Categories

| Category | Scripts | Description |
|----------|---------|-------------|
| **Maintenance** | cleanup, update | Day-to-day maintenance operations |
| **Setup** | generate-self-signed-cert | Initial setup tasks |
| **Configuration** | configure-redis-cache | Post-installation configuration |
| **Timezone** | configure-timezone-*, check-timezone-status | Timezone-related utilities |

## Recommended Workflow

1. **Initial Setup**: `generate-self-signed-cert.ps1/.sh`
2. **After Installation**: `configure-redis-cache.ps1/.sh`
3. **Regular Updates**: `update.ps1/.sh --backup`
4. **Cleanup**: `cleanup.ps1/.sh --keep-volumes`

For more detailed information, see the main [MAINTENANCE.md](../MAINTENANCE.md) guide. 