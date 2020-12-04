defmodule Yarnballs.Utils do
  @moduledoc false

  def now_milliseconds do
    DateTime.to_unix(DateTime.utc_now(), :millisecond)
  end
end

defmodule Yarnballs.State do
  @moduledoc """
  Represents the Yarnballs game state
  """
  require Logger
  alias Yarnballs.Missiles
  alias Yarnballs.Missile
  alias Yarnballs.PlayerShips
  alias Yarnballs.PlayerShip
  alias Yarnballs.Enemies
  alias Yarnballs.Enemy

  @type t :: %__MODULE__{
          collisions_updated_at: integer(),
          missiles: Missiles.t(),
          enemies: Enemies.t(),
          ships: PlayerShips.t()
        }

  @enforce_keys [:collisions_updated_at, :missiles, :enemies, :ships]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{
      collisions_updated_at: 0,
      missiles: Missiles.init(),
      enemies: Enemies.init(),
      ships: PlayerShips.init()
    }
  end

  def spawn_ship(state, id) do
    %{state | ships: PlayerShips.spawn(state.ships, id)}
  end

  def move_ship(state, id, x, y, angle, thrusting) do
    %{state | ships: PlayerShips.move(state.ships, id, x, y, angle, thrusting)}
  end

  def spawn_missile(state, x, y, vel_x, vel_y) do
    %{state | missiles: Missiles.spawn(state.missiles, x, y, vel_x, vel_y)}
  end

  def spawn_enemies(state) do
    %{state | enemies: Enemies.spawn(state.enemies)}
  end

  def update(state) do
    state
    |> update_physics()
    |> update_collisions()
  end

  @collision_update_interval 100

  defp update_collisions(state) do
    collisions_updated_at = Yarnballs.Utils.now_milliseconds()
    dt = collisions_updated_at - state.collisions_updated_at

    if dt > @collision_update_interval do
      {enemy_ids, missile_ids} =
        for e <- state.enemies.entities, m <- state.missiles.entities, collision?(e, m) do
          {e.id, m.id}
        end
        |> Enum.unzip()

      %{
        state
        | collisions_updated_at: collisions_updated_at,
          enemies: Enemies.remove(state.enemies, enemy_ids),
          missiles: Missiles.remove(state.missiles, missile_ids)
      }
    else
      state
    end
  end

  # TODO: add pattern matching properly? getting a compiler error when I try to
  defp collision?(enemy, missile) do
    {ex, ey, er} = Enemy.center_and_radius(enemy)
    {mx, my, mr} = Missile.center_and_radius(missile)

    distance(ex, ey, mx, my) <= er + mr
  end

  defp distance(x1, y1, x2, y2) do
    :math.sqrt(round(x2 - x1) ** 2 + round(y2 - y1) ** 2)
  end

  defp update_physics(state) do
    %{
      state
      | missiles: Missiles.update(state.missiles),
        enemies: Enemies.update(state.enemies)
    }
  end
end

defmodule Yarnballs.PlayerShips do
  @moduledoc """
  Represents an collection of players fired by players.
  """
  alias Yarnballs.PlayerShip

  @type t :: %__MODULE__{
          entities: %{binary => PlayerShip.t()},
          remove_ids: MapSet.t(binary)
        }

  @enforce_keys [:entities, :remove_ids]
  @derive {Jason.Encoder, only: [:entities]}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{entities: %{}, remove_ids: MapSet.new()}
  end

  def spawn(players, id) do
    player = PlayerShip.spawn(id)
    # TODO: should a player only be able to join once? what happens if they leave?
    entities = Map.put_new(players.entities, player.id, player)
    %{players | entities: entities}
  end

  def move(players, id, x, y, angle, thrusting) do
    entities =
      Map.update!(players.entities, id, fn ship ->
        %{ship | x: x, y: y, angle: angle, thrusting: thrusting}
      end)

    %{players | entities: entities}
  end

  def remove(players, ids) do
    %{players | remove_ids: MapSet.union(players.remove_ids, MapSet.new(ids))}
  end

  def update(players) do
    entities =
      players.entities
      |> Enum.filter(fn {k, p} -> {k, keep_player?(players, p)} end)
      |> Enum.into({})

    %{players | entities: entities, remove_ids: MapSet.new()}
  end

  defp keep_player?(players, player) do
    !MapSet.member?(players.remove_ids, player.id)
  end
end

defmodule Yarnballs.PlayerShip do
  @moduledoc """
  Represent players fired by players
  """
  require Logger

  @type t :: %__MODULE__{
          id: binary,
          x: float,
          y: float,
          angle: float,
          thrusting: boolean
        }
  @enforce_keys [
    :id,
    :x,
    :y,
    :angle,
    :thrusting
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  # radius?

  def spawn(id) do
    %__MODULE__{
      id: id,
      x: 0,
      y: 0,
      angle: 0,
      thrusting: false
    }
  end
end

defmodule Yarnballs.Missiles do
  @moduledoc """
  Represents an collection of missiles fired by players.
  """
  alias Yarnballs.Missile

  @type t :: %__MODULE__{
          entities: list(Missile.t()),
          remove_ids: MapSet.t(binary)
        }

  @enforce_keys [:entities, :remove_ids]
  @derive {Jason.Encoder, only: [:entities]}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{entities: [], remove_ids: MapSet.new()}
  end

  def spawn(missiles, x, y, vel_x, vel_y) do
    %{missiles | entities: [Missile.spawn(x, y, vel_x, vel_y) | missiles.entities]}
  end

  def remove(missiles, ids) do
    %{missiles | remove_ids: MapSet.union(missiles.remove_ids, MapSet.new(ids))}
  end

  def update(missiles) do
    entities =
      missiles.entities
      |> Enum.filter(fn m -> keep_missile?(missiles, m) end)
      |> Enum.map(&Missile.update/1)

    %{missiles | entities: entities, remove_ids: MapSet.new()}
  end

  defp keep_missile?(missiles, missile) do
    missile.lifespan > 0 && !MapSet.member?(missiles.remove_ids, missile.id)
  end
end

defmodule Yarnballs.Missile do
  @moduledoc """
  Represent missiles fired by players
  """
  require Logger

  @type t :: %__MODULE__{
          id: binary,
          updated_at: integer,
          x: float,
          y: float,
          vel_x: float,
          vel_y: float,
          lifespan: integer
        }
  @enforce_keys [
    :id,
    :updated_at,
    :x,
    :y,
    :vel_x,
    :vel_y,
    :lifespan
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  @lifespan 1000
  @radius 5

  def spawn(x, y, vel_x, vel_y) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      updated_at: Yarnballs.Utils.now_milliseconds(),
      x: x,
      y: y,
      vel_x: vel_x,
      vel_y: vel_y,
      lifespan: @lifespan
    }
  end

  def update(missile) do
    # update physics
    updated_at = Yarnballs.Utils.now_milliseconds()
    dt = updated_at - missile.updated_at
    x = round(missile.x + missile.vel_x * (dt / 1000))
    y = round(missile.y + missile.vel_y * (dt / 1000))
    lifespan = missile.lifespan - dt

    %{missile | updated_at: updated_at, x: x, y: y, lifespan: lifespan}
  end

  def center_and_radius(missile) do
    {missile.x + @radius, missile.y + @radius, @radius}
  end
end

defmodule Yarnballs.Enemies do
  @moduledoc """
  Represents an collection of enemies.
  """
  require Logger
  alias Yarnballs.Enemy

  @type t :: %__MODULE__{
          entities: list(Enemy.t()),
          remove_ids: MapSet.t(binary),
          last_spawned_at: integer
        }

  @enforce_keys [:entities, :remove_ids, :last_spawned_at]
  @derive {Jason.Encoder, only: [:entities]}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{entities: [], remove_ids: MapSet.new(), last_spawned_at: 0}
  end

  @limit 15
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

    %{enemies | entities: entities, remove_ids: MapSet.new()}
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

  @width 640
  @height 480

  @min_vel 25
  @max_vel 75

  @radius 256 / 2 * 0.3

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

  def center_and_radius(enemy) do
    {enemy.x + @radius, enemy.y + @radius, @radius}
  end
end

defmodule Ggyo.Yarnballs.GameLoop do
  @moduledoc """
  Background process that updates the game loop for every active game.
  """
  use GenServer
  require Logger
  alias Yarnballs.State
  alias Ggyo.Yarnballs

  def start_link(state) do
    Logger.debug("starting link to game loop")

    GenServer.start_link(__MODULE__, state, name: :game_loop)
  end

  def join(id) do
    GenServer.cast(:game_loop, {:join, id})
  end

  def moved_ship(id, x, y, angle, thrusting) do
    GenServer.cast(:game_loop, {:move_ship, id, x, y, angle, thrusting})
  end

  def fire_missile(x, y, vel_x, vel_y) do
    GenServer.cast(:game_loop, {:fire_missile, x, y, vel_x, vel_y})
  end

  @impl true
  @spec init(State.t()) :: {:ok, State.t()}
  def init(state) do
    Logger.debug("initializing game loop")

    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_cast({:join, id}, state) do
    {:noreply, State.spawn_ship(state, id)}
  end

  @impl true
  def handle_cast({:move_ship, id, x, y, angle, thrusting}, state) do
    {:noreply, State.move_ship(state, id, x, y, angle, thrusting)}
  end

  @impl true
  def handle_cast({:fire_missile, x, y, vel_x, vel_y}, state) do
    {:noreply, State.spawn_missile(state, x, y, vel_x, vel_y)}
  end

  @impl true
  def handle_info(:tick, state) do
    new_state =
      state
      |> State.spawn_enemies()
      |> State.update()

    broadcast!(new_state)
    schedule_tick()

    {:noreply, new_state}
  end

  # @impl true
  # @doc """
  # Remove all entities except for ships on code change.
  # """
  # def code_change(_old_vsn, state, _extra) do
  #   Logger.debug("changing game loop code")
  #
  #   # TODO: use presence to determine which ships to keep?
  #   new_state = %{State.init() | ships: state.ships}
  #   {:ok, new_state}
  # end

  defp schedule_tick do
    Process.send_after(self(), :tick, 16)
  end

  defp broadcast!(state) do
    msg = %{room_id: Yarnballs.room_id(), state: state}
    topic = "yarnballs:#{Yarnballs.room_id()}"
    GgyoWeb.Endpoint.broadcast!(topic, "requested_state", msg)
  end
end
