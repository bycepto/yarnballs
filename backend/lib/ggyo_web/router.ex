defmodule GgyoWeb.Router do
  use GgyoWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
  end

  pipeline :api_auth do
    plug(:ensure_authenticated)
  end

  scope "/api", GgyoWeb do
    pipe_through(:api)

    # TODO: should one of these be authenticated?
    resources("/refresh-tokens", RefreshTokenController, only: [:create])
    resources("/access-tokens", AccessTokenController, only: [:create])
  end

  scope "/api", GgyoWeb do
    pipe_through([:api, :api_auth])

    resources("/users", UserController, except: [:new, :edit])
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through([:fetch_session, :protect_from_forgery])
      live_dashboard("/dashboard", metrics: GgyoWeb.Telemetry)
    end
  end

  # Plug function
  defp ensure_authenticated(conn, _opts) do
    with [auth_header] <- get_req_header(conn, "authorization"),
         token <- String.replace_prefix(auth_header, "Bearer ", ""),
         {:ok, user_id} <- Phoenix.Token.verify(conn, "access", token, max_age: 86400),
         conn <- assign(conn, :user, Ggyo.Account.get_user!(user_id)) do
      conn
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(GgyoWeb.ErrorView)
        |> render("401.json", message: "Unauthenticated user")
        |> halt()
    end
  end
end
