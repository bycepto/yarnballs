defmodule Shmup.Auth.User do
  @moduledoc """
  A temporary user.
  """

  @type t :: %__MODULE__{}

  @enforce_keys [:id, :name]
  defstruct @enforce_keys
end

defmodule Shmup.Auth.Token do
  @moduledoc """
  A token, temporary user pair.
  """

  @type t :: %__MODULE__{}

  @enforce_keys [:token, :user]
  defstruct @enforce_keys
end

defmodule Shmup.Auth do
  @moduledoc """
  The Auth context.
  """

  alias Shmup.Auth.User
  alias Shmup.Auth.Token

  @signing_salt "auth_api"
  @max_age 3600

  @doc """
  Create a signed token for a temporary user.
  """
  @spec create_token(String.t()) :: Token.t()
  def create_token(name) do
    # TODO limit the number of tokens one client can create?
    user_id = UUID.uuid4()
    user = %User{id: user_id, name: name}

    token = Phoenix.Token.sign(ShmupWeb.Endpoint, @signing_salt, user)

    %Token{token: token, user: user}
  end

  @doc """
  Verify token signature and expiration time.
  """
  @spec verify_token(String.t()) :: {:ok, User.t()} | {:error, :unauthenticated}
  def verify_token(token) do
    case Phoenix.Token.verify(ShmupWeb.Endpoint, @signing_salt, token, max_age: @max_age) do
      {:ok, user} -> {:ok, user}
      _error -> {:error, :unauthenticated}
    end
  end
end
