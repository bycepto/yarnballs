defmodule Shmup.AuthTest do
  use ExUnit.Case

  alias Shmup.Auth

  describe "tokens" do
    alias Shmup.Auth.Token
    alias Shmup.Auth.User

    import Shmup.AuthFixtures

    test "create_token returns a token for a temporary user" do
      name = "alice"

      assert %Token{
               token: token,
               user: %User{id: id, name: ^name}
             } = Auth.create_token(name)
    end

    #     test "verify_token returns the associated temporary user for a valid token" do
    #       name = "alice"
    # 
    #       assert %Token{
    #                token: token,
    #                user: %User{id: id, name: ^name}
    #              } = token_fixture(name)
    #     end
    #     
    #     test "verify_token returns an error for an invalid token" do
    #       name = "alice"
    # 
    #       assert %Token{
    #                token: token,
    #                user: %User{id: id, name: ^name}
    #              } = token_fixture(name)
    #     end
  end
end
