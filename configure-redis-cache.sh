#!/bin/bash

# Script to manually configure Redis cache for GLPI
# Run this script from the host to configure Redis cache in the PHP container

echo "Configuring Redis cache for GLPI..."

# Check if docker-compose is running
if ! docker-compose ps | grep -q "php.*Up"; then
    echo "Error: PHP container is not running. Please start the containers first:"
    echo "  docker-compose up -d"
    exit 1
fi

# Execute the cache configuration command in the PHP container
echo "Executing cache configuration in PHP container..."
docker-compose exec -T php su -s /bin/sh www-data -c "cd /var/www/html && php bin/console cache:configure --context core --dsn redis://redis:6379/1"

if [ $? -eq 0 ]; then
    echo "Redis cache configured successfully!"
    
    # Optionally, test the Redis connection
    echo ""
    echo "Testing Redis connection..."
    docker-compose exec -T php su -s /bin/sh www-data -c "cd /var/www/html && php bin/console cache:test --context core" 2>/dev/null || {
        echo "Note: Cache test command might not be available in your GLPI version"
    }
else
    echo "Error: Failed to configure Redis cache"
    echo "Please check that:"
    echo "  1. GLPI is properly installed"
    echo "  2. Redis container is running"
    echo "  3. The config directory exists and is writable"
    exit 1
fi 