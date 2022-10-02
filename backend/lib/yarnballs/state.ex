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
  alias Yarnballs.Level0Spawner
  alias Yarnballs.Level1Spawner

  @type t :: %__MODULE__{
          collisions_updated_at: integer(),
          missiles: Missiles.t(),
          enemies: Enemies.t(),
          ships: PlayerShips.t(),
          score_by_ship: %{binary => non_neg_integer}
        }

  @enforce_keys [:collisions_updated_at, :missiles, :enemies, :ships, :score_by_ship]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{
      collisions_updated_at: 0,
      missiles: Missiles.init(),
      enemies: Enemies.init(),
      ships: PlayerShips.init(),
      score_by_ship: Map.new()
    }
  end

  def spawn_ship(state, id) do
    %{state | ships: PlayerShips.spawn(state.ships, id)}
  end

  def move_ship(state, id, x, y, angle, thrusting) do
    %{state | ships: PlayerShips.move(state.ships, id, x, y, angle, thrusting)}
  end

  def spawn_missile(state, shooter_id, x, y, vel_x, vel_y, dead) do
    case PlayerShips.fetch(state.ships, shooter_id) do
      {:ok, _} ->
        %{
          state
          | missiles: Missiles.spawn(state.missiles, shooter_id, x, y, vel_x, vel_y, dead)
        }

      :error ->
        state
    end
  end

  def spawn_enemies(state) do
    spawner =
      case total_score(state) do
        x when x < 25 -> Level0Spawner
        _ -> Level1Spawner
      end

    %{state | enemies: Spawner.spawn(spawner, state.enemies)}
  end

  defp total_score(state) do
    state.score_by_ship
    |> Map.values()
    |> Enum.sum()
  end

  def update(state) do
    state
    |> spawn_enemies()
    |> update_physics()
    |> update_collisions()
    |> update_scores()
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

      # update scores for each ship
      scores =
        Map.merge(
          Enum.frequencies_by(missiles, & &1.shooter_id),
          state.score_by_ship,
          fn _key, score1, score2 -> score1 + score2 end
        )

      %{
        state
        | collisions_updated_at: collisions_updated_at,
          enemies: Enemies.remove(state.enemies, enemy_ids),
          missiles: Missiles.remove(state.missiles, Enum.map(missiles, & &1.id)),
          ships: ships,
          score_by_ship: scores
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

  # TODO: rename this function
  defp update_physics(state) do
    %{
      state
      | missiles: Missiles.update(state.missiles),
        enemies: Enemies.update(state.enemies)
    }
  end

  defp update_scores(state) do
    ships = PlayerShips.update(state.ships)

    # subtract 50 points from each newly destroyed ship
    scores =
      MapSet.difference(PlayerShips.dead(ships), PlayerShips.dead(state.ships))
      |> Enum.map(fn id -> {id, -50} end)
      |> Enum.into(%{})
      |> Map.merge(
        state.score_by_ship,
        fn _key, score1, score2 -> max(0, score1 + score2) end
      )

    %{state | ships: ships, score_by_ship: scores}
  end
end
