defmodule ShmupWeb.TokenJSON do
  alias Shmup.Auth.Token

  @doc """
  Renders a single token.
  """
  def show(%{token: token}) do
    %{data: data(token)}
  end

  defp data(%Token{user: user} = token) do
    %{
      token: token.token,
      user: %{id: user.id, name: user.name}
    }
  end
end
