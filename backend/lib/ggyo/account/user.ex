defmodule Ggyo.Account.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field(:username, :string)
    field(:display_name, :string)
    field(:password, :string, virtual: true)
    field(:password_hash, :string)
    field(:is_active, :boolean, default: false)
    field(:is_anonymous, :boolean, default: false)

    # Add support for microseconds at the app level
    # for this specific schema
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :display_name, :is_active, :password, :is_anonymous])
    |> validate_required([:username, :is_active, :password])
    |> unique_constraint(:username)
    |> put_password_hash()
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, Bcrypt.add_hash(password))
  end

  defp put_password_hash(changeset) do
    changeset
  end
end
