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

  @limit 10
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
      |> Enum.filter(fn enemy -> keep?(enemies, enemy) end)
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

  def keep?(enemies, enemy) do
    !MapSet.member?(enemies.remove_ids, enemy.id) && !Enemy.out_of_bounds?(enemy)
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
  @padding 50

  @arc 50
  @min_vel 50
  @max_vel 100

  def spawn() do
    {spawn_x, spawn_y} =
      case Enum.random([:horizontal, :vertical]) do
        :horizontal ->
          {Enum.random([-@padding, @width + @padding]), Enum.random(0..@height)}

        :vertical ->
          {Enum.random(0..@width), Enum.random([-@padding, @height + @padding])}
      end

    center_x = @width / 2
    center_y = @height / 2
    angle_adjustment = :math.pi() * Enum.random(-@arc..@arc) / 180
    angle = :math.atan2(center_y - spawn_y, center_x - spawn_x) + angle_adjustment
    vel_x = Enum.random(@min_vel..@max_vel) * :math.cos(angle)
    vel_y = Enum.random(@min_vel..@max_vel) * :math.sin(angle)

    %__MODULE__{
      id: Ecto.UUID.generate(),
      updated_at: Yarnballs.Utils.now_milliseconds(),
      x: spawn_x,
      y: spawn_y,
      vel_x: vel_x,
      vel_y: vel_y
    }
  end

  def update(enemy) do
    updated_at = Yarnballs.Utils.now_milliseconds()
    dt = updated_at - enemy.updated_at
    x = enemy.x + enemy.vel_x * (dt / 1000)
    y = enemy.y + enemy.vel_y * (dt / 1000)

    %{enemy | updated_at: updated_at, x: x, y: y}
  end

  @out_of_bounds 100

  def out_of_bounds?(enemy) do
    enemy.x < -@out_of_bounds ||
      enemy.y < -@out_of_bounds ||
      enemy.x > @width + @out_of_bounds ||
      enemy.y > @height + @out_of_bounds
  end
end
