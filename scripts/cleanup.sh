#!/bin/bash
# GLPI Docker Cleanup Script for Linux/macOS
# This script cleans up Docker containers, volumes, and temporary files

# Color codes
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;90m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
KEEP_VOLUMES=false
KEEP_DATA=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-volumes)
            KEEP_VOLUMES=true
            shift
            ;;
        --keep-data)
            KEEP_DATA=true
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
            echo "  --keep-volumes    Keep Docker volumes (preserves database and files)"
            echo "  --keep-data       Keep all data (volumes and .env file)"
            echo "  --force           Skip all confirmations"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Example: $0 --keep-volumes"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}GLPI Docker Cleanup Script${NC}"
echo -e "${BLUE}=========================${NC}"

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

# Stop and remove containers
echo -e "\n${YELLOW}Stopping and removing containers...${NC}"
if docker-compose ps -q 2>/dev/null | grep -q .; then
    docker-compose down
    echo -e "${GREEN}Containers stopped and removed.${NC}"
else
    echo -e "${GRAY}No running containers found.${NC}"
fi

# Remove volumes if not keeping data
if [ "$KEEP_VOLUMES" = false ] && [ "$KEEP_DATA" = false ]; then
    if confirm_action "Remove all Docker volumes? This will DELETE ALL DATA!"; then
        echo -e "\n${YELLOW}Removing Docker volumes...${NC}"
        docker-compose down -v
        
        # Also remove any orphaned volumes
        volumes=$(docker volume ls -q -f "name=glpi_docker_" 2>/dev/null)
        if [ -n "$volumes" ]; then
            docker volume rm $volumes 2>/dev/null
            echo -e "${GREEN}Volumes removed.${NC}"
        fi
    fi
fi

# Clean up SSL certificates
if ls nginx/ssl/*.pem 2>/dev/null || ls nginx/ssl/*.key 2>/dev/null || ls nginx/ssl/*.crt 2>/dev/null; then
    if confirm_action "Remove SSL certificates?"; then
        echo -e "\n${YELLOW}Removing SSL certificates...${NC}"
        rm -f nginx/ssl/*.pem nginx/ssl/*.key nginx/ssl/*.crt nginx/ssl/*.pfx nginx/ssl/*.p12 2>/dev/null
        echo -e "${GREEN}SSL certificates removed.${NC}"
    fi
fi

# Remove .env file if exists
if [ -f ".env" ]; then
    if confirm_action "Remove .env file?"; then
        echo -e "\n${YELLOW}Removing .env file...${NC}"
        rm -f .env
        echo -e "${GREEN}.env file removed.${NC}"
    fi
fi

# Clean Docker system
if confirm_action "Run Docker system prune to remove unused data?"; then
    echo -e "\n${YELLOW}Cleaning Docker system...${NC}"
    docker system prune -f
    echo -e "${GREEN}Docker system cleaned.${NC}"
fi

# Remove PHP-FPM build cache
if [ -f "php-fpm/.dockerignore" ] || docker images -q "glpi_docker_php" 2>/dev/null | grep -q .; then
    if confirm_action "Remove PHP-FPM Docker image?"; then
        echo -e "\n${YELLOW}Removing PHP-FPM Docker image...${NC}"
        docker rmi glpi_docker_php 2>/dev/null
        docker rmi glpi_docker-php 2>/dev/null
        echo -e "${GREEN}PHP-FPM image removed.${NC}"
    fi
fi

echo -e "\n${GREEN}Cleanup completed!${NC}"
echo -e "\n${CYAN}Usage tips:${NC}"
echo "  --keep-volumes : Keep Docker volumes (preserves database and files)"
echo "  --keep-data    : Keep all data (volumes and .env file)"
echo "  --force        : Skip all confirmations"
echo -e "\nExample: ${CYAN}./cleanup.sh --keep-volumes${NC}" 