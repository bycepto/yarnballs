defmodule Yarnballs.PlayerShips do
  @moduledoc """
  Represents an collection of ships operated by players.
  """
  alias Yarnballs.PlayerShip

  @type t :: %__MODULE__{
          entities: %{binary => PlayerShip.t()}
        }

  @enforce_keys [:entities]
  @derive {Jason.Encoder, only: [:entities]}
  defstruct @enforce_keys

  def init() do
    %__MODULE__{entities: %{}}
  end

  def entities(players) do
    Map.values(players.entities)
  end

  def spawn(players, id) do
    player = PlayerShip.spawn(id)
    # TODO: should a player only be able to join once? what happens if they leave?
    entities = Map.put_new(players.entities, player.id, player)
    %{players | entities: entities}
  end

  def move(players, id, x, y, angle, thrusting) do
    entities =
      Map.update!(players.entities, id, fn ship ->
        %{ship | x: x, y: y, vel_x: 0, vel_y: 0, angle: angle, thrusting: thrusting}
      end)

    %{players | entities: entities}
  end

  def collide_with(players, id, thing) do
    entities =
      Map.update!(
        players.entities,
        id,
        fn ship -> PlayerShip.collide_with(ship, thing) end
      )

    %{players | entities: entities}
  end

  def update(players) do
    entities =
      players.entities
      |> Enum.map(fn {id, player} -> {id, PlayerShip.update(player)} end)
      |> Enum.into(%{})

    %{players | entities: entities}
  end
end

defmodule Yarnballs.PlayerShip do
  @moduledoc """
  Represent ships operated by players.
  """
  require Logger
  alias Yarnballs.Enemy
  alias Yarnballs.Enemy.Rock

  @type t :: %__MODULE__{
          id: binary,
          x: float,
          y: float,
          vel_x: float,
          vel_y: float,
          angle: float,
          thrusting: boolean,
          health: float,
          destroyed_at: float | nil
        }
  @enforce_keys [
    :id,
    :x,
    :y,
    :vel_x,
    :vel_y,
    :angle,
    :thrusting,
    :health,
    :destroyed_at
  ]
  @derive {Jason.Encoder, only: @enforce_keys}
  defstruct @enforce_keys

  defimpl Yarnballs.Collidable do
    def top_left(%{x: x, y: y}), do: {x, y}
    def radius(_), do: 45.0
  end

  @health 100

  def spawn(id) do
    %__MODULE__{
      id: id,
      x: 0,
      y: 0,
      vel_x: 0,
      vel_y: 0,
      angle: 0,
      thrusting: false,
      health: @health,
      destroyed_at: nil
    }
  end

  @bouncer_repel_velocity 10
  @rock_repel_velocity 2
  @rock_damage 5

  def collide_with(player, thing) do
    # TODO: check collision and guard?

    # TODO: consider making this a protocol
    case thing do
      %Enemy{} ->
        new_angle = repel_angle(player, thing)
        vel_x = @bouncer_repel_velocity * :math.cos(new_angle)
        vel_y = @bouncer_repel_velocity * :math.sin(new_angle)
        %{player | vel_x: vel_x, vel_y: vel_y}

      %Rock{} ->
        new_angle = repel_angle(player, thing)
        vel_x = @rock_repel_velocity * :math.cos(new_angle)
        vel_y = @rock_repel_velocity * :math.sin(new_angle)
        %{player | health: player.health - @rock_damage, vel_x: vel_x, vel_y: vel_y}

      _ ->
        raise "cannot collide with #{thing}"
    end
  end

  @respawn_delay 10_000

  def update(player) do
    cond do
      dead?(player) ->
        dt = Yarnballs.Utils.now_milliseconds() - player.destroyed_at

        if dt > @respawn_delay do
          # respawn
          %{player | destroyed_at: nil, health: @health}
        else
          player
        end

      player.health <= 0 ->
        %{player | destroyed_at: Yarnballs.Utils.now_milliseconds()}

      true ->
        player
    end
  end

  def dead?(player), do: player.destroyed_at != nil

  defp repel_angle(player, %{x: x, y: y}) do
    dy = y - player.y
    dx = x - player.x
    :math.atan2(dy, dx) + :math.pi()
  end
end
