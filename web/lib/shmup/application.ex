defmodule Shmup.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShmupWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:shmup, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Shmup.PubSub},
      # Start a worker by calling: Shmup.Worker.start_link(arg)
      # {Shmup.Worker, arg},
      # Start to serve requests, typically the last entry
      ShmupWeb.Endpoint,
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
  @impl true
  def config_change(changed, _new, removed) do
    ShmupWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
