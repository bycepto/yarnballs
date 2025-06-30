defmodule Yarnballs.GameLoop do
  @moduledoc """
  Background process that updates the game loop.
  """

  defmacro __using__(_opts) do
    quote do
      use GenServer
      require Logger
      alias Yarnballs.State

      # CLIENT

      def start_link(state) do
        GenServer.start_link(__MODULE__, state, name: :game_loop)
      end

      def join(id, name) do
        GenServer.cast(:game_loop, {:join, id, name})
      end

      def leave(id) do
        GenServer.cast(:game_loop, {:leave, id})
      end

      def turned_ship(id, clockwise) do
        GenServer.cast(:game_loop, {:turn_ship, id, clockwise})
      end

      def thrusted_ship(id) do
        GenServer.cast(:game_loop, {:thrust_ship, id})
      end

      def fire_missile(shooter_id) do
        GenServer.cast(:game_loop, {:fire_missile, shooter_id})
      end

      # SERVER

      @impl true
      @spec init(State.t()) :: {:ok, State.t()}
      def init(state) do
        schedule_tick()
        {:ok, state}
      end

      @impl true
      def handle_cast({:join, id, name}, state) do
        {:noreply, State.spawn_ship(state, id, name)}
      end

      @impl true
      def handle_cast({:leave, id}, state) do
        Logger.info("player '#{id}' is leaving the game")
        {:noreply, State.remove_ship(state, id)}
      end

      @impl true
      def handle_cast({:turn_ship, id, clockwise}, state) do
        {:noreply, State.turn_ship(state, id, clockwise)}
      end

      @impl true
      def handle_cast({:thrust_ship, id}, state) do
        {:noreply, State.thrust_ship(state, id)}
      end

      @impl true
      def handle_cast({:fire_missile, shooter_id}, state) do
        {:noreply, State.spawn_missile(state, shooter_id)}
      end

      @impl true
      def handle_info(:tick, state) do
        new_state = State.update(state)

        handle_new_state(new_state)
        schedule_tick()

        {:noreply, new_state}
      end

      def handle_new_state(_state), do: nil

      @impl true
      def code_change(_old_vsn, _state, _extra) do
        Logger.debug("reseting game state")

        {:ok, State.init()}
      end

      defp schedule_tick do
        Process.send_after(self(), :tick, 16)
      end

      defoverridable(handle_new_state: 1)
    end
  end
end
