stack_name=pelican

panel_container_id = $(shell docker ps -qf "name=$(stack_name)_panel")
wings_container_id = $(shell docker ps -qf "name=$(stack_name)_wings")

.PHONY: help
help:
	@echo "Pelican Panel Stack Management"
	@echo ""
	@echo "Usage:"
	@echo "  make deploy               - Deploy the stack (panel + wings)"
	@echo "  make undeploy             - Remove the stack"
	@echo "  make status               - Show services status"
	@echo "  make logs-panel           - Follow panel logs"
	@echo "  make logs-wings           - Follow wings logs"
	@echo "  make bash-panel           - Shell inside the panel container"
	@echo "  make bash-wings           - Shell inside the wings container"
	@echo "  make artisan CMD='...'    - Run an artisan command in the panel (e.g. CMD='p:user:make')"
	@echo "  make wings-configure TOKEN='...' - Configure wings from a panel auto-deploy token"
	@echo "  make backup               - Backup panel data + game servers data"

.PHONY: deploy
deploy:
	@if [ ! -f .env ]; then \
		echo "⚠️  .env not found, creating from example..."; \
		cp .env.example .env; \
	fi
	@mkdir -p panel/data/plugins panel/logs wings/etc wings/logs wings/data wings/tmp
	@set -a && . ./.env && set +a && \
		PELICAN_ROOT=$$(pwd) docker stack deploy -c docker-compose.yaml $(stack_name)
	@echo "✅ Deployed!"
	@echo "🦤 Panel: https://$$(grep ^PANEL_DOMAIN .env | cut -d= -f2)/installer (first run only)"

.PHONY: undeploy
undeploy:
	docker stack rm $(stack_name)

.PHONY: status
status:
	docker stack services $(stack_name)

.PHONY: logs-panel
logs-panel:
	docker service logs -f $(stack_name)_panel

.PHONY: logs-wings
logs-wings:
	docker service logs -f $(stack_name)_wings

.PHONY: bash-panel
bash-panel:
	docker exec -it $(panel_container_id) bash

.PHONY: bash-wings
bash-wings:
	docker exec -it $(wings_container_id) bash

.PHONY: artisan
artisan:
	docker exec -it $(panel_container_id) php artisan $(CMD)

# Paste the token command from Admin → Nodes → <node> → Configuration → Auto Deploy,
# only the arguments: make wings-configure TOKEN="--panel-url https://... --token ... --node 1"
# The generated config is then patched so all wings data lives under ./wings/.
.PHONY: wings-configure
wings-configure:
	docker exec -it $(wings_container_id) wings configure $(TOKEN)
	sudo ./scripts/patch-wings-config.sh
	docker service update --force $(stack_name)_wings

.PHONY: backup
backup:
	@echo "Creating backup..."
	sudo tar -czf backup-$(shell date +%Y%m%d-%H%M%S).tar.gz panel wings/etc wings/data
	@echo "Backup created: backup-$(shell date +%Y%m%d-%H%M%S).tar.gz"
