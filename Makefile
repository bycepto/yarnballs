VSN := $(shell cat web/mix.exs | grep version | sed -e 's/.*version: "\(.*\)",/\1/')

.PHONY: dev
dev:
	cd web && mix phx.server

.PHONY: test
test:
	cd yarnballs && mix deps.get --only test && mix test
	cd web && mix deps.get --only test && mix test

.PHONY: build
build:
	$(MAKE) -C web web/_build/prod/shmup-$(VSN).tar.gz
