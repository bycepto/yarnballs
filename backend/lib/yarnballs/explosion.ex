defmodule Yarnballs.Explosions do
  @moduledoc """
  Represents a collection of explosions.
  """
  alias Yarnballs.Explosion

  @type t :: %__MODULE__{
          entities: list(Explosion.t())
        }

  @enforce_keys [:entities]
  @derive {Jason.Encoder, only: [:entities]}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{entities: []}
  end

  def spawn(explosions, thing) do
    %{explosions | entities: [Explosion.spawn(thing) | explosions.entities]}
  end

  def update(explosions) do
    entities =
      explosions.entities
      |> Enum.filter(&keep?/1)
      |> Enum.map(&Explosion.update/1)

    %{explosions | entities: entities}
  end

  defp keep?(explosion) do
    explosion.lifespan > 0
  end
end

defmodule Yarnballs.Explosion do
  @moduledoc """
  Represent an explosion.
  """
  require Logger
  alias Yarnballs.Enemy
  alias Yarnballs.Enemy.Rock
  alias Yarnballs.Collidable

  @type t :: %__MODULE__{
          id: binary,
          updated_at: integer,
          x: float,
          y: float,
          size: float,
          lifespan: integer
        }

  @enforce_keys [
    :id,
    :updated_at,
    :x,
    :y,
    # the size of the thing that is exploding - used to determine scale.
    :size,
    :lifespan
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  @lifespan 1000

  # TODO: consider making this a protocol?
  def spawn(thing) do
    {x, y, size} =
      case thing do
        # TODO: don't rely on collidable protocol / radius for size since it's indirect
        %Enemy{} ->
          {thing.x, thing.y, Collidable.radius(thing) * 2}

        %Rock{} ->
          {thing.x, thing.y, Collidable.radius(thing) * 2}

        _ ->
          raise "cannot spawn explosion for #{thing}"
      end

    %__MODULE__{
      id: Ecto.UUID.generate(),
      updated_at: Yarnballs.Utils.now_milliseconds(),
      x: x,
      y: y,
      size: size,
      lifespan: @lifespan
    }
  end

  def update(explosion) do
    # update physics
    updated_at = Yarnballs.Utils.now_milliseconds()
    dt = updated_at - explosion.updated_at
    lifespan = explosion.lifespan - dt

    %{explosion | updated_at: updated_at, lifespan: lifespan}
  end
end
