defmodule Yarnballs.PlayerShips do
  @moduledoc """
  Represents an collection of ships operated by players.
  """

  @enforce_keys [:entities]
  @derive {Jason.Encoder, only: [:entities]}
  defstruct @enforce_keys
end

defmodule Yarnballs.PlayerShip do
  @moduledoc """
  Represent ships operated by players.
  """

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
end
