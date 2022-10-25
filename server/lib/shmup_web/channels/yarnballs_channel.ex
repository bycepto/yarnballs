defmodule ShmupWeb.YarnballsChannel do
  @moduledoc false

  use Phoenix.Channel
  alias ShmupWeb.Presence

  @events ["requested_state"]

  def join("yarnballs:" <> room_id, _message, socket) do
    send(self(), :after_join)

    user_id = socket.assigns.user.id

    :ok =
      ShmupWeb.ChannelWatcher.monitor(
        :games,
        self(),
        {__MODULE__, :leave, [room_id, user_id]}
      )

    {:ok, %{events: @events}, socket}
  end

  def handle_info(:after_join, socket) do
    user = socket.assigns.user

    Presence.track(socket, user.id, %{name: user.display_name})

    {:noreply, socket}
  end

  def handle_in("turned_ship", %{"clockwise" => clockwise}, socket) do
    ShmupWeb.GameLoop.turned_ship(socket.assigns.user.id, clockwise)
    {:noreply, socket}
  end

  def handle_in("thrusted_ship", %{}, socket) do
    ShmupWeb.GameLoop.thrusted_ship(socket.assigns.user.id)
    {:noreply, socket}
  end

  def handle_in("fired_shot", %{}, socket) do
    ShmupWeb.GameLoop.fire_missile(socket.assigns.user.id)
    {:noreply, socket}
  end

  def leave(_room_id, user_id) do
    ShmupWeb.GameLoop.leave(user_id)
  end

  intercept(["presence_diff"])

  def handle_out("presence_diff", %{joins: joins, leaves: leaves}, socket) do
    Enum.each(
      joins,
      fn {user_id, %{metas: metas}} ->
        ShmupWeb.GameLoop.join(user_id, name_from_metas(metas))
      end
    )

    Enum.each(Map.keys(leaves), &ShmupWeb.GameLoop.leave/1)

    {:noreply, socket}
  end

  defp name_from_metas(metas) do
    metas
    |> Enum.reduce(%{}, fn meta, merged -> Map.merge(meta, merged) end)
    |> Map.get(:name)
  end
end
