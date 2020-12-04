defmodule GgyoWeb.UserView do
  use GgyoWeb, :view
  alias GgyoWeb.UserView

  def render("index.json", %{users: users}) do
    %{data: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    case user do
      nil ->
        %{
          id: nil,
          username: "anon",
          display_name: nil,
          is_active: false,
          is_anonymous: true
        }

      user ->
        %{
          id: user.id,
          username: user.username,
          display_name: user.display_name,
          is_active: user.is_active,
          is_anonymous: user.is_anonymous
        }
    end
  end

  def render("sign_in.json", %{user: user}) do
    %{
      data: %{
        user: %{
          id: user.id,
          username: user.username,
          display_name: user.display_name
        }
      }
    }
  end

  def render("user_with_tokens.json", %{user: user, refresh: refresh, access: access}) do
    %{
      data: %{
        user: %{
          id: user.id,
          username: user.username,
          display_name: user.display_name,
          is_anonymous: user.is_anonymous
        },
        refresh: refresh,
        access: access
      }
    }
  end
end
