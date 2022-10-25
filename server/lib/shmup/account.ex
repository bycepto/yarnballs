defmodule Shmup.Account do
  @moduledoc """
  The Account context.
  """

  import Ecto.Query, warn: false
  alias Shmup.Repo
  alias Shmup.Account.User

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @cleanup_threshold 200
  @cleanup_amount 100

  @doc """
  Deletes 100 anonymous users when there are more than 200.
  """
  # HACK
  # TODO check if there are any active games
  # TODO only delete if no updates in a few days
  def cleanup_anonymous do
    stale_users =
      User
      |> order_by(:updated_at)
      |> limit(@cleanup_threshold)
      |> Repo.all()

    if Enum.count(stale_users) >= @cleanup_threshold do
      ids_to_delete =
        stale_users
        |> Enum.take(@cleanup_amount)
        |> Enum.map(fn x -> x.id end)

      from(u in User, where: u.id in ^ids_to_delete) |> Repo.delete_all()
    end
  end
end
