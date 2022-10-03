defmodule Yarnballs.Spawner do
  @moduledoc false

  require Logger
  alias Yarnballs.Enemy
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
  Spawn a single enemy. This will be called on every update interval if we are
  below the enemy limit.
  """
  @callback spawn() :: Enemy.t()

  @spec update(module, Enemies.t()) :: Enemies.t()
  def update(impl, enemies) do
    last_spawned_at = Yarnballs.Utils.now_milliseconds()
    dt = last_spawned_at - enemies.last_spawned_at

    if length(enemies.entities) < impl.limit() && dt > impl.interval() do
      Logger.debug("spawning enemy")
      entities = [impl.spawn() | enemies.entities]

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

defmodule Yarnballs.Spawner.AFewBouncers do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 5

  @impl Spawner
  def interval(), do: 1000

  @impl Spawner
  def spawn() do
    Enemy.Bouncer.spawn()
  end
end

defmodule Yarnballs.Spawner.AFewRocks do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 5

  @impl Spawner
  def interval(), do: 1000

  @impl Spawner
  def spawn() do
    Enemy.Rock.spawn()
  end
end

defmodule Yarnballs.Spawner.AFewBouncersAndRocks do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 5

  @impl Spawner
  def interval(), do: 1000

  @impl Spawner
  def spawn() do
    [Enemy.Bouncer, Enemy.Rock]
    |> Enum.random()
    |> (fn x -> x.spawn() end).()
  end
end

defmodule Yarnballs.Spawner.Rocks do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 20

  @impl Spawner
  def interval(), do: 500

  @impl Spawner
  def spawn() do
    Enemy.Rock.spawn()
  end
end

defmodule Yarnballs.Spawner.BouncersAndRocks do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 20

  @impl Spawner
  def interval(), do: 500

  @impl Spawner
  def spawn() do
    [Enemy.Bouncer, Enemy.Rock]
    |> Enum.random()
    |> (fn x -> x.spawn() end).()
  end
end

defmodule Yarnballs.Spawner.BiggerRocks do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 15

  @impl Spawner
  def interval(), do: 500

  @impl Spawner
  def spawn() do
    Enemy.Rock.spawn(%{max_scale: 1.5})
  end
end

defmodule Yarnballs.Spawner.BouncersAndBiggerRocks do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 15

  @impl Spawner
  def interval(), do: 500

  @impl Spawner
  def spawn() do
    [Enemy.Bouncer, Enemy.Rock]
    |> Enum.random()
    |> (fn
          Enemy.Rock -> Enemy.Rock.spawn(%{max_scale: 1.5})
          x -> x.spawn()
        end).()
  end
end

defmodule Yarnballs.Spawner.FasterRocks do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 10

  @impl Spawner
  def interval(), do: 500

  @impl Spawner
  def spawn() do
    Enemy.Rock.spawn(%{min_vel: 150, max_vel: 200})
  end
end

defmodule Yarnballs.Spawner.FasterRocksAndBiggerRocks do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 20

  @impl Spawner
  def interval(), do: 500

  @impl Spawner
  def spawn() do
    [%{min_vel: 150, max_vel: 200}, %{max_scale: 1.5}]
    |> Enum.random()
    |> Enemy.Rock.spawn()
  end
end

defmodule Yarnballs.Spawner.BouncersAndFasterRocksAndBiggerRocks do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 25

  @impl Spawner
  def interval(), do: 500

  @impl Spawner
  def spawn() do
    [
      Enemy.Bouncer,
      {Enemy.Rock, %{min_vel: 150, max_vel: 200}},
      {Enemy.Rock, %{max_scale: 1.5}}
    ]
    |> Enum.random()
    |> (fn
          Enemy.Bouncer -> Enemy.Bouncer.spawn()
          {x, opts} -> x.spawn(opts)
        end).()
  end
end

defmodule Yarnballs.Spawner.Madness do
  @moduledoc false

  alias Yarnballs.Spawner
  alias Yarnballs.Enemy

  @behaviour Spawner

  @impl Spawner
  def limit(), do: 50

  @impl Spawner
  def interval(), do: 250

  @impl Spawner
  def spawn() do
    [
      {Enemy.Bouncer, %{min_vel: 100, max_vel: 150}},
      {Enemy.Rock, %{max_scale: 1.5, min_vel: 200, max_vel: 250}}
    ]
    |> Enum.random()
    |> (fn {x, opts} -> x.spawn(opts) end).()
  end
end
