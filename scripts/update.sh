#!/bin/bash
# GLPI Docker Update Script for Linux/macOS
# This script helps update GLPI Docker setup components

# Color codes
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;90m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Default values
BACKUP=false
NO_BACKUP=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup)
            BACKUP=true
            shift
            ;;
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --backup          Create backup before updating"
            echo "  --no-backup       Skip backup creation"
            echo "  --force           Skip all confirmations"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Example: $0 --backup"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}GLPI Docker Update Script${NC}"
echo -e "${BLUE}========================${NC}"

# Function to confirm action
confirm_action() {
    local message="$1"
    if [ "$FORCE" = false ]; then
        read -p "$message (y/N): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    else
        return 0
    fi
}

# Function to check if containers are running
containers_running() {
    docker compose ps -q 2>/dev/null | grep -q .
}

# Create backup if requested
if [ "$BACKUP" = true ] && [ "$NO_BACKUP" = false ]; then
    echo -e "\n${YELLOW}Creating backup...${NC}"
    backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup .env file
    if [ -f ".env" ]; then
        cp ".env" "$backup_dir/.env"
        echo -e "${GRAY}Backed up .env file${NC}"
    fi
    
    # Backup custom configurations
    if [ -d "php-fpm/conf.d" ]; then
        cp -r "php-fpm/conf.d" "$backup_dir/php-conf.d"
        echo -e "${GRAY}Backed up PHP configurations${NC}"
    fi
    
    if [ -d "nginx/conf.d" ]; then
        cp -r "nginx/conf.d" "$backup_dir/nginx-conf.d"
        echo -e "${GRAY}Backed up Nginx configurations${NC}"
    fi
    
    # Export Docker volumes if containers are running
    if containers_running; then
        if confirm_action "Export database backup? (Recommended)"; then
            echo -e "${GRAY}Exporting database...${NC}"
            # Read password from .env file
            if [ -f ".env" ]; then
                root_password=$(grep "^MARIADB_ROOT_PASSWORD=" .env | cut -d'=' -f2-)
                if [ -n "$root_password" ]; then
                    docker compose exec -T mariadb mysqldump -u root -p"$root_password" glpi > "$backup_dir/glpi_database.sql" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}Database exported successfully${NC}"
                    else
                        echo -e "${RED}Database export failed - check your database connection${NC}"
                    fi
                else
                    echo -e "${RED}Could not read MARIADB_ROOT_PASSWORD from .env file${NC}"
                fi
            fi
        fi
    fi
    
    echo -e "${GREEN}Backup created in: $backup_dir${NC}"
fi

# Pull latest images
echo -e "\n${YELLOW}Pulling latest Docker images...${NC}"
docker compose pull

# Check if PHP Dockerfile has changed
php_dockerfile="php-fpm/Dockerfile"
if [ -f "$php_dockerfile" ]; then
    current_hash=$(sha256sum "$php_dockerfile" | awk '{print $1}')
    last_hash=""
    
    if [ -f ".last-php-build-hash" ]; then
        last_hash=$(cat ".last-php-build-hash")
    fi
    
    if [ "$current_hash" != "$last_hash" ] || ! docker images -q "glpi_docker_php" 2>/dev/null | grep -q .; then
        echo -e "\n${YELLOW}Rebuilding PHP-FPM image...${NC}"
        docker compose build --no-cache php
        echo "$current_hash" > ".last-php-build-hash"
        echo -e "${GREEN}PHP-FPM image rebuilt.${NC}"
    else
        echo -e "\n${GRAY}PHP-FPM image is up to date.${NC}"
    fi
fi

# Stop containers if running
if containers_running; then
    echo -e "\n${YELLOW}Stopping containers...${NC}"
    docker compose stop
    echo -e "${GREEN}Containers stopped.${NC}"
fi

# Remove install directory
echo -e "\n${YELLOW}Removing install directory...${NC}"
docker volume rm glpi_docker_glpi-install

# Start containers with updated images
echo -e "\n${YELLOW}Starting containers with updated images...${NC}"
docker compose up -d

# Wait for services to be ready
echo -e "\n${YELLOW}Waiting for services to be ready...${NC}"
sleep 10

# Check container status
echo -e "\n${YELLOW}Checking container status...${NC}"
docker compose ps

# Show logs of any failed containers
failed_containers=$(docker compose ps | grep "Exit" | awk '{print $1}')
if [ -n "$failed_containers" ]; then
    echo -e "\n${RED}Some containers failed to start. Showing logs:${NC}"
    for container in $failed_containers; do
        echo -e "\n${YELLOW}Logs for $container:${NC}"
        docker compose logs --tail=20 "$container"
    done
else
    echo -e "\n${GREEN}All containers are running successfully!${NC}"
fi

# Run Redis configuration if needed
if [ -f "scripts/configure-redis-cache.sh" ]; then
    if confirm_action "Configure Redis cache for GLPI?"; then
        echo -e "\n${YELLOW}Configuring Redis cache...${NC}"
        ./scripts/configure-redis-cache.sh
    fi
fi

echo -e "\n${GREEN}Update completed!${NC}"
echo -e "\n${CYAN}Post-update checklist:${NC}"
echo -e "${WHITE}1. Access GLPI at: https://localhost${NC}"
echo -e "${WHITE}2. Check for GLPI updates in the web interface${NC}"
echo -e "${WHITE}3. Update plugins as needed${NC}"
echo -e "${WHITE}4. Clear GLPI cache if experiencing issues${NC}"

echo -e "\n${CYAN}Usage tips:${NC}"
echo "  --backup    : Create backup before updating"
echo "  --no-backup : Skip backup creation"
echo "  --force     : Skip all confirmations"
echo -e "\nExample: ${CYAN}./update.sh --backup${NC}" 