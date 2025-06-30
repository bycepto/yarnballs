VSN := $(shell cat web/mix.exs | grep version | sed -e 's/.*version: "\(.*\)",/\1/')

.PHONY: dev
dev:
	mix deps.get --only dev && mix phx.server

.PHONY: test
test:
	mix deps.get --only test && mix test

.PHONY: build
build:
	$(MAKE) web/_build/prod/shmup-$(VSN).tar.gz

_build/prod/shmup-%.tar.gz:
	mix deps.get --only prod
	cd assets && pnpm install
	MIX_ENV=prod mix assets.deploy
	MIX_ENV=prod mix compile
	MIX_ENV=prod mix phx.gen.release
	MIX_ENV=prod mix release --overwrite

# FLY.IO

.PHONY: update-production-env
update-production-env:
	cat .secrets/env.txt | fly secrets import

.PHONY: deploy
deploy:
	fly deploy -c fly.toml
