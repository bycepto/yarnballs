defmodule Ggyo.Fixtures do
  alias Ggyo.Account
  alias Ggyo.Cazadores

  def fixture(:user) do
    {:ok, user} =
      Account.create_user(%{
        username: "some username",
        is_active: true,
        password: "some password"
      })

    user
  end

  def fixture(:users) do
    ["anna", "vasyl", "igor", "grusha"]
    |> Enum.map(fn username ->
      Account.create_user(%{
        username: username,
        is_active: true,
        password: "password"
      })
    end)
    |> Enum.map(fn {:ok, user} -> user end)
  end

  def fixture(:anonymous) do
    {:ok, user} =
      Account.create_user(%{
        username: "user123456789",
        is_active: true,
        password: "some password",
        is_anonymous: true
      })

    user
  end

  def fixture(:room) do
    {:ok, room} = Cazadores.create_room()
    room
  end

  def fixture(:event, user_id: user_id, room_id: room_id) do
    {:ok, event} =
      Cazadores.create_event(%{
        user_id: user_id,
        room_id: room_id,
        type: "faked",
        payload: %{},
        state: nil
      })

    event
  end
end
