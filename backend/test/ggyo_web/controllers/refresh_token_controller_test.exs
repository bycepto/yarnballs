defmodule GgyoWeb.RefreshTokenControllerTest do
  use GgyoWeb.ConnCase
  import Ggyo.Factory

  alias Ggyo.Account.User

  @password "some password"

  setup %{conn: conn} do
    user = build(:user) |> set_user_password(@password) |> insert
    anonymous = insert(:user, is_anonymous: true)

    {:ok,
     conn: put_req_header(conn, "accept", "application/json"), user: user, anonymous: anonymous}
  end

  describe "create refresh_token" do
    test "renders refresh_token when data is valid", %{
      conn: conn,
      user: %User{id: _user_id, username: username}
    } do
      create_attrs = %{username: username, password: "wrong password"}

      conn = post(conn, Routes.refresh_token_path(conn, :create, create_attrs))

      assert %{"errors" => %{"detail" => "Wrong username or password"}} = json_response(conn, 401)
    end

    test "renders errors when password is incorrect", %{
      conn: conn,
      anonymous: %User{username: username}
    } do
      # TODO: expose password from fixtures?
      create_attrs = %{username: username, password: "some password"}

      conn = post(conn, Routes.refresh_token_path(conn, :create, create_attrs))
      assert %{"errors" => %{"detail" => "Wrong username or password"}} = json_response(conn, 401)
    end

    test "renders refresh_token for anonymous user no data is provided", %{
      conn: conn
    } do
      display_name = "Bob"
      create_attrs = %{display_name: display_name}

      conn = post(conn, Routes.refresh_token_path(conn, :create, create_attrs))

      assert %{
               "user" => %{
                 "id" => _user_id,
                 "username" => _username,
                 "display_name" => _display_name,
                 "is_anonymous" => true
               },
               "refresh" => _refresh,
               "access" => _access
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when user is anonymous", %{
      conn: conn,
      anonymous: %User{username: username}
    } do
      # TODO: expose password from fixtures?
      create_attrs = %{username: username, password: "some password"}

      conn = post(conn, Routes.refresh_token_path(conn, :create, create_attrs))
      assert %{"errors" => %{"detail" => "Wrong username or password"}} = json_response(conn, 401)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      invalid_attrs = %{username: nil, password: nil}
      conn = post(conn, Routes.refresh_token_path(conn, :create, invalid_attrs))
      assert %{"errors" => %{"detail" => "Wrong username or password"}} = json_response(conn, 401)
    end
  end
end
