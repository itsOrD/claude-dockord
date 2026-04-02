.PHONY: build shell yolo ralph agents stop clean status logs login rc view-logs

# All volume names use this prefix (matches COMPOSE_PROJECT_NAME in claude-dockord CLI)
COMPOSE_PROJECT_NAME := claude-dockord
export COMPOSE_PROJECT_NAME

# ── Build & Auth ──────────────────────────────────────────────────
build:
	docker compose build

login:
	docker compose run --rm claude claude auth login

# ── Interactive (requires P=path) ─────────────────────────────────
shell:
	docker compose run --rm -v "$(P):/workspace" claude zsh

yolo:
	docker compose run --rm -v "$(P):/workspace" claude claude --dangerously-skip-permissions

task:
	docker compose run --rm -v "$(P):/workspace" claude claude --dangerously-skip-permissions -p "$(T)"

# ── Remote Control ────────────────────────────────────────────────
rc:
	@echo "Starting container. Once inside, type /rc for Remote Control."
	@echo ""
	docker compose run --rm -v "$(P):/workspace" claude claude --dangerously-skip-permissions

# ── Ralph Loop ────────────────────────────────────────────────────
ralph-install:
	docker compose run --rm claude claude --dangerously-skip-permissions -p \
		'/plugin install ralph-wiggum@claude-plugins-official'

ralph:
	docker compose run --rm -v "$(P):/workspace" claude claude --dangerously-skip-permissions -p \
		'/ralph-loop:ralph-loop "$(T)" --max-iterations 30'

# ── Auto-Restart ──────────────────────────────────────────────────
auto:
	docker compose run --rm -v "$(P):/workspace" claude bash /opt/templates/auto-restart.sh "$(T)"

# ── Agent Teams ───────────────────────────────────────────────────
agents:
	docker compose run --rm -v "$(P):/workspace" claude claude --dangerously-skip-permissions

agents-task:
	docker compose run --rm -v "$(P):/workspace" claude claude --dangerously-skip-permissions -p "$(T)"

attach:
	docker exec -it claude-dockord tmux attach 2>/dev/null || echo "No tmux session."

# ── Monitoring ────────────────────────────────────────────────────
monitor:
	docker exec -it claude-dockord ccusage blocks --live

usage:
	docker exec -it claude-dockord ccusage daily --breakdown

# ── Agent Logs ────────────────────────────────────────────────────
view-logs:
	@docker run --rm -v $(COMPOSE_PROJECT_NAME)_agent-logs:/logs alpine \
		sh -c 'ls -la /logs/ 2>/dev/null || echo "No logs yet."'

read-log:
	@docker run --rm -v $(COMPOSE_PROJECT_NAME)_agent-logs:/logs alpine cat "/logs/$(F)"

export-logs:
	mkdir -p ./agent-logs-export
	docker run --rm \
		-v $(COMPOSE_PROJECT_NAME)_agent-logs:/src \
		-v $(CURDIR)/agent-logs-export:/dst \
		alpine cp -r /src/. /dst/
	@echo "Logs exported to ./agent-logs-export/"

# ── Container Management ─────────────────────────────────────────
stop:
	docker compose down

clean:
	docker compose down --rmi local

nuke:
	docker compose down -v --rmi local

status:
	docker compose ps

logs:
	docker compose logs -f
