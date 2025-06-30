defmodule ShmupWeb.Router do
  use ShmupWeb, :router
  require Logger

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShmupWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug :ensure_authenticated
  end

  scope "/", ShmupWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api", ShmupWeb do
    pipe_through :api

    post "/tokens", TokenController, :create
  end

  scope "/api", ShmupWeb do
    pipe_through [:api, :auth]

    get "/tokens", TokenController, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:shmup, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShmupWeb.Telemetry
    end
  end

  # Plug function
  defp ensure_authenticated(conn, _opts) do
    Logger.info("ensuring auth...")

    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Shmup.Auth.verify_token(token) do
      conn
      |> assign(:token, token)
      |> assign(:current_user, user)
    else
      error ->
        IO.inspect(error)

        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.put_view(ShmupWeb.ErrorJSON)
        |> Phoenix.Controller.render(:"401")
        |> halt()
    end
  end
end
