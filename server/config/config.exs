# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :shmup,
  ecto_repos: [Shmup.Repo],
  generators: [binary_id: true]

# Add support for microseconds at the database level avoid having to configure
# it on every migration file
config :shmup, Shmup.Repo, migration_timestamps: [type: :utc_datetime_usec]

# Configures the endpoint
config :shmup, ShmupWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "zlJBkX+sdzbhy9Zv1LfmSyL88n81AAQ0bSJUtqqPHCcTgcXSXKFVwQeSIdG2kr/c",
  render_errors: [view: ShmupWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Shmup.PubSub,
  live_view: [signing_salt: "L6XCKPWj"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure clustering hosts
config :libcluster, topologies: []

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
