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

  def spawn(missiles, x, y, vel_x, vel_y, dead) do
    missile = Missile.spawn(x, y, vel_x, vel_y, dead)
    %{missiles | entities: [missile | missiles.entities]}
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
          lifespan: integer,
          dead: boolean
        }

  @enforce_keys [
    :id,
    :updated_at,
    :x,
    :y,
    :vel_x,
    :vel_y,
    :lifespan,
    :dead
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  defimpl Yarnballs.Collidable do
    def top_left(%{x: x, y: y}), do: {x, y}
    def radius(_), do: 5.0
  end

  @lifespan 1000

  def spawn(x, y, vel_x, vel_y, dead) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      updated_at: Yarnballs.Utils.now_milliseconds(),
      x: x,
      y: y,
      vel_x: vel_x,
      vel_y: vel_y,
      lifespan: @lifespan,
      dead: dead
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
end
