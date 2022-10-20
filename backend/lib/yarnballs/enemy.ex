defprotocol Yarnballs.PlayerCollidable do
  alias Yarnballs.PlayerShip

  @spec collide_with(t, PlayerShip.t()) :: PlayerShip.t()
  def collide_with(thing, ship)
end

# TODO: break up this protocol by traits
defprotocol Yarnballs.Enemy do
  alias Yarnballs.Explosion

  @doc """
  Update an enemy.
  """
  @spec update(t) :: t
  def update(enemy)

  @doc """
  Is an enemy out of bounds?
  """
  @spec out_of_bounds?(t) :: boolean
  def out_of_bounds?(enemy)

  @spec explode(t) :: Explosion.t()
  def explode(enemy)
end

defimpl Yarnballs.Enemy, for: Any do
  alias Yarnballs.Collidable
  alias Yarnballs.Environment, as: Env
  alias Yarnballs.Explosion

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
      enemy.x > Env.width() + @out_of_bounds ||
      enemy.y > Env.height() + @out_of_bounds
  end

  def explode(enemy) do
    Explosion.spawn(enemy.x, enemy.y, Collidable.radius(enemy) * 2)
  end
end

defmodule Yarnballs.Enemy.Bouncer do
  @moduledoc """
  Represents an enemy.
  """

  alias Yarnballs.Environment, as: Env
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
  @derive [Yarnballs.Enemy]
  defstruct @enforce_keys

  defimpl Jason.Encoder do
    def encode(card, opts) do
      card
      |> Map.take([
        :id,
        :updated_at,
        :x,
        :y,
        :vel_x,
        :vel_y
      ])
      |> Map.put(:kind, "bouncer")
      |> Jason.Encode.map(opts)
    end
  end

  defimpl Yarnballs.Collidable do
    def top_left(%{x: x, y: y}), do: {x, y}
    def radius(_), do: 256 / 2 * 0.3
  end

  defimpl Yarnballs.PlayerCollidable do
    @repel_velocity 1000

    def collide_with(enemy, player) do
      new_angle = Yarnballs.Utils.repel_angle(enemy, player)
      vel_x = @repel_velocity * :math.cos(new_angle)
      vel_y = @repel_velocity * :math.sin(new_angle)
      %{player | vel_x: vel_x, vel_y: vel_y}
    end
  end

  @padding 50

  @arc 50
  @default_min_vel 50
  @default_max_vel 100

  def spawn(opts \\ %{}) do
    min_vel = Map.get(opts, :min_vel, @default_min_vel)
    max_vel = Map.get(opts, :max_vel, @default_max_vel)

    {spawn_x, spawn_y} =
      case Enum.random([:horizontal, :vertical]) do
        :horizontal ->
          {Enum.random([-@padding, Env.width() + @padding]), Enum.random(0..Env.height())}

        :vertical ->
          {Enum.random(0..Env.width()), Enum.random([-@padding, Env.height() + @padding])}
      end

    center_x = Env.width() / 2
    center_y = Env.height() / 2
    angle_adjustment = :math.pi() * Enum.random(-@arc..@arc) / 180
    angle = :math.atan2(center_y - spawn_y, center_x - spawn_x) + angle_adjustment
    vel_x = Enum.random(min_vel..max_vel) * :math.cos(angle)
    vel_y = Enum.random(min_vel..max_vel) * :math.sin(angle)

    %__MODULE__{
      id: Ecto.UUID.generate(),
      updated_at: Yarnballs.Utils.now_milliseconds(),
      x: spawn_x,
      y: spawn_y,
      vel_x: vel_x,
      vel_y: vel_y
    }
  end
end

defmodule Yarnballs.Enemy.Rock do
  @moduledoc """
  Represents an enemy.
  """

  alias Yarnballs.Environment, as: Env
  require Logger

  @type t :: %__MODULE__{
          id: binary,
          updated_at: integer,
          x: float,
          y: float,
          vel_x: float,
          vel_y: float,
          scale: float
        }

  @enforce_keys [
    :id,
    :updated_at,
    :x,
    :y,
    :vel_x,
    :vel_y,
    :scale
  ]
  @derive [Yarnballs.Enemy]
  defstruct @enforce_keys

  defimpl Jason.Encoder do
    def encode(rock, opts) do
      rock
      |> Map.take([
        :id,
        :x,
        :y,
        :vel_x,
        :vel_y,
        :scale
      ])
      |> Map.put(:kind, "rock")
      |> Jason.Encode.map(opts)
    end
  end

  defimpl Yarnballs.Collidable do
    def top_left(%{x: x, y: y}), do: {x, y}
    def radius(%{scale: scale}), do: 45.0 * scale
  end

  defimpl Yarnballs.PlayerCollidable do
    @repel_velocity 200
    @base_damage 5

    def collide_with(enemy, player) do
      new_angle = Yarnballs.Utils.repel_angle(enemy, player)
      vel_x = @repel_velocity * :math.cos(new_angle)
      vel_y = @repel_velocity * :math.sin(new_angle)
      %{player | health: player.health - rock_damage(enemy), vel_x: vel_x, vel_y: vel_y}
    end

    defp rock_damage(%{scale: scale}) do
      scale * @base_damage
    end
  end

  @padding 50

  @arc 50
  @default_min_vel 50
  @default_max_vel 100
  @default_scale 0.75

  def spawn(opts \\ %{}) do
    {spawn_x, spawn_y} =
      case Enum.random([:horizontal, :vertical]) do
        :horizontal ->
          {Enum.random([-@padding, Env.width() + @padding]), Enum.random(0..Env.height())}

        :vertical ->
          {Enum.random(0..Env.width()), Enum.random([-@padding, Env.height() + @padding])}
      end

    center_x = Env.width() / 2
    center_y = Env.height() / 2
    angle_adjustment = :math.pi() * Enum.random(-@arc..@arc) / 180
    angle = :math.atan2(center_y - spawn_y, center_x - spawn_x) + angle_adjustment

    spawn_at(spawn_x, spawn_y, angle, opts)
  end

  def split(%__MODULE__{x: x, y: y, scale: scale} = rock) do
    if scale <= @default_scale do
      []
    else
      angle = :math.pi() * Enum.random(1..360) / 180
      radius = Yarnballs.Collidable.radius(rock)

      [0, :math.pi() / 2, :math.pi(), 3 * :math.pi() / 2]
      |> Enum.map(fn theta ->
        opts = %{max_scale: scale / 2}
        spawn_at(x + radius, y + radius, angle + theta, opts)
      end)
    end
  end

  defp spawn_at(x, y, angle, opts) do
    max_scale = Map.get(opts, :max_scale, @default_scale)
    min_vel = Map.get(opts, :min_vel, @default_min_vel)
    max_vel = Map.get(opts, :max_vel, @default_max_vel)

    vel_x = Enum.random(min_vel..max_vel) * :math.cos(angle)
    vel_y = Enum.random(min_vel..max_vel) * :math.sin(angle)

    scale = Enum.random(30..round(max_scale * 100)) / 100

    %__MODULE__{
      id: Ecto.UUID.generate(),
      updated_at: Yarnballs.Utils.now_milliseconds(),
      x: x,
      y: y,
      vel_x: vel_x,
      vel_y: vel_y,
      scale: scale
    }
  end
end

defmodule Yarnballs.Enemies do
  @moduledoc """
  Represents an collection of enemies.
  """
  require Logger
  alias Yarnballs.Enemy
  alias Yarnballs.Enemy.Rock
  alias Yarnballs.Explosions

  @type t :: %__MODULE__{
          spawned_count: non_neg_integer,
          destroyed_count: non_neg_integer,
          entities: list(Enemy.t()),
          explosions: Explosions.t(),
          remove_ids: MapSet.t(binary),
          last_spawned_at: integer
        }

  @enforce_keys [
    :entities,
    :remove_ids,
    :explosions,
    :last_spawned_at,
    :spawned_count,
    :destroyed_count
  ]
  @derive {Jason.Encoder,
           only: [
             :entities,
             :explosions,
             :spawned_count,
             :destroyed_count
           ]}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{
      spawned_count: 0,
      destroyed_count: 0,
      entities: [],
      remove_ids: MapSet.new(),
      last_spawned_at: 0,
      explosions: Explosions.init()
    }
  end

  def remove(enemies, ids) do
    %{
      enemies
      | destroyed_count: enemies.destroyed_count + Enum.count(ids),
        remove_ids: MapSet.union(enemies.remove_ids, MapSet.new(ids))
    }
  end

  def update(enemies) do
    entities =
      enemies.entities
      |> Enum.filter(fn enemy -> keep?(enemies, enemy) end)
      |> Enum.map(&Enemy.update/1)

    {explosions, rock_splits} =
      enemies.entities
      |> Enum.filter(fn enemy -> MapSet.member?(enemies.remove_ids, enemy.id) end)
      |> Enum.reduce(
        {Explosions.update(enemies.explosions), []},
        fn enemy, {explosions, rock_splits} ->
          {Explosions.spawn(explosions, enemy),
           case enemy do
             %Rock{} -> [Rock.split(enemy) | rock_splits]
             _ -> rock_splits
           end}
        end
      )

    %{
      enemies
      | entities: Enum.concat([entities | rock_splits]),
        remove_ids: MapSet.new(),
        explosions: explosions
    }
  end

  def keep?(enemies, enemy) do
    !MapSet.member?(enemies.remove_ids, enemy.id) && !Enemy.out_of_bounds?(enemy)
  end
end
