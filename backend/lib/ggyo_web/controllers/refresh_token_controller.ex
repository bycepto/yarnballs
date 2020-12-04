defmodule GgyoWeb.RefreshTokenController do
  use GgyoWeb, :controller

  @random_number_limit 10_000_000
  @anonymous_password "pass"

  action_fallback(GgyoWeb.FallbackController)

  def create(conn, %{"username" => username, "password" => password}) do
    case Ggyo.Account.authenticate_user(username, password) do
      {:ok, user} ->
        refresh = Phoenix.Token.sign(conn, "refresh", user.id)
        access = Phoenix.Token.sign(conn, "access", user.id)

        conn
        |> put_status(:ok)
        |> put_view(GgyoWeb.UserView)
        |> render("user_with_tokens.json", user: user, access: access, refresh: refresh)

      {:error, message} ->
        conn
        |> put_status(:unauthorized)
        |> put_view(GgyoWeb.ErrorView)
        |> render("401.json", message: message)
    end
  end

  def create(conn, %{"display_name" => display_name}) do
    Ggyo.Account.cleanup_anonymous()

    username = "user#{:rand.uniform(@random_number_limit)}"

    case Ggyo.Account.create_user(%{
           username: username,
           display_name: display_name,
           password: @anonymous_password,
           is_anonymous: true
         }) do
      {:ok, user} ->
        refresh = Phoenix.Token.sign(conn, "refresh", user.id)
        access = Phoenix.Token.sign(conn, "access", user.id)

        conn
        |> put_status(:ok)
        |> put_view(GgyoWeb.UserView)
        |> render("user_with_tokens.json", user: user, access: access, refresh: refresh)

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> put_view(GgyoWeb.ErrorView)
        |> render("400.json", message: message)
    end
  end
end
