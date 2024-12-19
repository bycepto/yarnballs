defmodule ShmupWeb.GameLoop do
  @moduledoc false

  use Yarnballs.GameLoop

  def handle_new_state(state), do: broadcast!(state)

  defp broadcast!(state) do
    msg = %{state: state}
    ShmupWeb.Endpoint.broadcast!(topic(), "requested_state", msg)
  end

  defp topic, do: "yarnballs:x"
end
