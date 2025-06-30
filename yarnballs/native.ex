defmodule Yarnballs.Native do
  @moduledoc """
  NIF bridge
  """
  use Rustler, otp_app: :shmup, crate: :yarnballs

  # state
  def init_state(), do: :erlang.nif_error(:nif_not_loaded)
  def spawn_ship(_s, _id, _n), do: :erlang.nif_error(:nif_not_loaded)
  def turn_ship(_s, _id, _b), do: :erlang.nif_error(:nif_not_loaded)
  def thrust_ship(_s, _id), do: :erlang.nif_error(:nif_not_loaded)
  def remove_ship(_s, _id), do: :erlang.nif_error(:nif_not_loaded)
  def fire_missile_or_respawn(_s, _id), do: :erlang.nif_error(:nif_not_loaded)
  def update_bodies(_s), do: :erlang.nif_error(:nif_not_loaded)
  def level(_s), do: :erlang.nif_error(:nif_not_loaded)
  def total_score(_s), do: :erlang.nif_error(:nif_not_loaded)
  def next_level_score(_s), do: :erlang.nif_error(:nif_not_loaded)
end
