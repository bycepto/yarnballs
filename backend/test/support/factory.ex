defmodule Ggyo.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Ggyo.Repo

  def user_factory do
    %Ggyo.Account.User{
      username: sequence(:username, &"user-#{&1}")
    }
  end

  def set_user_password(user, password) do
    user
    |> Ggyo.Account.User.changeset(%{"password" => password})
    |> Ecto.Changeset.apply_changes()
  end

  # Cazadores

  def cazadores_room_factory do
    %Ggyo.Cazadores.Room{}
  end

  def cazadores_player_factory do
    %Ggyo.Cazadores.Player{
      user: build(:user),
      room: build(:cazadores_room)
    }
  end

  def cazadores_event_factory do
    %Ggyo.Cazadores.Event{
      room: build(:cazadores_room),
      user: build(:user)
    }
  end

  # Hanabi
  def hanabi_room_factory do
    %Ggyo.Hanabi.Room{}
  end
end
