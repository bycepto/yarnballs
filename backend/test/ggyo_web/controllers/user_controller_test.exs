defmodule GgyoWeb.UserControllerTest do
  use GgyoWeb.ConnCase

  alias Ggyo.Account
  alias Ggyo.Account.User
  alias Ggyo.Fixtures

  @create_attrs %{
    username: "some username",
    is_active: true,
    password: "some password"
  }
  @update_attrs %{
    username: "some updated username",
    is_active: false,
    password: "some updated password"
  }
  @invalid_attrs %{username: nil, is_active: nil, password: nil}
  @current_user_attrs %{
    username: "some current user username",
    is_active: true,
    password: "some current user password"
  }

  def fixture(:current_user) do
    {:ok, current_user} = Account.create_user(@current_user_attrs)
    current_user
  end

  setup %{conn: conn} do
    {:ok, conn: conn, current_user: current_user} = setup_current_user(conn)
    {:ok, conn: put_req_header(conn, "accept", "application/json"), current_user: current_user}
  end

  describe "index" do
    test "lists all users", %{conn: conn, current_user: current_user} do
      conn = get(conn, Routes.user_path(conn, :index))

      assert json_response(conn, 200)["data"] == [
               %{
                 "id" => current_user.id,
                 "username" => current_user.username,
                 "display_name" => nil,
                 "is_active" => current_user.is_active,
                 "is_anonymous" => false
               }
             ]
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "username" => "some username",
               "display_name" => nil,
               "is_active" => true,
               "is_anonymous" => false
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update user" do
    setup [:create_user]

    test "renders user when data is valid", %{conn: conn, user: %User{id: id} = user} do
      conn = put(conn, Routes.user_path(conn, :update, user), user: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "username" => "some updated username",
               "is_active" => false
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, Routes.user_path(conn, :update, user), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete user" do
    setup [:create_user]

    test "deletes chosen user", %{conn: conn, user: user} do
      conn = delete(conn, Routes.user_path(conn, :delete, user))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.user_path(conn, :show, user))
      end)
    end
  end

  defp create_user(_) do
    user = Fixtures.fixture(:user)
    %{user: user}
  end

  defp setup_current_user(conn) do
    current_user = fixture(:current_user)
    access = Phoenix.Token.sign(GgyoWeb.Endpoint, "access", current_user.id)

    {
      :ok,
      conn: put_req_header(conn, "authorization", "Bearer #{access}"), current_user: current_user
    }
  end
end
