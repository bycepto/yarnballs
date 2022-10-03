defmodule Yarnballs.PlayerShips do
  @moduledoc """
  Represents an collection of ships operated by players.
  """
  alias Yarnballs.PlayerShip
  alias Yarnballs.PlayerCollidable

  @type t :: %__MODULE__{
          entities: %{binary => PlayerShip.t()}
        }

  @enforce_keys [:entities]
  @derive {Jason.Encoder, only: [:entities]}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{entities: %{}}
  end

  @spec dead(t) :: MapSet.t(binary)
  def dead(ships) do
    ships.entities
    |> Map.filter(fn {_id, ship} -> PlayerShip.dead?(ship) end)
    |> Map.keys()
    |> MapSet.new()
  end

  def fetch(players, id) do
    Map.fetch(players.entities, id)
  end

  def entities(players) do
    Map.values(players.entities)
  end

  def spawn(players, id, name) do
    player = PlayerShip.spawn(id, name)
    entities = Map.put_new(players.entities, player.id, player)
    %{players | entities: entities}
  end

  def remove(players, id) do
    entities = Map.delete(players.entities, id)
    %{players | entities: entities}
  end

  def move(players, id, x, y, angle, thrusting) do
    entities =
      Map.update!(players.entities, id, fn ship ->
        %{ship | x: x, y: y, vel_x: 0, vel_y: 0, angle: angle, thrusting: thrusting}
      end)

    %{players | entities: entities}
  end

  def collide_with(players, id, thing) do
    entities =
      Map.update!(
        players.entities,
        id,
        fn ship -> PlayerCollidable.collide_with(thing, ship) end
      )

    %{players | entities: entities}
  end

  def update(players) do
    entities =
      players.entities
      |> Enum.map(fn {id, player} -> {id, PlayerShip.update(player)} end)
      |> Enum.into(%{})

    %{players | entities: entities}
  end
end

defmodule Yarnballs.PlayerShip do
  @moduledoc """
  Represent ships operated by players.
  """
  require Logger

  @type t :: %__MODULE__{
          id: binary,
          name: binary | nil,
          x: float,
          y: float,
          vel_x: float,
          vel_y: float,
          angle: float,
          thrusting: boolean,
          health: float,
          destroyed_at: float | nil
        }
  @enforce_keys [
    :id,
    :name,
    :x,
    :y,
    :vel_x,
    :vel_y,
    :angle,
    :thrusting,
    :health,
    :destroyed_at
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  defimpl Yarnballs.Collidable do
    def top_left(%{x: x, y: y}), do: {x, y}
    def radius(_), do: 45.0
  end

  @max_health 100

  def spawn(id, name) do
    %__MODULE__{
      id: id,
      name: name,
      x: 0,
      y: 0,
      vel_x: 0,
      vel_y: 0,
      angle: 0,
      thrusting: false,
      health: @max_health,
      destroyed_at: nil
    }
  end

  @respawn_delay 10_000
  @health_recharge 0.005

  def update(player) do
    cond do
      dead?(player) ->
        dt = Yarnballs.Utils.now_milliseconds() - player.destroyed_at

        if dt > @respawn_delay do
          # respawn
          %{player | destroyed_at: nil, health: @max_health}
        else
          player
        end

      player.health <= 0 ->
        %{player | destroyed_at: Yarnballs.Utils.now_milliseconds()}

      true ->
        # TODO: increase health recharge when near other players?
        %{player | health: min(@max_health, player.health + @health_recharge)}
    end
  end

  def dead?(player), do: player.destroyed_at != nil
end
