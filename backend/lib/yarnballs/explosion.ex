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

  def spawn(explosions, x, y) do
    %{explosions | entities: [Explosion.spawn(x, y) | explosions.entities]}
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

  @type t :: %__MODULE__{
          id: binary,
          updated_at: integer,
          x: float,
          y: float,
          lifespan: integer
        }

  @enforce_keys [
    :id,
    :updated_at,
    :x,
    :y,
    :lifespan
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  @lifespan 1000

  def spawn(x, y) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      updated_at: Yarnballs.Utils.now_milliseconds(),
      x: x,
      y: y,
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
