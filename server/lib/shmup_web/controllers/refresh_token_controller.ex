defmodule ShmupWeb.RefreshTokenController do
  use ShmupWeb, :controller

  action_fallback(ShmupWeb.FallbackController)

  def create(conn, %{"display_name" => display_name}) do
    Shmup.Account.cleanup_anonymous()

    case Shmup.Account.create_user(%{display_name: display_name}) do
      {:ok, user} ->
        refresh = Phoenix.Token.sign(conn, "refresh", user.id)
        access = Phoenix.Token.sign(conn, "access", user.id)

        conn
        |> put_status(:ok)
        |> put_view(ShmupWeb.UserView)
        |> render("user_with_tokens.json", user: user, access: access, refresh: refresh)

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> put_view(ShmupWeb.ErrorView)
        |> render("400.json", message: message)
    end
  end
end
