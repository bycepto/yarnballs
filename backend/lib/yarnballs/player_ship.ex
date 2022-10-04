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

  def move(players, id, x, y, angle, thrusting) do
    {_, entities} =
      Map.get_and_update(
        players.entities,
        id,
        fn
          nil ->
            :pop

          ship ->
            {nil, %{ship | x: x, y: y, vel_x: 0, vel_y: 0, angle: angle, thrusting: thrusting}}
        end
      )

    %{players | entities: entities}
  end

  def collide_with(players, id, thing) do
    {_, entities} =
      Map.get_and_update(
        players.entities,
        id,
        fn
          nil -> :pop
          ship -> {nil, PlayerCollidable.collide_with(thing, ship)}
        end
      )

    %{players | entities: entities}
  end

  def respawn(players, id) do
    {_, entities} =
      Map.get_and_update(
        players.entities,
        id,
        fn
          nil -> :pop
          ship -> {nil, PlayerShip.respawn(ship)}
        end
      )

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
      :delete -> []
      _ -> [{id, PlayerShip.update(player)}]
    end
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
    :score,
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
      score: 0,
      destroyed_at: nil
    }
  end

  @health_recharge 0.005
  # five minutes to respawn
  @kick_delay 150_000

  def update(player) do
    cond do
      dead?(player) ->
        dt = Yarnballs.Utils.now_milliseconds() - player.destroyed_at

        if dt > @kick_delay do
          :delete
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
