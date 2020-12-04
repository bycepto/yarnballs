defmodule Ggyo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      {Cluster.Supervisor, [topologies, [name: Ggyo.ClusterSupervisor]]},
      # Start the Ecto repository
      Ggyo.Repo,
      # Start the Telemetry supervisor
      GgyoWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Ggyo.PubSub},
      # Start the Endpoint (http/https)
      GgyoWeb.Endpoint,
      # Start a worker by calling: Ggyo.Worker.start_link(arg)
      # {Ggyo.Worker, arg}
      GgyoWeb.Presence,
      # # Add task supervisor for fire-and-forget async tasks
      {Task.Supervisor, name: Ggyo.TaskSupervisor},
      # Start HTTP clients
      Ggyo.Durak.child_spec(),
      # Start bot move process
      Ggyo.Durak.BotMove,
      # Start yarnballs game loop
      {Ggyo.Yarnballs.GameLoop, Yarnballs.State.init()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ggyo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    GgyoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
