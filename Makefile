.PHONY: dev
dev:
	cd web && mix phx.server

test:
	cd web && mix test
	cd yarnballs && mix test

build:
	$(MAKE) -C web shmup.tar.gz
