# Script to manually configure Redis cache for GLPI
# Run this script from the host to configure Redis cache in the PHP container

Write-Host "Configuring Redis cache for GLPI..." -ForegroundColor Green

# Check if docker-compose is running
$phpRunning = docker-compose ps | Select-String "php.*Up"

if (-not $phpRunning) {
    Write-Host "Error: PHP container is not running. Please start the containers first:" -ForegroundColor Red
    Write-Host "  docker-compose up -d" -ForegroundColor Yellow
    exit 1
}

# Execute the cache configuration command in the PHP container
Write-Host "Executing cache configuration in PHP container..." -ForegroundColor Yellow

$result = docker-compose exec -T php su -s /bin/sh www-data -c "cd /var/www/html && php bin/console cache:configure --context core --dsn redis://redis:6379/1" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Redis cache configured successfully!" -ForegroundColor Green
    
    # Optionally, test the Redis connection
    Write-Host ""
    Write-Host "Testing Redis connection..." -ForegroundColor Yellow
    
    $testResult = docker-compose exec -T php su -s /bin/sh www-data -c "cd /var/www/html && php bin/console cache:test --context core" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Note: Cache test command might not be available in your GLPI version" -ForegroundColor Yellow
    } else {
        Write-Host $testResult
    }
} else {
    Write-Host "Error: Failed to configure Redis cache" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check that:" -ForegroundColor Yellow
    Write-Host "  1. GLPI is properly installed" -ForegroundColor Cyan
    Write-Host "  2. Redis container is running" -ForegroundColor Cyan
    Write-Host "  3. The config directory exists and is writable" -ForegroundColor Cyan
    exit 1
} 