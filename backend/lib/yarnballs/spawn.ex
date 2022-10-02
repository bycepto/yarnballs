defmodule Yarnballs.Spawner do
  @moduledoc false

  require Logger
  alias Yarnballs.Enemies

  @doc """
  The time to wait between each spawn in milliseconds.
  """
  @callback interval() :: non_neg_integer()

  @doc """
  The maximum number of enemies to spawn.
  """
  @callback limit() :: non_neg_integer()

  @doc """
  A list of modules that can spawn from which to select from at each spawn interval.

  These choices are weighted if they are in form {`weight`, `module`}.
  """
  @callback choices() :: Enumerable.t(module | {pos_integer, module})

  defp spawn_one(impl) do
    impl.choices
    |> Enum.flat_map(fn
      {weight, mod} -> Enum.map(1..weight, fn _ -> mod end)
      mod -> [mod]
    end)
    |> Enum.random()
    |> (fn x -> x.spawn() end).()
  end

  @spec spawn(module, Enemies.t()) :: Enemies.t()
  def spawn(impl, enemies) do
    last_spawned_at = Yarnballs.Utils.now_milliseconds()
    dt = last_spawned_at - enemies.last_spawned_at

    if length(enemies.entities) < impl.limit && dt > impl.interval do
      Logger.debug("spawning enemy")

      # TODO: generalize enemy with protocol or behavior?
      enemy = spawn_one(impl)
      entities = [enemy | enemies.entities]

      %{
        enemies
        | entities: entities,
          last_spawned_at: last_spawned_at,
          spawned_count: enemies.spawned_count + 1
      }
    else
      enemies
    end
  end
end

defmodule Yarnballs.Level0Spawner do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy.Bouncer
  alias Yarnballs.Enemy.Rock

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 10

  @impl Spawner
  def interval(), do: 1000

  @impl Spawner
  def choices(), do: [Bouncer, Rock]
end

defmodule Yarnballs.Level1Spawner do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy.Bouncer
  alias Yarnballs.Enemy.Rock

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 20

  @impl Spawner
  def interval(), do: 500

  @impl Spawner
  def choices(), do: [Bouncer, Rock]
end
