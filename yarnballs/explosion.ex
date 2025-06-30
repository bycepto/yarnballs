defmodule Yarnballs.Explosions do
  @moduledoc """
  Represents a collection of explosions.
  """

  @enforce_keys [:entities]
  @derive {Jason.Encoder, only: [:entities]}
  defstruct @enforce_keys
end

defmodule Yarnballs.Explosion do
  @moduledoc """
  Represent an explosion.
  """

  @enforce_keys [
    :id,
    :updated_at,
    :x,
    :y,
    :size,
    :lifespan
  ]
  @derive {Jason.Encoder, only: [:id, :x, :y, :size]}
  defstruct @enforce_keys
end
