# Perintah bersama. Di Windows jalankan lewat Git Bash (make tersedia via `choco install make` atau `scoop install make`).

COMPOSE = docker compose -f infra/docker-compose.yml --env-file .env

.PHONY: help dev down logs test contracts

help:
	@echo "make dev        - nyalakan Postgres + Mosquitto"
	@echo "make down       - matikan semua container"
	@echo "make logs       - lihat log container"
	@echo "make test       - jalankan semua tes"
	@echo "make contracts  - ekspor openapi.json ke packages/contracts"

dev:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

# Diisi saat tiap bagian sudah punya kode (R-01, R-02, R-09).
test:
	python packages/contracts/test_contracts.py
	pytest services/api/tests

# Ekspor OpenAPI (R-07)
contracts:
	python services/api/scripts/export_openapi.py
