defmodule Shmup.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      {Cluster.Supervisor, [topologies, [name: Shmup.ClusterSupervisor]]},
      # Start the Ecto repository
      Shmup.Repo,
      # Start the Telemetry supervisor
      ShmupWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Shmup.PubSub},
      # Start the Endpoint (http/https)
      ShmupWeb.Endpoint,
      # Start a worker by calling: Shmup.Worker.start_link(arg)
      # {Shmup.Worker, arg}
      ShmupWeb.Presence,
      # Start yarnballs game loop
      {ShmupWeb.GameLoop, Yarnballs.State.init()},
      # Track users leaving game
      {ShmupWeb.ChannelWatcher, :games}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Shmup.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ShmupWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
