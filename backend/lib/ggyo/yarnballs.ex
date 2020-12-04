defmodule Ggyo.Yarnballs do
  @moduledoc """
  Yarnballs game context
  """
  alias Ggyo.Repo
  alias Ggyo.Yarnballs.Room

  def room_id do
    # "d8fa592d-488f-423b-94f2-7fd9dd014c90"
    "x"
  end

  def create_room do
    %Room{}
    |> Room.changeset(%{id: room_id()})
    |> Repo.insert()
  end
end
