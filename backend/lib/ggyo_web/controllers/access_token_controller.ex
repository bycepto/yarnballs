defmodule GgyoWeb.AccessTokenController do
  use GgyoWeb, :controller

  alias Ggyo.Account
  alias Ggyo.Account.User

  action_fallback(GgyoWeb.FallbackController)

  def create(conn, %{"refresh" => refresh}) do
    with {:ok, user_id} <- Phoenix.Token.verify(conn, "refresh", refresh, max_age: 86400),
         %User{} = user <- Account.get_user!(user_id),
         new_refresh <- Phoenix.Token.sign(conn, "refresh", user_id),
         access <- Phoenix.Token.sign(conn, "access", user_id) do
      conn
      |> put_status(:ok)
      |> put_view(GgyoWeb.UserView)
      |> render("user_with_tokens.json", user: user, access: access, refresh: new_refresh)
    else
      {:error, message} ->
        conn
        |> put_status(:unauthorized)
        |> put_view(GgyoWeb.ErrorView)
        |> render("401.json", message: message)
    end
  end
end
