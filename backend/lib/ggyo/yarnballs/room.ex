defmodule Ggyo.Yarnballs.Room do
  @moduledoc """
  This represents a Yarnballs room.
  """

  use Ecto.Schema
  import Ecto.Changeset
  # alias Ggyo.Yarnballs.Event
  # alias Ggyo.Yarnballs.Player

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: binary | nil,
          stage: binary | nil,
          # players: [binary] | nil,
          # events: [Event.t()] | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "yarnballs_rooms" do
    field(:stage, :string, default: "waiting")

    # has_many(:players, Player)
    # has_many(:events, Event)

    timestamps()
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:stage])
  end
end
