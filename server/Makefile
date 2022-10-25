shell:
	iex -S mix

reset-local-db:
	MIX_ENV='dev' mix do ecto.drop, ecto.setup

generate-secrets:
	echo "cookie"
	elixir -e 'Base.url_encode64(:crypto.strong_rand_bytes(40)) |> IO.puts'
	echo "base key"
	mix phx.gen.secret
