.PHONY: help setup start stop restart logs backup update clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Initial setup - generate secrets and pull images
	@./setup.sh

start: ## Start all services
	@docker compose up -d
	@echo "Services starting..."
	@sleep 3
	@echo "NPM:      http://localhost:81"
	@echo "Authentik: http://localhost:9000"

stop: ## Stop all services
	@docker compose down

restart: ## Restart all services
	@docker compose restart

logs: ## Show logs for all services
	@docker compose logs -f

logs-npm: ## Show NPM logs only
	@docker compose logs -f npm

logs-auth: ## Show Authentik logs only
	@docker compose logs -f authentik-server

backup: ## Create backup of data directory
	@echo "Creating backup..."
	@docker compose down
	@tar -czvf neoproxy-backup-$$(date +%Y%m%d-%H%M%S).tar.gz ./data
	@docker compose up -d
	@echo "Backup complete!"

update: ## Update all images and restart
	@echo "Pulling latest images..."
	@docker compose pull
	@echo "Restarting services..."
	@docker compose up -d
	@echo "Update complete!"

clean: ## Stop and remove all containers, networks (keeps data)
	@docker compose down --remove-orphans

purge: ## ⚠️  DANGER: Remove everything including data volumes
	@echo "⚠️  This will DELETE ALL DATA! ⚠️"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@docker compose down -v --remove-orphans
	@rm -rf ./data
	@echo "All data purged."

status: ## Show status of all services
	@docker compose ps

health: ## Check health of services
	@echo "Checking health..."
	@docker compose exec -it authentik-server ak healthcheck 2>/dev/null || echo "Authentik health check failed"

shell-npm: ## Open shell in NPM container
	@docker compose exec npm sh

shell-auth: ## Open shell in Authentik container
	@docker compose exec authentik-server /bin/bash
