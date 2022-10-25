defmodule ShmupWeb.UserView do
  use ShmupWeb, :view
  alias ShmupWeb.UserView

  def render("index.json", %{users: users}) do
    %{data: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      display_name: user.display_name
    }
  end

  def render("sign_in.json", %{user: user}) do
    %{
      data: %{
        user: %{
          id: user.id,
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
          display_name: user.display_name
        },
        refresh: refresh,
        access: access
      }
    }
  end
end
