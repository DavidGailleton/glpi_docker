#!/bin/sh
set -e

echo "Starting GLPI container initialization..."

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
max_tries=30
tries=0
while [ $tries -lt $max_tries ]; do
    if nc -z redis 6379 2>/dev/null; then
        echo "Redis is ready!"
        break
    fi
    tries=$((tries + 1))
    echo "Waiting for Redis... ($tries/$max_tries)"
    sleep 2
done

if [ $tries -eq $max_tries ]; then
    echo "Warning: Redis might not be ready, but continuing anyway..."
fi

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
max_tries=30
tries=0
while [ $tries -lt $max_tries ]; do
    if nc -z mariadb 3306 2>/dev/null; then
        echo "MariaDB is ready!"
        break
    fi
    tries=$((tries + 1))
    echo "Waiting for MariaDB... ($tries/$max_tries)"
    sleep 2
done

if [ $tries -eq $max_tries ]; then
    echo "Warning: MariaDB might not be ready, but continuing anyway..."
fi

# Check if GLPI is already installed by looking for the config file
if [ -f "/var/www/html/config/config_db.php" ]; then
    echo "GLPI appears to be installed, configuring Redis cache..."
    
    # Configure Redis cache for GLPI
    cd /var/www/html
    
    # Run as www-data user (no need for sudo in container)
    su -s /bin/sh www-data -c "php bin/console cache:configure --context core --dsn redis://redis:6379/1" || {
        echo "Warning: Failed to configure Redis cache, but continuing..."
    }
    
    echo "Redis cache configuration completed (or skipped if failed)"
else
    echo "GLPI not yet installed, skipping Redis cache configuration..."
    echo "Redis cache will need to be configured after GLPI installation"
fi

# Create necessary directories if they don't exist
for dir in _cache _cron _dumps _graphs _lock _pictures _plugins _rss _sessions _tmp _uploads; do
    if [ ! -d "/var/lib/glpi/$dir" ]; then
        mkdir -p "/var/lib/glpi/$dir"
        chown www-data:www-data "/var/lib/glpi/$dir"
        chmod 755 "/var/lib/glpi/$dir"
    fi
done

# Fix marketplace volume ownership
echo "Fixing marketplace volume ownership..."
if [ -d "/var/www/html/marketplace" ]; then
    chown -R www-data:www-data /var/www/html/marketplace
    chmod -R 755 /var/www/html/marketplace
    echo "Marketplace directory ownership set to www-data:www-data"
else
    echo "Marketplace directory not found, creating it..."
    mkdir -p /var/www/html/marketplace
    chown -R www-data:www-data /var/www/html/marketplace
    chmod -R 755 /var/www/html/marketplace
    echo "Marketplace directory created with www-data:www-data ownership"
fi

echo "Starting PHP-FPM..."

# Execute the original command (php-fpm)
exec "$@" 