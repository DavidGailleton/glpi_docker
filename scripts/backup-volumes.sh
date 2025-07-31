#!/bin/bash
# Docker Volume Backup Script for GLPI
# This script creates direct backups of all Docker volumes

# Color codes
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;90m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="glpi_docker"
BACKUP_DIR="volume-backups"
COMPRESS=true
VERBOSE=false

# Volume list from docker-compose.yml
VOLUMES=(
    "redis-cache"
    "glpi-db"
    "marketplace"
    "config"
    "files"
)

# Default values
OPERATION=""
BACKUP_NAME=""
FORCE=false

# Functions
show_help() {
    echo -e "${BLUE}Docker Volume Backup Script${NC}"
    echo -e "${BLUE}==========================${NC}"
    echo ""
    echo "Usage: $0 [OPERATION] [OPTIONS]"
    echo ""
    echo "Operations:"
    echo "  backup              Create backup of all volumes"
    echo "  restore BACKUP_NAME Restore volumes from backup"
    echo "  list               List available backups"
    echo "  list-volumes       List current volumes and their sizes"
    echo ""
    echo "Options:"
    echo "  --no-compress      Don't compress backup files"
    echo "  --force           Skip confirmations"
    echo "  --verbose         Show detailed output"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 backup                           # Create new backup"
    echo "  $0 restore backup_20240128_143022   # Restore from specific backup"
    echo "  $0 list                            # List all backups"
    echo "  $0 list-volumes                    # Show current volume info"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${GRAY}[VERBOSE]${NC} $1"
    fi
}

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

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Cannot connect to Docker daemon"
        exit 1
    fi
}

get_volume_full_name() {
    local volume_name="$1"
    echo "${PROJECT_NAME}_${volume_name}"
}

volume_exists() {
    local volume_name="$1"
    docker volume inspect "$volume_name" >/dev/null 2>&1
}

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="backup_${timestamp}"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_info "Creating volume backup: $backup_name"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Create metadata file
    cat > "${backup_path}/metadata.txt" << EOF
Backup Name: $backup_name
Timestamp: $(date)
Project: $PROJECT_NAME
Volumes: ${VOLUMES[*]}
Compressed: $COMPRESS
EOF
    
    # Backup each volume
    for volume in "${VOLUMES[@]}"; do
        local full_volume_name=$(get_volume_full_name "$volume")
        
        if ! volume_exists "$full_volume_name"; then
            log_warning "Volume $full_volume_name does not exist, skipping"
            continue
        fi
        
        log_info "Backing up volume: $volume"
        log_verbose "Full volume name: $full_volume_name"
        
        # Create volume backup using a temporary container
        local backup_file="${backup_path}/${volume}.tar"
        
        if [ "$VERBOSE" = true ]; then
            docker run --rm \
                -v "$full_volume_name":/source:ro \
                -v "$(pwd)/${backup_path}":/backup \
                alpine:latest \
                tar -cvf "/backup/${volume}.tar" -C /source .
        else
            docker run --rm \
                -v "$full_volume_name":/source:ro \
                -v "$(pwd)/${backup_path}":/backup \
                alpine:latest \
                tar -cf "/backup/${volume}.tar" -C /source . 2>/dev/null
        fi
        
        if [ $? -eq 0 ]; then
            log_verbose "Volume $volume backed up successfully"
            
            # Compress if requested
            if [ "$COMPRESS" = true ]; then
                log_verbose "Compressing $volume.tar"
                gzip "${backup_file}"
                if [ $? -eq 0 ]; then
                    log_verbose "Compression completed for $volume"
                else
                    log_warning "Compression failed for $volume"
                fi
            fi
        else
            log_error "Failed to backup volume: $volume"
            return 1
        fi
    done
    
    # Create backup summary
    cat > "${backup_path}/summary.txt" << EOF
Backup Summary
==============
Backup Name: $backup_name
Date: $(date)
Total Volumes: ${#VOLUMES[@]}

Volume Details:
EOF
    
    for volume in "${VOLUMES[@]}"; do
        local full_volume_name=$(get_volume_full_name "$volume")
        if volume_exists "$full_volume_name"; then
            local backup_file="${backup_path}/${volume}.tar"
            if [ "$COMPRESS" = true ]; then
                backup_file="${backup_file}.gz"
            fi
            
            if [ -f "$backup_file" ]; then
                local size=$(ls -lh "$backup_file" | awk '{print $5}')
                echo "  ✓ $volume ($size)" >> "${backup_path}/summary.txt"
            else
                echo "  ✗ $volume (failed)" >> "${backup_path}/summary.txt"
            fi
        else
            echo "  - $volume (not found)" >> "${backup_path}/summary.txt"
        fi
    done
    
    log_success "Backup created: $backup_path"
    cat "${backup_path}/summary.txt"
    
    # Show total backup size
    local total_size=$(du -sh "$backup_path" | cut -f1)
    log_info "Total backup size: $total_size"
}

restore_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    if [ ! -d "$backup_path" ]; then
        log_error "Backup not found: $backup_name"
        log_info "Available backups:"
        list_backups
        exit 1
    fi
    
    log_warning "This will OVERWRITE existing volume data!"
    if ! confirm_action "Are you sure you want to restore from $backup_name?"; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    log_info "Restoring from backup: $backup_name"
    
    # Check if containers are running
    if docker compose ps -q 2>/dev/null | grep -q .; then
        log_warning "Containers are currently running"
        if confirm_action "Stop containers before restore? (Recommended)"; then
            log_info "Stopping containers..."
            docker compose down
        fi
    fi
    
    # Restore each volume
    for volume in "${VOLUMES[@]}"; do
        local full_volume_name=$(get_volume_full_name "$volume")
        local backup_file="${backup_path}/${volume}.tar"
        
        # Check for compressed version
        if [ ! -f "$backup_file" ] && [ -f "${backup_file}.gz" ]; then
            backup_file="${backup_file}.gz"
        fi
        
        if [ ! -f "$backup_file" ]; then
            log_warning "Backup file not found for volume: $volume"
            continue
        fi
        
        log_info "Restoring volume: $volume"
        log_verbose "Full volume name: $full_volume_name"
        
        # Create volume if it doesn't exist
        if ! volume_exists "$full_volume_name"; then
            log_verbose "Creating volume: $full_volume_name"
            docker volume create "$full_volume_name"
        fi
        
        # Determine if file is compressed
        local extract_cmd="tar -xf"
        if [[ "$backup_file" == *.gz ]]; then
            extract_cmd="tar -xzf"
        fi
        
        # Restore volume using temporary container
        if [ "$VERBOSE" = true ]; then
            docker run --rm \
                -v "$full_volume_name":/target \
                -v "$(pwd)/${backup_file}":/backup.tar$([ "${backup_file##*.}" = "gz" ] && echo ".gz") \
                alpine:latest \
                sh -c "cd /target && $extract_cmd /backup.tar$([ "${backup_file##*.}" = "gz" ] && echo ".gz") --overwrite"
        else
            docker run --rm \
                -v "$full_volume_name":/target \
                -v "$(pwd)/${backup_file}":/backup.tar$([ "${backup_file##*.}" = "gz" ] && echo ".gz") \
                alpine:latest \
                sh -c "cd /target && $extract_cmd /backup.tar$([ "${backup_file##*.}" = "gz" ] && echo ".gz") --overwrite" 2>/dev/null
        fi
        
        if [ $? -eq 0 ]; then
            log_verbose "Volume $volume restored successfully"
        else
            log_error "Failed to restore volume: $volume"
            return 1
        fi
    done
    
    log_success "Restore completed from: $backup_name"
    log_info "You can now start your containers with: docker compose up -d"
}

list_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "No backups directory found"
        return
    fi
    
    local backups=($(ls -1 "$BACKUP_DIR" 2>/dev/null | grep "^backup_"))
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_info "No backups found"
        return
    fi
    
    echo -e "${BLUE}Available Backups:${NC}"
    echo "=================="
    
    for backup in "${backups[@]}"; do
        local backup_path="${BACKUP_DIR}/${backup}"
        local size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)
        local date=""
        
        if [ -f "${backup_path}/metadata.txt" ]; then
            date=$(grep "Timestamp:" "${backup_path}/metadata.txt" | cut -d: -f2- | xargs)
        fi
        
        echo -e "${GREEN}$backup${NC} (${size})"
        if [ -n "$date" ]; then
            echo -e "  ${GRAY}Created: $date${NC}"
        fi
        
        if [ -f "${backup_path}/summary.txt" ]; then
            local volume_count=$(grep -c "✓" "${backup_path}/summary.txt" 2>/dev/null || echo "?")
            echo -e "  ${GRAY}Volumes: $volume_count${NC}"
        fi
        echo ""
    done
}

list_volumes() {
    echo -e "${BLUE}Current Docker Volumes:${NC}"
    echo "======================"
    
    for volume in "${VOLUMES[@]}"; do
        local full_volume_name=$(get_volume_full_name "$volume")
        
        if volume_exists "$full_volume_name"; then
            # Get volume size (approximate)
            local size=$(docker run --rm -v "$full_volume_name":/data alpine:latest sh -c "du -sh /data" 2>/dev/null | cut -f1 || echo "?")
            echo -e "${GREEN}✓${NC} $volume (${full_volume_name}) - ${size}"
        else
            echo -e "${RED}✗${NC} $volume (${full_volume_name}) - not found"
        fi
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        backup)
            OPERATION="backup"
            shift
            ;;
        restore)
            OPERATION="restore"
            shift
            if [[ $# -gt 0 && $1 != --* ]]; then
                BACKUP_NAME="$1"
                shift
            else
                log_error "Restore operation requires backup name"
                exit 1
            fi
            ;;
        list)
            OPERATION="list"
            shift
            ;;
        list-volumes)
            OPERATION="list-volumes"
            shift
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
check_docker

case "$OPERATION" in
    backup)
        create_backup
        ;;
    restore)
        restore_backup "$BACKUP_NAME"
        ;;
    list)
        list_backups
        ;;
    list-volumes)
        list_volumes
        ;;
    *)
        log_error "No operation specified"
        show_help
        exit 1
        ;;
esac 