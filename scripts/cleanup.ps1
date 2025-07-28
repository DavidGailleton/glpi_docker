#!/usr/bin/env pwsh
# GLPI Docker Cleanup Script for Windows
# This script cleans up Docker containers, volumes, and temporary files

param(
    [switch]$KeepVolumes,
    [switch]$KeepData,
    [switch]$Force
)

Write-Host "GLPI Docker Cleanup Script" -ForegroundColor Blue
Write-Host "=========================" -ForegroundColor Blue

# Function to confirm action
function Confirm-Action {
    param([string]$Message)
    if (-not $Force) {
        $response = Read-Host "$Message (y/N)"
        return $response -eq 'y' -or $response -eq 'Y'
    }
    return $true
}

# Stop and remove containers
Write-Host "`nStopping and removing containers..." -ForegroundColor Yellow
$containers = docker-compose ps -q 2>$null
if ($containers) {
    docker-compose down
    Write-Host "Containers stopped and removed." -ForegroundColor Green
} else {
    Write-Host "No running containers found." -ForegroundColor Gray
}

# Remove volumes if not keeping data
if (-not $KeepVolumes -and -not $KeepData) {
    if (Confirm-Action "Remove all Docker volumes? This will DELETE ALL DATA!") {
        Write-Host "`nRemoving Docker volumes..." -ForegroundColor Yellow
        docker-compose down -v
        
        # Also remove any orphaned volumes
        $volumes = docker volume ls -q -f "name=glpi_docker_" 2>$null
        if ($volumes) {
            docker volume rm $volumes 2>$null
            Write-Host "Volumes removed." -ForegroundColor Green
        }
    }
}

# Clean up SSL certificates
if (Test-Path "nginx/ssl/*.pem" -or Test-Path "nginx/ssl/*.key" -or Test-Path "nginx/ssl/*.crt") {
    if (Confirm-Action "Remove SSL certificates?") {
        Write-Host "`nRemoving SSL certificates..." -ForegroundColor Yellow
        Remove-Item -Path "nginx/ssl/*.pem" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "nginx/ssl/*.key" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "nginx/ssl/*.crt" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "nginx/ssl/*.pfx" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "nginx/ssl/*.p12" -Force -ErrorAction SilentlyContinue
        Write-Host "SSL certificates removed." -ForegroundColor Green
    }
}

# Remove .env file if exists
if (Test-Path ".env") {
    if (Confirm-Action "Remove .env file?") {
        Write-Host "`nRemoving .env file..." -ForegroundColor Yellow
        Remove-Item -Path ".env" -Force
        Write-Host ".env file removed." -ForegroundColor Green
    }
}

# Clean Docker system
if (Confirm-Action "Run Docker system prune to remove unused data?") {
    Write-Host "`nCleaning Docker system..." -ForegroundColor Yellow
    docker system prune -f
    Write-Host "Docker system cleaned." -ForegroundColor Green
}

# Remove PHP-FPM build cache
if (Test-Path "php-fpm/.dockerignore" -or (docker images -q "glpi_docker_php" 2>$null)) {
    if (Confirm-Action "Remove PHP-FPM Docker image?") {
        Write-Host "`nRemoving PHP-FPM Docker image..." -ForegroundColor Yellow
        docker rmi glpi_docker_php 2>$null
        docker rmi glpi_docker-php 2>$null
        Write-Host "PHP-FPM image removed." -ForegroundColor Green
    }
}

Write-Host "`nCleanup completed!" -ForegroundColor Green
Write-Host "`nUsage tips:" -ForegroundColor Cyan
Write-Host "  -KeepVolumes : Keep Docker volumes (preserves database and files)"
Write-Host "  -KeepData    : Keep all data (volumes and .env file)"
Write-Host "  -Force       : Skip all confirmations"
Write-Host "`nExample: .\cleanup.ps1 -KeepVolumes" 