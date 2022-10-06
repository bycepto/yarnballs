defmodule Yarnballs.Utils do
  @moduledoc """
  Functions shared across multiple Yarnballs modules.
  """

  def now_milliseconds do
    DateTime.to_unix(DateTime.utc_now(), :millisecond)
  end

  def repel_angle(%{x: x, y: y}, %{x: other_x, y: other_y}) do
    dy = y - other_y
    dx = x - other_x
    :math.atan2(dy, dx) + :math.pi()
  end

  @doc """
  Wrap entity around if the reach a position less then `0` or more than `limit`.

  `offset` specifies at what point we should the entity wrap. If there is an
  entity that is `x` pixels wide and the `offset` is set to `x / 2` - this will
  make it so the entity will start wrapping when it is halfway across the
  wrapping limit.
  """
  @spec wrap_dim(float, integer, float) :: float
  def wrap_dim(value, limit, offset) do
    (Integer.mod(round(value + offset), limit) - round(offset)) / 1.0
  end
end
