defmodule Ggyo.Account do
  @moduledoc """
  The Account context.
  """

  import Ecto.Query, warn: false
  alias Ggyo.Repo
  alias Ggyo.Account.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  # TODO: figure out a better way to do bots than just having dedicated users?
  def list_bot_users do
    User
    |> where([u], u.username in ["vasyl", "igor", "grusha"])
    |> Repo.all()
  end

  # TODO: figure out a better way to do bots than just having dedicated users?
  def is_bot?(user) do
    user.username in ["vasyl", "igor", "grusha"]
  end

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

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def authenticate_user(username, password) do
    query =
      from(
        u in User,
        where: u.username == ^username,
        where: not u.is_anonymous
      )

    query |> Repo.one() |> verify_password(password)
  end

  defp verify_password(nil, _) do
    # Perform a dummy check to make user enumeration more difficult
    Bcrypt.no_user_verify()
    {:error, "Wrong username or password"}
  end

  defp verify_password(user, password) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, "Wrong username or password"}
    end
  end

  @cleanup_threshold 200
  @cleanup_amount 100

  @doc """
  HACK

  Deletes 100 anonymous users when there are more than 200.

  TODO check if there are any active games
  TODO only delete if no updates in a few days
  """
  def cleanup_anonymous do
    stale_users =
      User
      |> where(is_anonymous: true)
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
