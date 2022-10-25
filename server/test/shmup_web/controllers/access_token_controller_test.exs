defmodule ShmupWeb.AccessTokenControllerTest do
  use ShmupWeb.ConnCase

  alias Shmup.Account
  alias Shmup.Account.User

  def user_fixture() do
    {:ok, user} = Account.create_user(%{display_name: "some display name"})

    user
  end

  setup %{conn: conn} do
    user = user_fixture()
    refresh = Phoenix.Token.sign(ShmupWeb.Endpoint, "refresh", user.id)

    {:ok, conn: put_req_header(conn, "accept", "application/json"), user: user, refresh: refresh}
  end

  describe "create access_token" do
    test "renders access_token when data is valid", %{
      conn: conn,
      user: %User{id: user_id, display_name: display_name},
      refresh: refresh
    } do
      create_attrs = %{refresh: refresh}

      conn = post(conn, Routes.access_token_path(conn, :create, create_attrs))

      assert %{
               "user" => %{
                 "id" => ^user_id,
                 "display_name" => ^display_name
               },
               "refresh" => _refresh,
               "access" => _access
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      invalid_attrs = %{refresh: nil}
      conn = post(conn, Routes.access_token_path(conn, :create, invalid_attrs))
      assert %{"errors" => %{"detail" => "invalid"}} = json_response(conn, 401)
    end
  end
end
