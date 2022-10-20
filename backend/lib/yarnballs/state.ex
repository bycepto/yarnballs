defmodule Yarnballs.State do
  @moduledoc """
  Represents the Yarnballs game state.
  """
  require Logger

  alias Yarnballs.Collider
  alias Yarnballs.CollisionSpace
  alias Yarnballs.Enemies
  alias Yarnballs.Missiles
  alias Yarnballs.PlayerShips
  alias Yarnballs.PlayerShip
  alias Yarnballs.Environment, as: Env
  alias Yarnballs.Spawner

  @type t :: %__MODULE__{
          missiles: Missiles.t(),
          enemies: Enemies.t(),
          ships: PlayerShips.t()
        }

  @enforce_keys [
    :missiles,
    :enemies,
    :ships
  ]
  defstruct @enforce_keys

  defimpl Jason.Encoder do
    def encode(state, opts) do
      state
      |> Map.take([
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

  def turn_ship(state, id, vel_angle) do
    %{state | ships: PlayerShips.turn(state.ships, id, vel_angle)}
  end

  def thrust_ship(state, id, vel_x, vel_y) do
    %{state | ships: PlayerShips.thrust(state.ships, id, vel_x, vel_y)}
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

  defp update_collisions(state) do
    spaces = collision_spaces(state)

    # TODO: come up with better names for entity x entity collision variables
    {emcs, escs} =
      for {_, space} <- spaces, map_size(space) > 1, reduce: {MapSet.new(), MapSet.new()} do
        {emcs_acc, escs_acc} ->
          {
            MapSet.union(emcs_acc, MapSet.new(CollisionSpace.emc(space))),
            MapSet.union(escs_acc, MapSet.new(CollisionSpace.esc(space)))
          }
      end

    {enemies, missiles} = Enum.unzip(emcs)

    ships =
      escs
      |> Enum.reduce(
        state.ships,
        fn {e, s}, ships -> PlayerShips.collide_with(ships, s.id, e) end
      )

    scores = Enum.frequencies_by(missiles, & &1.shooter_id)

    %{
      state
      | enemies: Enemies.remove(state.enemies, Enum.map(enemies, & &1.id)),
        missiles: Missiles.remove(state.missiles, Enum.map(missiles, & &1.id)),
        ships: PlayerShips.increase_scores(ships, scores)
    }
  end

  defp collision_spaces(state) do
    hash = spatial_hash()

    enemies = Collider.spatial_hash(state.enemies.entities, hash, :enemies)
    missiles = Collider.spatial_hash(state.missiles.entities, hash, :missiles)
    ships = Collider.spatial_hash(Map.values(state.ships.entities), hash, :ships)

    enemies
    |> Map.merge(missiles, fn _key, m1, m2 -> Map.merge(m1, m2) end)
    |> Map.merge(ships, fn _key, m1, m2 -> Map.merge(m1, m2) end)
  end

  defp spatial_hash do
    [{0, Env.width(), 50}, {0, Env.height(), 50}]
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
