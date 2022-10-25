defmodule ShmupWeb.RefreshTokenControllerTest do
  use ShmupWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create refresh_token" do
    test "renders refresh_token when data is valid", %{conn: conn} do
      display_name = "Bob"
      create_attrs = %{display_name: display_name}

      conn = post(conn, Routes.refresh_token_path(conn, :create, create_attrs))

      assert %{
               "user" => %{
                 "id" => _user_id,
                 "display_name" => ^display_name
               },
               "refresh" => _refresh,
               "access" => _access
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      invalid_attrs = %{display_name: nil}
      conn = post(conn, Routes.refresh_token_path(conn, :create, invalid_attrs))
      assert %{"errors" => %{"detail" => "Bad Request"}} = json_response(conn, 400)
    end
  end
end
