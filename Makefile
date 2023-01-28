TAG=bycepto/shmup

dev:
	./scripts/run_local.sh

test:
	cd webclient && npm run build
	cd server && mix test
	cd yarnballs && mix test

build:
	docker build --tag="$(TAG)" .

push-images: build
	docker push "$(TAG)"

# Backend app tasks

server/%:
	$(MAKE) -C server $*
