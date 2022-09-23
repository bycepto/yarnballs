defmodule Yarnballs.State do
  @moduledoc """
  Represents the Yarnballs game state.
  """
  require Logger

  alias Yarnballs.Missiles
  alias Yarnballs.PlayerShips
  alias Yarnballs.Enemies
  alias Yarnballs.Collider

  @type t :: %__MODULE__{
          collisions_updated_at: integer(),
          missiles: Missiles.t(),
          enemies: Enemies.t(),
          ships: PlayerShips.t()
        }

  @enforce_keys [:collisions_updated_at, :missiles, :enemies, :ships]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{
      collisions_updated_at: 0,
      missiles: Missiles.init(),
      enemies: Enemies.init(),
      ships: PlayerShips.init()
    }
  end

  def spawn_ship(state, id) do
    %{state | ships: PlayerShips.spawn(state.ships, id)}
  end

  def move_ship(state, id, x, y, angle, thrusting) do
    %{state | ships: PlayerShips.move(state.ships, id, x, y, angle, thrusting)}
  end

  def spawn_missile(state, x, y, vel_x, vel_y) do
    %{state | missiles: Missiles.spawn(state.missiles, x, y, vel_x, vel_y)}
  end

  def spawn_enemies(state) do
    %{state | enemies: Enemies.spawn(state.enemies)}
  end

  def update(state) do
    state
    |> update_physics()
    |> update_collisions()
  end

  @collision_update_interval 100
  @bounce_velocity 10

  defp update_collisions(state) do
    collisions_updated_at = Yarnballs.Utils.now_milliseconds()
    dt = collisions_updated_at - state.collisions_updated_at

    if dt > @collision_update_interval do
      {enemy_ids, missile_ids} =
        for e <- state.enemies.entities,
            m <- state.missiles.entities,
            enemy_missile_collision?(e, m) do
          {e.id, m.id}
        end
        |> Enum.unzip()

      ships =
        for e <- state.enemies.entities,
            p <- PlayerShips.entities(state.ships),
            enemy_player_collision?(e, p) do
          dy = e.y - p.y
          dx = e.x - p.x
          new_angle = :math.atan2(dy, dx) + :math.pi()

          vel_x = @bounce_velocity * :math.cos(new_angle)
          vel_y = @bounce_velocity * :math.sin(new_angle)
          {p.id, vel_x, vel_y}
        end
        |> Enum.reduce(
          state.ships,
          fn {id, vel_x, vel_y}, ships ->
            PlayerShips.accelerate(ships, id, vel_x, vel_y)
          end
        )

      %{
        state
        | collisions_updated_at: collisions_updated_at,
          enemies: Enemies.remove(state.enemies, enemy_ids),
          missiles: Missiles.remove(state.missiles, missile_ids),
          ships: ships
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

  defp update_physics(state) do
    %{
      state
      | missiles: Missiles.update(state.missiles),
        enemies: Enemies.update(state.enemies)
    }
  end
end
