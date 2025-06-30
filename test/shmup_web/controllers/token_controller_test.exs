defmodule ShmupWeb.TokenControllerTest do
  use ShmupWeb.ConnCase

  alias Shmup.Auth.Token

  @create_attrs %{
    display_name: "alice"
  }
  @invalid_attrs %{
    foo: "bar"
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create token" do
    test "renders token when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/tokens", token: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/tokens/#{id}")

      assert %{
               "id" => ^id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/tokens", token: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
