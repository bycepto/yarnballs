defmodule Yarnballs.State do
  @moduledoc """
  Represents the Yarnballs game state.
  """
  require Logger

  alias Yarnballs.Missiles
  alias Yarnballs.PlayerShips
  alias Yarnballs.PlayerShip
  alias Yarnballs.Enemies
  alias Yarnballs.Collider
  alias Yarnballs.Spawner

  @type t :: %__MODULE__{
          collisions_updated_at: integer(),
          missiles: Missiles.t(),
          enemies: Enemies.t(),
          ships: PlayerShips.t()
        }

  @enforce_keys [
    :collisions_updated_at,
    :missiles,
    :enemies,
    :ships
  ]
  defstruct @enforce_keys

  defimpl Jason.Encoder do
    def encode(state, opts) do
      state
      |> Map.take([
        :collisions_updated_at,
        :missiles,
        :enemies,
        :ships
      ])
      |> Map.put(:level, Yarnballs.State.level(state))
      |> Map.put(:score, Yarnballs.State.total_score(state))
      |> Jason.Encode.map(opts)
    end
  end

  def init() do
    %__MODULE__{
      collisions_updated_at: 0,
      missiles: Missiles.init(),
      enemies: Enemies.init(),
      ships: PlayerShips.init()
    }
  end

  def spawn_ship(state, id, name) do
    %{state | ships: PlayerShips.spawn(state.ships, id, name)}
  end

  def remove_ship(state, id) do
    %{state | ships: PlayerShips.remove(state.ships, id)}
  end

  def move_ship(state, id, x, y, angle, thrusting) do
    %{state | ships: PlayerShips.move(state.ships, id, x, y, angle, thrusting)}
  end

  def spawn_missile(state, shooter_id, x, y, vel_x, vel_y, dead) do
    case PlayerShips.fetch(state.ships, shooter_id) do
      # If player is alive, shoot missiles
      {:ok, %PlayerShip{destroyed_at: nil}} ->
        # TODO: remove `dead` if there is no respawn delay
        missiles = Missiles.spawn(state.missiles, shooter_id, x, y, vel_x, vel_y, dead)
        %{state | missiles: missiles}

      # If player is dead, try to respawn
      {:ok, _} ->
        ships = PlayerShips.respawn(state.ships, shooter_id)
        %{state | ships: ships}

      :error ->
        state
    end
  end

  def spawn_enemies(state) do
    {_, spawner} = level_with_spawner(state)

    %{state | enemies: Spawner.update(spawner, state.enemies)}
  end

  def level(state) do
    {lvl, _} = level_with_spawner(state)
    lvl
  end

  defp level_with_spawner(state) do
    case total_score(state) do
      x when x < 15 -> {0, Spawner.AFewBouncers}
      x when x < 30 -> {1, Spawner.AFewRocks}
      x when x < 60 -> {2, Spawner.AFewBouncersAndRocks}
      x when x < 90 -> {3, Spawner.Rocks}
      x when x < 120 -> {4, Spawner.BouncersAndRocks}
      x when x < 200 -> {5, Spawner.BiggerRocks}
      x when x < 280 -> {6, Spawner.BouncersAndBiggerRocks}
      x when x < 330 -> {7, Spawner.FasterRocks}
      x when x < 430 -> {8, Spawner.FasterRocksAndBiggerRocks}
      x when x < 1000 -> {9, Spawner.BouncersAndFasterRocksAndBiggerRocks}
      _ -> {10, Spawner.Madness}
    end
  end

  ## Leave for testing ^
  # x when x < 1 -> {0, Spawner.AFewBouncers}
  # x when x < 2 -> {1, Spawner.AFewRocks}
  # x when x < 3 -> {2, Spawner.AFewBouncersAndRocks}
  # x when x < 4 -> {3, Spawner.Rocks}
  # x when x < 5 -> {4, Spawner.BouncersAndRocks}
  # x when x < 6 -> {5, Spawner.BiggerRocks}
  # x when x < 7 -> {6, Spawner.BouncersAndBiggerRocks}
  # x when x < 8 -> {7, Spawner.FasterRocks}
  # x when x < 9 -> {8, Spawner.FasterRocksAndBiggerRocks}
  # x when x < 10 -> {9, Spawner.BouncersAndFasterRocksAndBiggerRocks}
  # _ -> {10, Spawner.Madness}

  def total_score(state) do
    PlayerShips.total_score(state.ships)
  end

  def update(state) do
    state
    |> spawn_enemies()
    |> update_entities()
    |> update_collisions()
  end

  @collision_update_interval 100

  defp update_collisions(state) do
    collisions_updated_at = Yarnballs.Utils.now_milliseconds()
    dt = collisions_updated_at - state.collisions_updated_at

    if dt > @collision_update_interval do
      {enemy_ids, missiles} =
        for e <- state.enemies.entities,
            missile <- state.missiles.entities,
            enemy_missile_collision?(e, missile),
            !missile.dead do
          {e.id, missile}
        end
        |> Enum.unzip()

      ships =
        for e <- state.enemies.entities,
            p <- PlayerShips.entities(state.ships),
            enemy_player_collision?(e, p),
            !PlayerShip.dead?(p) do
          {p, e}
        end
        |> Enum.reduce(
          state.ships,
          fn {p, e}, ships -> PlayerShips.collide_with(ships, p.id, e) end
        )

      scores = Enum.frequencies_by(missiles, & &1.shooter_id)

      %{
        state
        | collisions_updated_at: collisions_updated_at,
          enemies: Enemies.remove(state.enemies, enemy_ids),
          missiles: Missiles.remove(state.missiles, Enum.map(missiles, & &1.id)),
          ships: PlayerShips.increase_scores(ships, scores)
      }
    else
      state
    end
  end

  defp enemy_missile_collision?(enemy, missile) do
    Collider.collided?(enemy, missile)
  end

  defp enemy_player_collision?(enemy, ship) do
    Collider.collided?(enemy, ship)
  end

  defp update_entities(state) do
    %{
      state
      | missiles: Missiles.update(state.missiles),
        enemies: Enemies.update(state.enemies),
        ships: PlayerShips.update(state.ships)
    }
  end
end
