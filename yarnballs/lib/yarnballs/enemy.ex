defmodule Yarnballs.Enemy.Bouncer do
  @moduledoc """
  Represents an enemy.
  """
  @enforce_keys [
    :id,
    :updated_at,
    :x,
    :y,
    :vel_x,
    :vel_y
  ]
  defstruct @enforce_keys

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> Map.take([
        :x,
        :y,
        :vel_x,
        :vel_y
      ])
      |> Map.put(:kind, "bouncer")
      |> Jason.Encode.map(opts)
    end
  end
end

defmodule Yarnballs.Enemy.Rock do
  @moduledoc """
  Represents an enemy.
  """
  @enforce_keys [
    :id,
    :updated_at,
    :x,
    :y,
    :vel_x,
    :vel_y,
    :scale
  ]
  defstruct @enforce_keys

  defimpl Jason.Encoder do
    def encode(rock, opts) do
      rock
      |> Map.take([
        :x,
        :y,
        :vel_x,
        :vel_y,
        :scale
      ])
      |> Map.put(:kind, "rock")
      |> Jason.Encode.map(opts)
    end
  end
end

defmodule Yarnballs.Enemies do
  @moduledoc """
  Represents an collection of enemies.
  """

  @enforce_keys [
    :entities,
    :remove_ids,
    :explosions,
    :last_spawned_at,
    :spawned_count,
    :destroyed_count
  ]
  @derive {Jason.Encoder,
           only: [
             :entities,
             :explosions,
             :spawned_count,
             :destroyed_count
           ]}
  defstruct @enforce_keys

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> Map.take([
        :explosions,
        :spawned_count,
        :destroyed_count
      ])
      |> Map.put(:entities, Map.values(value.entities))
      |> Jason.Encode.map(opts)
    end
  end
end
