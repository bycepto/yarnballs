defmodule Yarnballs.PlayerShips do
  @moduledoc """
  Represents an collection of ships operated by players.
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

  def entities(players) do
    Map.values(players.entities)
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
        %{ship | x: x, y: y, vel_x: 0, vel_y: 0, angle: angle, thrusting: thrusting}
      end)

    %{players | entities: entities}
  end

  def remove(players, ids) do
    %{players | remove_ids: MapSet.union(players.remove_ids, MapSet.new(ids))}
  end

  def accelerate(players, id, vel_x, vel_y) do
    entities =
      Map.update!(players.entities, id, fn ship ->
        %{ship | vel_x: vel_x, vel_y: vel_y}
      end)

    %{players | entities: entities}
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
  Represent ships operated by players.
  """
  require Logger

  @type t :: %__MODULE__{
          id: binary,
          x: float,
          y: float,
          vel_x: float,
          vel_y: float,
          angle: float,
          thrusting: boolean
        }
  @enforce_keys [
    :id,
    :x,
    :y,
    :vel_x,
    :vel_y,
    :angle,
    :thrusting
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  defimpl Yarnballs.Collidable do
    def top_left(%{x: x, y: y}), do: {x, y}
    def radius(_), do: 45.0
  end

  def spawn(id) do
    %__MODULE__{
      id: id,
      x: 0,
      y: 0,
      vel_x: 0,
      vel_y: 0,
      angle: 0,
      thrusting: false
    }
  end
end
