defmodule GgyoWeb.UserSocket do
  use Phoenix.Socket
  alias Phoenix.Token
  alias Ggyo.Account
  alias Ggyo.Account.User

  ## Channels
  channel("cazadores:*", GgyoWeb.CazadoresChannel)
  channel("hanabi:*", GgyoWeb.HanabiChannel)
  channel("durak:*", GgyoWeb.DurakChannel)
  channel("yarnballs:*", GgyoWeb.YarnballsChannel)

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    with {:ok, user_id} <- Token.verify(socket, "access", token, max_age: 86400),
         %User{} = user <- Account.get_user!(user_id),
         socket <- assign(socket, :user, user) do
      {:ok, socket}
    else
      _ -> :error
    end
  end

  @impl true
  def connect(_params, _socket, _connect_info), do: :error

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     GgyoWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil
end
