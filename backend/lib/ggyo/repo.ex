defmodule Ggyo.Repo do
  use Ecto.Repo,
    otp_app: :ggyo,
    adapter: Ecto.Adapters.Postgres
end
