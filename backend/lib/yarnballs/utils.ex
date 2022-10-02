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
end
