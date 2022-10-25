defmodule Yarnballs.Missiles do
  @moduledoc """
  Represents an collection of missiles fired by players.
  """
  @enforce_keys [:entities, :remove_ids]
  @derive {Jason.Encoder, only: [:entities]}
  defstruct @enforce_keys
end

defmodule Yarnballs.Missile do
  @moduledoc """
  Represent missiles fired by players
  """
  @enforce_keys [
    :id,
    :shooter_id,
    :updated_at,
    :x,
    :y,
    :vel_x,
    :vel_y,
    :lifespan
  ]
  @derive {Jason.Encoder, only: [:x, :y, :vel_x, :vel_y]}
  defstruct @enforce_keys
end
