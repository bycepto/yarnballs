defmodule GgyoWeb.YarnballsChannel do
  @moduledoc false

  use Phoenix.Channel
  alias GgyoWeb.Presence
  require Logger

  @events ["requested_state"]

  def join("yarnballs:" <> _room_id, _message, socket) do
    send(self(), :after_join)
    {:ok, %{events: @events}, socket}
  end

  def handle_info(:after_join, socket) do
    user = socket.assigns.user

    Presence.track(socket, user.id, %{name: user.display_name})

    {:noreply, socket}
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

  intercept(["presence_diff"])

  def handle_out("presence_diff", %{joins: joins, leaves: leaves}, socket) do
    Enum.each(
      joins,
      fn {user_id, %{metas: metas}} ->
        Ggyo.Yarnballs.GameLoop.join(user_id, name_from_metas(metas))
      end
    )

    Enum.each(Map.keys(leaves), &Ggyo.Yarnballs.GameLoop.leave/1)

    {:noreply, socket}
  end

  defp name_from_metas(metas) do
    metas
    |> Enum.reduce(%{}, fn meta, merged -> Map.merge(meta, merged) end)
    |> Map.get(:name)
  end
end
