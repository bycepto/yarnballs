defmodule Ggyo.Yarnballs.GameLoop do
  @moduledoc """
  Background process that updates the game loop for every active game.
  """
  use GenServer
  require Logger
  alias Yarnballs.State
  alias Ggyo.Yarnballs

  def start_link(state) do
    Logger.debug("starting link to game loop")

    GenServer.start_link(__MODULE__, state, name: :game_loop)
  end

  def join(id) do
    GenServer.cast(:game_loop, {:join, id})
  end

  def moved_ship(id, x, y, angle, thrusting) do
    GenServer.cast(:game_loop, {:move_ship, id, x, y, angle, thrusting})
  end

  def fire_missile(shooter_id, x, y, vel_x, vel_y, dead) do
    GenServer.cast(:game_loop, {:fire_missile, shooter_id, x, y, vel_x, vel_y, dead})
  end

  @impl true
  @spec init(State.t()) :: {:ok, State.t()}
  def init(state) do
    Logger.debug("initializing game loop")

    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_cast({:join, id}, state) do
    {:noreply, State.spawn_ship(state, id)}
  end

  @impl true
  def handle_cast({:move_ship, id, x, y, angle, thrusting}, state) do
    {:noreply, State.move_ship(state, id, x, y, angle, thrusting)}
  end

  @impl true
  def handle_cast({:fire_missile, shooter_id, x, y, vel_x, vel_y, dead}, state) do
    {:noreply, State.spawn_missile(state, shooter_id, x, y, vel_x, vel_y, dead)}
  end

  @impl true
  def handle_info(:tick, state) do
    new_state = State.update(state)

    broadcast!(new_state)
    schedule_tick()

    {:noreply, new_state}
  end

  @impl true
  def code_change(_old_vsn, _state, _extra) do
    Logger.debug("reseting game state")

    # TODO: use presence to determine which ships to keep?

    {:ok, State.init()}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 16)
  end

  defp broadcast!(state) do
    msg = %{room_id: Yarnballs.room_id(), state: state}
    topic = "yarnballs:#{Yarnballs.room_id()}"
    GgyoWeb.Endpoint.broadcast!(topic, "requested_state", msg)
  end
end
