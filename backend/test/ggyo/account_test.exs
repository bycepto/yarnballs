defmodule Ggyo.AccountTest do
  use Ggyo.DataCase

  alias Ggyo.Account

  describe "users" do
    alias Ggyo.Account.User

    @valid_attrs %{username: "some username", is_active: true, password: "some password"}
    @update_attrs %{
      username: "some updated username",
      is_active: false,
      password: "some updated password"
    }
    @invalid_attrs %{username: nil, is_active: nil, password: nil}

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Account.create_user()

      user
    end

    def user_without_password(attrs \\ %{}) do
      %{user_fixture(attrs) | password: nil}
    end

    test "list_users/0 returns all users" do
      user = user_without_password()
      assert Account.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_without_password()
      assert Account.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Account.create_user(@valid_attrs)
      assert user.username == "some username"
      assert user.is_active == true
      assert user.password == "some password"
      assert Bcrypt.verify_pass("some password", user.password_hash)
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Account.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, %User{} = user} = Account.update_user(user, @update_attrs)
      assert user.username == "some updated username"
      assert user.is_active == false
      assert user.password == "some updated password"
      assert Bcrypt.verify_pass("some updated password", user.password_hash)
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_without_password()
      assert {:error, %Ecto.Changeset{}} = Account.update_user(user, @invalid_attrs)
      assert user == Account.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Account.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Account.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Account.change_user(user)
    end

    test "authenticate_user/2 authenticates the user" do
      user = user_without_password()

      assert {:error, "Wrong username or password"} =
               Account.authenticate_user("wrong username", "")

      assert {:ok, authenticated_user} =
               Account.authenticate_user(user.username, @valid_attrs.password)

      assert user == authenticated_user
    end
  end
end
