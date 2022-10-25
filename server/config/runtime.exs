import Config

if config_env() == :dev do
  check_origin =
    System.get_env("CORS_ORIGINS", "http://localhost:3003,http://localhost:3004")
    |> String.split(",")

  config :shmup, ShmupWeb.Endpoint, check_origin: check_origin
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  pool_size =
    System.get_env("POOL_SIZE", "10")
    |> String.to_integer()

  config :shmup, Shmup.Repo,
    # ssl: true,f
    url: database_url,
    pool_size: pool_size

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  cors_origins =
    System.get_env("CORS_ORIGINS") ||
      raise """
      environment variable CORS_ORIGINS is missing.
      """

  check_origin = String.split(cors_origins, ",")

  config :shmup, ShmupWeb.Endpoint,
    http: [
      port: String.to_integer(System.get_env("PORT") || "4000"),
      transport_options: [socket_opts: [:inet6]]
    ],
    check_origin: check_origin,
    secret_key_base: secret_key_base

  # Configure clustering hosts

  release_name =
    System.get_env("RELEASE_NAME") ||
      raise """
      environment variable RELEASE_NAME is missing.
      """

  service_name =
    System.get_env("SERVICE_NAME") ||
      raise """
      environment variable SERVICE_NAME is missing.
      """

  config :libcluster,
    topologies: [
      shmup: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [
          # https://docs.docker.com/network/overlay/#container-discovery
          query: "tasks.#{service_name}",
          node_basename: release_name
        ]
      ]
    ]

  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.
end
