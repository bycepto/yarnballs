defmodule ShmupWeb.TokenController do
  use ShmupWeb, :controller

  alias Shmup.Auth
  alias Shmup.Auth.Token

  action_fallback ShmupWeb.FallbackController

  def create(conn, %{"display_name" => display_name}) do
    with token <- Auth.create_token(display_name) do
      conn
      |> put_status(:created)
      |> render(:show, token: token)
    end
  end

  def show(conn, %{}) do
    token = %Token{token: conn.assigns.token, user: conn.assigns.current_user}
    render(conn, :show, token: token)
  end
end
