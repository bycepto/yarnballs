shmup.tar.gz:
	mix deps.get --only prod
	cd assets && pnpm install
	MIX_ENV=prod mix assets.deploy
	MIX_ENV=prod mix compile
	MIX_ENV=prod mix phx.gen.release
	MIX_ENV=prod mix release --overwrite
	tar -czvf shmup.tar.gz -C _build/prod/rel shmup
