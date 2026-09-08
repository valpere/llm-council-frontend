.PHONY: help install dev build preview lint test test-watch test-coverage ci clean

help:
	@echo "Frontend (vmm-rada-web-ui):"
	@echo "  make install        npm install"
	@echo "  make dev            start dev server (http://localhost:5173)"
	@echo "  make build          production build to dist/"
	@echo "  make preview        serve the production build locally"
	@echo "  make lint           eslint ."
	@echo "  make test           vitest run"
	@echo "  make test-watch     vitest (watch mode)"
	@echo "  make test-coverage  vitest run --coverage (writes coverage/)"
	@echo "  make ci             npm ci + lint + test:coverage + build (mirrors .github/workflows/ci.yml)"
	@echo "  make clean          remove dist/, coverage/ and node_modules/"

install:
	npm install

dev:
	npm run dev

build:
	npm run build

preview:
	npm run preview

lint:
	npm run lint

test:
	npm test

test-watch:
	npm run test:watch

test-coverage:
	npm run test:coverage

ci:
	npm ci
	npm run lint
	npm run test:coverage
	npm run build

clean:
	rm -rf dist coverage node_modules
