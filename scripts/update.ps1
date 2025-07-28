#!/usr/bin/env pwsh
# GLPI Docker Update Script for Windows
# This script helps update GLPI Docker setup components

param(
    [switch]$Backup,
    [switch]$NoBackup,
    [switch]$Force
)

Write-Host "GLPI Docker Update Script" -ForegroundColor Blue
Write-Host "========================" -ForegroundColor Blue

# Function to confirm action
function Confirm-Action {
    param([string]$Message)
    if (-not $Force) {
        $response = Read-Host "$Message (y/N)"
        return $response -eq 'y' -or $response -eq 'Y'
    }
    return $true
}

# Function to check if containers are running
function Test-ContainersRunning {
    $containers = docker-compose ps -q 2>$null
    return $null -ne $containers -and $containers.Count -gt 0
}

# Create backup if requested
if ($Backup -and -not $NoBackup) {
    Write-Host "`nCreating backup..." -ForegroundColor Yellow
    $backupDir = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    # Backup .env file
    if (Test-Path ".env") {
        Copy-Item ".env" "$backupDir/.env"
        Write-Host "Backed up .env file" -ForegroundColor Gray
    }
    
    # Backup custom configurations
    if (Test-Path "php-fpm/conf.d") {
        Copy-Item -Recurse "php-fpm/conf.d" "$backupDir/php-conf.d"
        Write-Host "Backed up PHP configurations" -ForegroundColor Gray
    }
    
    if (Test-Path "nginx/conf.d") {
        Copy-Item -Recurse "nginx/conf.d" "$backupDir/nginx-conf.d"
        Write-Host "Backed up Nginx configurations" -ForegroundColor Gray
    }
    
    # Export Docker volumes if containers are running
    if (Test-ContainersRunning) {
        if (Confirm-Action "Export database backup? (Recommended)") {
            Write-Host "Exporting database..." -ForegroundColor Gray
            # Read password from .env file
            $rootPassword = ""
            if (Test-Path ".env") {
                $envContent = Get-Content ".env" | Where-Object { $_ -match "^MARIADB_ROOT_PASSWORD=" }
                if ($envContent) {
                    $rootPassword = $envContent -replace "^MARIADB_ROOT_PASSWORD=", ""
                }
            }
            
            if ($rootPassword) {
                docker-compose exec -T mariadb mysqldump -u root -p"$rootPassword" glpi > "$backupDir/glpi_database.sql" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Database exported successfully" -ForegroundColor Green
                } else {
                    Write-Host "Database export failed - check your database connection" -ForegroundColor Red
                }
            } else {
                Write-Host "Could not read MARIADB_ROOT_PASSWORD from .env file" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "Backup created in: $backupDir" -ForegroundColor Green
}

# Pull latest images
Write-Host "`nPulling latest Docker images..." -ForegroundColor Yellow
docker-compose pull

# Check if PHP Dockerfile has changed
$phpDockerfile = "php-fpm/Dockerfile"
if (Test-Path $phpDockerfile) {
    $currentHash = (Get-FileHash $phpDockerfile).Hash
    $lastHash = $null
    
    if (Test-Path ".last-php-build-hash") {
        $lastHash = Get-Content ".last-php-build-hash"
    }
    
    if ($currentHash -ne $lastHash -or -not (docker images -q "glpi_docker_php" 2>$null)) {
        Write-Host "`nRebuilding PHP-FPM image..." -ForegroundColor Yellow
        docker-compose build --no-cache php
        $currentHash | Out-File -FilePath ".last-php-build-hash" -NoNewline
        Write-Host "PHP-FPM image rebuilt." -ForegroundColor Green
    } else {
        Write-Host "`nPHP-FPM image is up to date." -ForegroundColor Gray
    }
}

# Stop containers if running
if (Test-ContainersRunning) {
    Write-Host "`nStopping containers..." -ForegroundColor Yellow
    docker-compose stop
    Write-Host "Containers stopped." -ForegroundColor Green
}

# Start containers with updated images
Write-Host "`nStarting containers with updated images..." -ForegroundColor Yellow
docker-compose up -d

# Wait for services to be ready
Write-Host "`nWaiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check container status
Write-Host "`nChecking container status..." -ForegroundColor Yellow
docker-compose ps

# Show logs of any failed containers
$failedContainers = docker-compose ps | Select-String "Exit" | ForEach-Object { ($_ -split '\s+')[0] }
if ($failedContainers) {
    Write-Host "`nSome containers failed to start. Showing logs:" -ForegroundColor Red
    foreach ($container in $failedContainers) {
        Write-Host "`nLogs for ${container}:" -ForegroundColor Yellow
        docker-compose logs --tail=20 $container
    }
} else {
    Write-Host "`nAll containers are running successfully!" -ForegroundColor Green
}

# Run Redis configuration if needed
if (Test-Path "scripts/configure-redis-cache.ps1") {
    if (Confirm-Action "Configure Redis cache for GLPI?") {
        Write-Host "`nConfiguring Redis cache..." -ForegroundColor Yellow
        & ./scripts/configure-redis-cache.ps1
    }
}

Write-Host "`nUpdate completed!" -ForegroundColor Green
Write-Host "`nPost-update checklist:" -ForegroundColor Cyan
Write-Host "1. Access GLPI at: https://localhost" -ForegroundColor White
Write-Host "2. Check for GLPI updates in the web interface" -ForegroundColor White
Write-Host "3. Update plugins as needed" -ForegroundColor White
Write-Host "4. Clear GLPI cache if experiencing issues" -ForegroundColor White

Write-Host "`nUsage tips:" -ForegroundColor Cyan
Write-Host "  -Backup    : Create backup before updating"
Write-Host "  -NoBackup  : Skip backup creation"
Write-Host "  -Force     : Skip all confirmations"
Write-Host "`nExample: .\update.ps1 -Backup" 