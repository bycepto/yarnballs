defmodule Yarnballs.Enemies do
  @moduledoc """
  Represents an collection of enemies.
  """
  require Logger
  alias Yarnballs.Enemy
  alias Yarnballs.Explosions

  @type t :: %__MODULE__{
          entities: list(Enemy.t()),
          explosions: Explosions.t(),
          remove_ids: MapSet.t(binary),
          last_spawned_at: integer
        }

  @enforce_keys [:entities, :remove_ids, :explosions, :last_spawned_at]
  @derive {Jason.Encoder, only: [:entities, :explosions]}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{
      entities: [],
      remove_ids: MapSet.new(),
      last_spawned_at: 0,
      explosions: Explosions.init()
    }
  end

  @limit 4
  @spawn_interval 1000

  def spawn(enemies) do
    last_spawned_at = Yarnballs.Utils.now_milliseconds()
    dt = last_spawned_at - enemies.last_spawned_at

    if length(enemies.entities) < @limit && dt > @spawn_interval do
      Logger.debug("spawning enemy")

      entities = [Enemy.spawn() | enemies.entities]
      %{enemies | entities: entities, last_spawned_at: last_spawned_at}
    else
      enemies
    end
  end

  def remove(enemies, ids) do
    %{enemies | remove_ids: MapSet.union(enemies.remove_ids, MapSet.new(ids))}
  end

  def update(enemies) do
    entities =
      enemies.entities
      |> Enum.filter(fn enemy -> !MapSet.member?(enemies.remove_ids, enemy.id) end)
      |> Enum.map(&Enemy.update/1)

    explosions =
      enemies.entities
      |> Enum.filter(fn enemy -> MapSet.member?(enemies.remove_ids, enemy.id) end)
      |> Enum.reduce(
        Explosions.update(enemies.explosions),
        fn enemy, explosions -> Explosions.spawn(explosions, enemy.x, enemy.y) end
      )

    %{enemies | entities: entities, remove_ids: MapSet.new(), explosions: explosions}
  end
end

defmodule Yarnballs.Enemy do
  @moduledoc """
  Represents an enemy.
  """

  require Logger

  @type t :: %__MODULE__{
          id: binary,
          updated_at: integer,
          x: float,
          y: float,
          vel_x: float,
          vel_y: float
        }

  @enforce_keys [
    :id,
    :updated_at,
    :x,
    :y,
    :vel_x,
    :vel_y
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  defimpl Yarnballs.Collidable do
    def top_left(%{x: x, y: y}), do: {x, y}
    def radius(_), do: 256 / 2 * 0.3
  end

  @width 640
  @height 480

  @min_vel 25
  @max_vel 75

  def spawn() do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      updated_at: Yarnballs.Utils.now_milliseconds(),
      x: Enum.random(1..@width),
      y: Enum.random(1..@height),
      vel_x: Enum.random(@min_vel..@max_vel) * Enum.random([-1, 1]),
      vel_y: Enum.random(@min_vel..@max_vel) * Enum.random([-1, 1])
    }
  end

  def update(enemy) do
    # update physics
    updated_at = Yarnballs.Utils.now_milliseconds()
    dt = updated_at - enemy.updated_at
    x = Integer.mod(round(enemy.x + enemy.vel_x * (dt / 1000)), @width)
    y = Integer.mod(round(enemy.y + enemy.vel_y * (dt / 1000)), @height)

    %{enemy | updated_at: updated_at, x: x, y: y}
  end
end
