shmup.tar.gz:
	cd assets && pnpm install
	MIX_ENV=prod mix assets.deploy
	MIX_ENV=prod mix compile
	mix phx.gen.release
	MIX_ENV=prod mix release --overwrite
	tar -czvf shmup.tar.gz -C _build/prod/rel shmup
