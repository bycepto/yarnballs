defmodule Yarnballs.Utils do
  @moduledoc """
  Functions shared across multiple Yarnballs modules.
  """

  def now_milliseconds do
    DateTime.to_unix(DateTime.utc_now(), :millisecond)
  end
end
