# GLPI Docker Makefile
# Provides easy commands for common tasks

.PHONY: help up down start stop restart status logs clean clean-all update backup setup

# Default target
help:
	@echo "GLPI Docker Management Commands"
	@echo "=============================="
	@echo ""
	@echo "Setup & Start:"
	@echo "  make setup       - Initial setup (create .env, generate SSL)"
	@echo "  make up          - Start all containers"
	@echo "  make down        - Stop and remove containers"
	@echo "  make start       - Start stopped containers"
	@echo "  make stop        - Stop running containers"
	@echo "  make restart     - Restart all containers"
	@echo ""
	@echo "Monitoring:"
	@echo "  make status      - Show container status"
	@echo "  make logs        - Show container logs"
	@echo "  make logs-f      - Follow container logs"
	@echo ""
	@echo "Maintenance:"
	@echo "  make update      - Update containers and images"
	@echo "  make backup      - Create backup of data and configs"
	@echo "  make clean       - Clean containers (keep data)"
	@echo "  make clean-all   - Clean everything (REMOVES ALL DATA!)"
	@echo ""
	@echo "Database:"
	@echo "  make db-shell    - Access MariaDB shell"
	@echo "  make db-backup   - Backup database only"
	@echo ""
	@echo "GLPI:"
	@echo "  make glpi-shell  - Access GLPI container shell"
	@echo "  make redis-config - Configure Redis cache"

# Setup commands
setup:
	@if [ ! -f .env ]; then \
		echo "Creating .env file..."; \
		echo "# Timezone configuration" > .env; \
		echo "TZ=Europe/Paris" >> .env; \
		echo "" >> .env; \
		echo "# MariaDB configuration" >> .env; \
		echo "MARIADB_ROOT_PASSWORD=change_this_root_password" >> .env; \
		echo "MARIADB_DATABASE=glpi" >> .env; \
		echo "MARIADB_USER=glpi_user" >> .env; \
		echo "MARIADB_PASSWORD=change_this_password" >> .env; \
		echo "" >> .env; \
		echo "# GLPI database configuration" >> .env; \
		echo "GLPI_DB_HOST=mariadb" >> .env; \
		echo "GLPI_DB_PORT=3306" >> .env; \
		echo "GLPI_DB_NAME=glpi" >> .env; \
		echo "GLPI_DB_USER=glpi_user" >> .env; \
		echo "GLPI_DB_PASSWORD=change_this_password" >> .env; \
		echo ""; \
		echo "✓ Created .env file"; \
		echo "⚠️  IMPORTANT: Edit .env and change all passwords before continuing!"; \
	else \
		echo "✓ .env file already exists"; \
	fi
	@echo ""
	@echo "Generating SSL certificates..."
	@if [ -f ./scripts/generate-self-signed-cert.sh ]; then \
		chmod +x ./scripts/generate-self-signed-cert.sh; \
		./scripts/generate-self-signed-cert.sh; \
	else \
		echo "⚠️  SSL generation script not found"; \
	fi

# Container management
up:
	docker-compose up -d
	@echo ""
	@echo "✓ Containers started"
	@echo "Access GLPI at: https://localhost"

down:
	docker-compose down

start:
	docker-compose start

stop:
	docker-compose stop

restart:
	docker-compose restart

# Monitoring
status:
	docker-compose ps

logs:
	docker-compose logs

logs-f:
	docker-compose logs -f

# Maintenance
update:
	@if [ -f ./scripts/update.sh ]; then \
		chmod +x ./scripts/update.sh; \
		./scripts/update.sh --backup; \
	elif [ -f ./scripts/update.ps1 ]; then \
		powershell -ExecutionPolicy Bypass -File ./scripts/update.ps1 -Backup; \
	else \
		echo "Update script not found"; \
		exit 1; \
	fi

backup:
	@if [ -f ./scripts/update.sh ]; then \
		chmod +x ./scripts/update.sh; \
		./scripts/update.sh --backup --no-update; \
	elif [ -f ./scripts/update.ps1 ]; then \
		powershell -ExecutionPolicy Bypass -File ./scripts/update.ps1 -Backup -NoUpdate; \
	else \
		echo "Creating manual backup..."; \
		mkdir -p "backup_$$(date +%Y%m%d_%H%M%S)"; \
		cp -r .env php-fpm/conf.d nginx/conf.d "backup_$$(date +%Y%m%d_%H%M%S)/"; \
	fi

clean:
	@if [ -f ./scripts/cleanup.sh ]; then \
		chmod +x ./scripts/cleanup.sh; \
		./scripts/cleanup.sh --keep-volumes; \
	elif [ -f ./scripts/cleanup.ps1 ]; then \
		powershell -ExecutionPolicy Bypass -File ./scripts/cleanup.ps1 -KeepVolumes; \
	else \
		docker-compose down; \
		docker system prune -f; \
	fi

clean-all:
	@echo "⚠️  WARNING: This will DELETE ALL DATA!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		if [ -f ./scripts/cleanup.sh ]; then \
			chmod +x ./scripts/cleanup.sh; \
			./scripts/cleanup.sh --force; \
		elif [ -f ./scripts/cleanup.ps1 ]; then \
			powershell -ExecutionPolicy Bypass -File ./scripts/cleanup.ps1 -Force; \
		else \
			docker-compose down -v; \
			docker system prune -af; \
		fi \
	else \
		echo "Cancelled"; \
	fi

# Database commands
db-shell:
	@if [ -f .env ]; then \
		. ./.env && docker-compose exec mariadb mysql -u root -p$$MARIADB_ROOT_PASSWORD; \
	else \
		docker-compose exec mariadb mysql -u root -p; \
	fi

db-backup:
	@mkdir -p backups
	@if [ -f .env ]; then \
		. ./.env && docker-compose exec -T mariadb mysqldump -u root -p$$MARIADB_ROOT_PASSWORD glpi > "backups/glpi_$$(date +%Y%m%d_%H%M%S).sql"; \
		echo "✓ Database backed up to backups/glpi_$$(date +%Y%m%d_%H%M%S).sql"; \
	else \
		echo "⚠️  .env file not found - cannot read database password"; \
	fi

# GLPI specific
glpi-shell:
	docker-compose exec php /bin/bash

redis-config:
	@if [ -f ./scripts/configure-redis-cache.sh ]; then \
		chmod +x ./scripts/configure-redis-cache.sh; \
		./scripts/configure-redis-cache.sh; \
	elif [ -f ./scripts/configure-redis-cache.ps1 ]; then \
		powershell -ExecutionPolicy Bypass -File ./scripts/configure-redis-cache.ps1; \
	else \
		echo "Redis configuration script not found"; \
	fi

# Quick access to common tasks
.PHONY: build rebuild
build:
	docker-compose build

rebuild:
	docker-compose build --no-cache 