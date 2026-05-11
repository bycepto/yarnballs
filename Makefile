GOCACHE ?= /tmp/gocache

.PHONY: dev
dev: setup-frontend
	bash etc/scripts/dev.sh

.PHONY: setup-frontend
setup-frontend:
	pnpm -C assets install

.PHONY: test-go
test-go:
	GOCACHE=$(GOCACHE) go test ./...

.PHONY: generate-token-signing-key
generate-token-signing-key:
	GOCACHE=$(GOCACHE) go run ./cmd/generate_token_signing_key

.PHONY: build-frontend
build-frontend:
	cd assets && APP_HOST=localhost:8080 pnpm build -- --deploy

.PHONY: build-go
build-go:
	GOCACHE=$(GOCACHE) go build ./cmd/server

.PHONY: build
build: build-frontend build-go

.PHONY: prod-local
prod-local:
	cd assets && APP_HOST=localhost:8080 APP_SCHEME=http pnpm build -- --deploy
	GOCACHE=$(GOCACHE) go build ./cmd/server
	./server

# FLY.IO

.PHONY: update-production-env
update-production-env:
	cat .secrets/env.txt | fly secrets import

.PHONY: deploy
deploy:
	fly deploy -c fly.toml

.PHONY: deploy-from-local
deploy-from-local:
	fly deploy -c fly.toml --local-only

.PHONY: build-from_local
build-from-local:
	fly deploy -c fly.toml --local-only --build-only
