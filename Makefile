COMPOSE      = docker-compose
COMPOSE_DEV  = docker-compose -f docker-compose.dev.yml

BACKEND_URL  = http://localhost:8000
FRONTEND_URL = http://localhost:3000
OLLAMA_URL   = http://localhost:11434

.DEFAULT_GOAL := help

# ── Help ──────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "  Personal Health Video Analyser"
	@echo ""
	@echo "  Production"
	@echo "    make up          Build and start all services"
	@echo "    make down        Stop all services"
	@echo "    make build       Build images without starting"
	@echo "    make restart     Restart all services"
	@echo "    make restart-backend   Restart backend only"
	@echo "    make restart-frontend  Restart frontend only"
	@echo ""
	@echo "  Development"
	@echo "    make dev         Start dev stack (hot reload, auto-starts Ollama)"
	@echo "    make dev-down    Stop dev stack"
	@echo ""
	@echo "  Logs"
	@echo "    make logs        Tail all logs"
	@echo "    make logs-back   Tail backend logs"
	@echo "    make logs-front  Tail frontend logs"
	@echo ""
	@echo "  Health"
	@echo "    make health      Check backend + Ollama status"
	@echo "    make open        Open app in browser"
	@echo ""
	@echo "  Cleanup"
	@echo "    make clean       Remove containers and images"
	@echo "    make clean-all   Remove containers, images, and database volume"
	@echo "    make prune       Docker system prune (reclaim disk space)"
	@echo ""

# ── Production ────────────────────────────────────────────────────────────────
.PHONY: up
up: check-ollama
	$(COMPOSE) up --build -d
	@echo ""
	@echo "  Services started:"
	@echo "    Frontend  → $(FRONTEND_URL)"
	@echo "    Backend   → $(BACKEND_URL)/docs"
	@echo ""

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: build
build:
	$(COMPOSE) build

.PHONY: restart
restart:
	$(COMPOSE) restart

.PHONY: restart-backend
restart-backend:
	$(COMPOSE) restart backend

.PHONY: restart-frontend
restart-frontend:
	$(COMPOSE) restart frontend

# ── Development ───────────────────────────────────────────────────────────────
.PHONY: dev
dev: start-ollama
	$(COMPOSE_DEV) up -d
	@echo ""
	@echo "  Dev stack started (hot reload):"
	@echo "    Frontend  → $(FRONTEND_URL)"
	@echo "    Backend   → $(BACKEND_URL)/docs"
	@echo "    Ollama    → $(OLLAMA_URL)"
	@echo ""

.PHONY: dev-down
dev-down:
	$(COMPOSE_DEV) down

# ── Logs ──────────────────────────────────────────────────────────────────────
.PHONY: logs
logs:
	$(COMPOSE) logs -f

.PHONY: logs-back
logs-back:
	$(COMPOSE) logs -f backend

.PHONY: logs-front
logs-front:
	$(COMPOSE) logs -f frontend

# ── Health ────────────────────────────────────────────────────────────────────
.PHONY: health
health:
	@echo "Checking backend..."
	@curl -sf $(BACKEND_URL)/api/v1/health && echo "  backend  OK" || echo "  backend  UNREACHABLE"
	@echo "Checking Ollama..."
	@curl -sf $(OLLAMA_URL)/api/tags > /dev/null && echo "  ollama   OK" || echo "  ollama   UNREACHABLE"

.PHONY: start-ollama
start-ollama:
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/start-ollama.ps1 -OllamaUrl $(OLLAMA_URL)

.PHONY: check-ollama
check-ollama:
	@curl -sf $(OLLAMA_URL)/api/tags > /dev/null || \
		(echo "ERROR: Ollama is not running on $(OLLAMA_URL). Start it first." && exit 1)

.PHONY: open
open:
	start $(FRONTEND_URL)

# ── Cleanup ───────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	$(COMPOSE) down --rmi local
	$(COMPOSE_DEV) down --rmi local 2>/dev/null || true

.PHONY: clean-all
clean-all:
	$(COMPOSE) down -v --rmi local
	$(COMPOSE_DEV) down -v --rmi local 2>/dev/null || true
	@echo "  Containers, images, and SQLite volume removed."

.PHONY: prune
prune:
	docker system prune -f
	@echo "  Docker system pruned."
