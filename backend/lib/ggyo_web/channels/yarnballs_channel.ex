defmodule GgyoWeb.YarnballsChannel do
  @moduledoc false

  use Phoenix.Channel
  require Logger

  @events ["requested_state"]

  @doc """
  Joining a Yarnballs channel also adds a player's ship to a game loop
  """
  def join("yarnballs:" <> _room_id, _message, socket) do
    Ggyo.Yarnballs.GameLoop.join(socket.assigns.user.id)
    {:ok, %{events: @events}, socket}
  end

  def handle_in(
        "moved_ship",
        %{"x" => x, "y" => y, "angle" => angle, "thrusting" => thrusting},
        socket
      ) do
    Ggyo.Yarnballs.GameLoop.moved_ship(socket.assigns.user.id, x, y, angle, thrusting)
    {:noreply, socket}
  end

  def handle_in(
        "fired_shot",
        %{"x" => x, "y" => y, "vel_x" => vel_x, "vel_y" => vel_y, "dead" => dead},
        socket
      ) do
    Ggyo.Yarnballs.GameLoop.fire_missile(socket.assigns.user.id, x, y, vel_x, vel_y, dead)
    {:noreply, socket}
  end
end
