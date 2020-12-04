SHELL = /bin/sh

# Combined

dev:
	./scripts/run_local.sh

dev-docker:
	./scripts/run_local_docker.sh

test: test-frontend test-backend test-durak

build: build-backend build-durak

build-priv: build-backend-priv build-durak

# Front-end

test-frontend:
	cd frontend && elm-test

# Back-end

shell-backend:
	cd backend && iex -S mix


test-backend:
	cd backend && mix test

build-backend:
	cd backend && docker build . --tag=bycepto/ggyo

build-backend-priv:
	cd backend && ./scripts/build_backend_local.sh

reset-db:
	cd backend && MIX_ENV='dev' mix do ecto.drop, ecto.setup

generate-secrets:
	echo "cookie"
	elixir -e 'Base.url_encode64(:crypto.strong_rand_bytes(40)) |> IO.puts'
	echo "base key"
	cd backend && mix phx.gen.secret

# Durak server

test-durak:
	cd durak_server && poetry run pytest

build-durak:
	cd durak_server && docker build . --tag=bycepto/ggyo_durak


# Ad-hoc

test-one:
	# cd backend && mix test test/ggyo/hanabi_test.exs:107
