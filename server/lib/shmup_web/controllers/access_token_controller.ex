defmodule ShmupWeb.AccessTokenController do
  use ShmupWeb, :controller

  alias Shmup.Account
  alias Shmup.Account.User

  action_fallback(ShmupWeb.FallbackController)

  def create(conn, %{"refresh" => refresh}) do
    with {:ok, user_id} <- Phoenix.Token.verify(conn, "refresh", refresh, max_age: 86_400),
         %User{} = user <- Account.get_user!(user_id),
         new_refresh <- Phoenix.Token.sign(conn, "refresh", user_id),
         access <- Phoenix.Token.sign(conn, "access", user_id) do
      conn
      |> put_status(:ok)
      |> put_view(ShmupWeb.UserView)
      |> render("user_with_tokens.json", user: user, access: access, refresh: new_refresh)
    else
      {:error, message} ->
        conn
        |> put_status(:unauthorized)
        |> put_view(ShmupWeb.ErrorView)
        |> render("401.json", message: message)
    end
  end
end
