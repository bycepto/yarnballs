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

  def total_score(players) do
    players.entities
    |> Map.values()
    |> Enum.map(fn p -> p.score end)
    |> Enum.sum()
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

  def increase_scores(players, scores) do
    entities =
      Map.merge(
        players.entities,
        scores,
        fn _key, ship, score -> %{ship | score: ship.score + score} end
      )

    %{players | entities: entities}
  end

  def turn(players, id, vel_angle) do
    entities =
      map_update_existing(
        players.entities,
        id,
        fn ship -> PlayerShip.turn(ship, vel_angle) end
      )

    %{players | entities: entities}
  end

  def thrust(players, id, vel_x, vel_y) do
    entities =
      map_update_existing(
        players.entities,
        id,
        fn ship -> PlayerShip.thrust(ship, vel_x, vel_y) end
      )

    %{players | entities: entities}
  end

  def collide_with(players, id, thing) do
    entities =
      map_update_existing(
        players.entities,
        id,
        fn ship -> PlayerCollidable.collide_with(thing, ship) end
      )

    %{players | entities: entities}
  end

  def respawn(players, id) do
    entities = map_update_existing(players.entities, id, &PlayerShip.respawn/1)

    %{players | entities: entities}
  end

  def update(players) do
    entities =
      players.entities
      |> Enum.flat_map(&maybe_update/1)
      |> Enum.into(%{})

    %{players | entities: entities}
  end

  defp maybe_update({id, player}) do
    case PlayerShip.update(player) do
      :pop -> []
      _ -> [{id, PlayerShip.update(player)}]
    end
  end

  defp map_update_existing(map, key, func) do
    {_, result} =
      Map.get_and_update(map, key, fn
        nil -> :pop
        value -> {nil, func.(value)}
      end)

    result
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
          updated_at: float,
          x: float,
          y: float,
          vel_x: float,
          vel_y: float,
          angle: float,
          vel_angle: float,
          thrusted_at: float,
          thrusting: boolean,
          health: float,
          destroyed_at: float | nil
        }
  @enforce_keys [
    :id,
    :name,
    :updated_at,
    :x,
    :y,
    :vel_x,
    :vel_y,
    :angle,
    :vel_angle,
    :thrusted_at,
    :thrusting,
    :health,
    :score,
    :destroyed_at
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  def radius, do: 45.0

  defimpl Yarnballs.Collidable do
    def top_left(%{x: x, y: y}), do: {x, y}
    def radius(_), do: Yarnballs.PlayerShip.radius()
  end

  @max_health 100
  @thrust_duration 50

  def spawn(id, name) do
    %__MODULE__{
      id: id,
      name: name,
      updated_at: 0,
      x: 0,
      y: 0,
      vel_x: 0,
      vel_y: 0,
      angle: 0,
      vel_angle: 0,
      thrusted_at: -@thrust_duration,
      thrusting: false,
      health: @max_health,
      score: 0,
      destroyed_at: nil
    }
  end

  @health_recharge 0.005
  # 15 minute kick delay
  @kick_delay 1000 * 60 * 15

  def update(player) do
    player
    |> update_physics()
    |> update_health()
  end

  def thrust(ship, vel_x, vel_y) do
    thrusted_at = Yarnballs.Utils.now_milliseconds()
    %{ship | vel_x: ship.vel_x + vel_x, vel_y: ship.vel_y + vel_y, thrusted_at: thrusted_at}
  end

  def turn(ship, vel_angle) do
    %{ship | vel_angle: vel_angle}
  end

  @thrust_friction 0.05
  # TODO: pass in as config params
  @width 640
  @height 480

  defp update_physics(ship) do
    updated_at = Yarnballs.Utils.now_milliseconds()
    dt = updated_at - ship.updated_at
    x = ship.x + ship.vel_x * (dt / 1000)
    y = ship.y + ship.vel_y * (dt / 1000)
    angle = ship.angle + ship.vel_angle * (:math.pi() / 180) * (dt / 1000)

    %{
      ship
      | updated_at: updated_at,
        x: Yarnballs.Utils.wrap_dim(x, @width, radius()),
        y: Yarnballs.Utils.wrap_dim(y, @height, radius()),
        angle: angle,
        vel_x: ship.vel_x * (1 - @thrust_friction),
        vel_y: ship.vel_y * (1 - @thrust_friction),
        thrusting: updated_at - ship.thrusted_at < @thrust_duration
    }
  end

  defp update_health(player) do
    cond do
      dead?(player) ->
        dt = Yarnballs.Utils.now_milliseconds() - player.destroyed_at

        if dt > @kick_delay do
          :pop
        else
          player
        end

      player.health <= 0 ->
        # subtract 50 points each time a ship is destroyed.
        %{
          player
          | destroyed_at: Yarnballs.Utils.now_milliseconds(),
            score: max(0, player.score - 50)
        }

      true ->
        # TODO: increase health recharge when near other players?
        %{player | health: min(@max_health, player.health + @health_recharge)}
    end
  end

  def respawn(player) do
    if dead?(player) do
      %{player | destroyed_at: nil, health: @max_health}
    else
      player
    end
  end

  def dead?(player), do: player.destroyed_at != nil
end
