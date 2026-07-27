.PHONY: help dev web mobile phone ios db db-down migrate backend-check mobile-check test

WEB_API_URL := http://localhost:8000/api/v1
MOBILE_API_URL := http://10.0.2.2:8000/api/v1
PHONE_API_URL ?= http://192.168.1.50:8000/api/v1
WEB_PORT := 52134

help:
	@echo "Kullanilabilir komutlar:"
	@echo "  make dev           Backend'i calistir"
	@echo "  make web           Flutter web'i Chrome'da calistir"
	@echo "  make mobile        Android emulatorunde calistir"
	@echo "  make phone         Fiziksel Android telefonda calistir"
	@echo "  make ios           iOS simulatorunde calistir"
	@echo "  make db            PostgreSQL ve Redis'i baslat"
	@echo "  make db-down       Altyapi containerlarini durdur"
	@echo "  make migrate       Veritabani migrationlarini calistir"
	@echo "  make backend-check Backend kontrollerini calistir"
	@echo "  make mobile-check  Flutter kontrollerini calistir"
	@echo "  make test          Tum kontrolleri calistir"

dev:
	cd backend && uv run uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

web:
	cd mobile && flutter run -d chrome --web-port $(WEB_PORT) --dart-define=API_BASE_URL=$(WEB_API_URL)

mobile:
	cd mobile && flutter run -d android --dart-define=API_BASE_URL=$(MOBILE_API_URL)

phone:
	cd mobile && flutter run --dart-define=API_BASE_URL=$(PHONE_API_URL)

ios:
	cd mobile && flutter run -d ios --dart-define=API_BASE_URL=$(WEB_API_URL)

db:
	docker compose up -d postgres redis

db-down:
	docker compose down

migrate:
	cd backend && uv run alembic upgrade head

backend-check:
	cd backend && uv run ruff check src tests
	cd backend && uv run mypy src
	cd backend && uv run pytest -q

mobile-check:
	cd mobile && flutter analyze
	cd mobile && flutter test

test: backend-check mobile-check
