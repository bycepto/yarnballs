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

  def join(id, name) do
    GenServer.cast(:game_loop, {:join, id, name})
  end

  def leave(id) do
    GenServer.cast(:game_loop, {:leave, id})
  end

  def turned_ship(id, vel_angle) do
    GenServer.cast(:game_loop, {:turn_ship, id, vel_angle})
  end

  def thrusted_ship(id, vel_x, vel_y) do
    GenServer.cast(:game_loop, {:thrust_ship, id, vel_x, vel_y})
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
  def handle_cast({:join, id, name}, state) do
    {:noreply, State.spawn_ship(state, id, name)}
  end

  @impl true
  def handle_cast({:leave, id}, state) do
    {:noreply, State.remove_ship(state, id)}
  end

  @impl true
  def handle_cast({:turn_ship, id, vel_angle}, state) do
    {:noreply, State.turn_ship(state, id, vel_angle)}
  end

  @impl true
  def handle_cast({:thrust_ship, id, vel_x, vel_y}, state) do
    {:noreply, State.thrust_ship(state, id, vel_x, vel_y)}
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
