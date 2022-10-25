defmodule Yarnballs.State do
  @moduledoc """
  Represents the Yarnballs game state.
  """
  alias Yarnballs.Native

  @enforce_keys [
    :missiles,
    :enemies,
    :ships
  ]
  defstruct @enforce_keys

  defimpl Jason.Encoder do
    alias Yarnballs.Native

    def encode(value, opts) do
      value
      |> Map.put(:level, Native.level(value))
      |> Map.put(:score, Native.total_score(value))
      |> Jason.Encode.map(opts)
    end
  end

  def init(), do: Native.init_state()

  def spawn_ship(state, id, name), do: Native.spawn_ship(state, id, name)

  def remove_ship(state, id), do: Native.remove_ship(state, id)

  def turn_ship(state, id, clockwise), do: Native.turn_ship(state, id, clockwise)

  def thrust_ship(state, id), do: Native.thrust_ship(state, id)

  def spawn_missile(state, shooter_id) do
    Native.fire_missile_or_respawn(state, shooter_id)
  end

  def update(state), do: Native.update_bodies(state)
end
