defmodule Shmup.Repo do
  use Ecto.Repo,
    otp_app: :shmup,
    adapter: Ecto.Adapters.Postgres
end
