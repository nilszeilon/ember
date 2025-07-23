defmodule Emberchat.ChatTest do
  use Emberchat.DataCase

  alias Emberchat.Chat

  describe "rooms" do
    alias Emberchat.Chat.Room

    import Emberchat.AccountsFixtures, only: [user_scope_fixture: 0]
    import Emberchat.ChatFixtures

    @invalid_attrs %{name: nil, description: nil, is_private: nil}

    test "list_rooms/1 returns all scoped rooms" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room = room_fixture(scope)
      other_room = room_fixture(other_scope)
      assert Chat.list_rooms(scope) == [room]
      assert Chat.list_rooms(other_scope) == [other_room]
    end

    test "get_room!/2 returns the room with given id" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      other_scope = user_scope_fixture()
      assert Chat.get_room!(scope, room.id) == room
      assert_raise Ecto.NoResultsError, fn -> Chat.get_room!(other_scope, room.id) end
    end

    test "create_room/2 with valid data creates a room" do
      valid_attrs = %{name: "some name", description: "some description", is_private: true}
      scope = user_scope_fixture()

      assert {:ok, %Room{} = room} = Chat.create_room(scope, valid_attrs)
      assert room.name == "some name"
      assert room.description == "some description"
      assert room.is_private == true
      assert room.user_id == scope.user.id
    end

    test "create_room/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.create_room(scope, @invalid_attrs)
    end

    test "update_room/3 with valid data updates the room" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      update_attrs = %{name: "some updated name", description: "some updated description", is_private: false}

      assert {:ok, %Room{} = room} = Chat.update_room(scope, room, update_attrs)
      assert room.name == "some updated name"
      assert room.description == "some updated description"
      assert room.is_private == false
    end

    test "update_room/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room = room_fixture(scope)

      assert_raise MatchError, fn ->
        Chat.update_room(other_scope, room, %{})
      end
    end

    test "update_room/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Chat.update_room(scope, room, @invalid_attrs)
      assert room == Chat.get_room!(scope, room.id)
    end

    test "delete_room/2 deletes the room" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      assert {:ok, %Room{}} = Chat.delete_room(scope, room)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_room!(scope, room.id) end
    end

    test "delete_room/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room = room_fixture(scope)
      assert_raise MatchError, fn -> Chat.delete_room(other_scope, room) end
    end

    test "change_room/2 returns a room changeset" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      assert %Ecto.Changeset{} = Chat.change_room(scope, room)
    end
  end

  describe "messages" do
    alias Emberchat.Chat.Message

    import Emberchat.AccountsFixtures, only: [user_scope_fixture: 0]
    import Emberchat.ChatFixtures

    @invalid_attrs %{content: nil}

    test "list_messages/1 returns all scoped messages" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      message = message_fixture(scope)
      other_message = message_fixture(other_scope)
      assert Chat.list_messages(scope) == [message]
      assert Chat.list_messages(other_scope) == [other_message]
    end

    test "get_message!/2 returns the message with given id" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      other_scope = user_scope_fixture()
      assert Chat.get_message!(scope, message.id) == message
      assert_raise Ecto.NoResultsError, fn -> Chat.get_message!(other_scope, message.id) end
    end

    test "create_message/2 with valid data creates a message" do
      valid_attrs = %{content: "some content"}
      scope = user_scope_fixture()

      assert {:ok, %Message{} = message} = Chat.create_message(scope, valid_attrs)
      assert message.content == "some content"
      assert message.user_id == scope.user.id
    end

    test "create_message/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.create_message(scope, @invalid_attrs)
    end

    test "update_message/3 with valid data updates the message" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      update_attrs = %{content: "some updated content"}

      assert {:ok, %Message{} = message} = Chat.update_message(scope, message, update_attrs)
      assert message.content == "some updated content"
    end

    test "update_message/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      message = message_fixture(scope)

      assert_raise MatchError, fn ->
        Chat.update_message(other_scope, message, %{})
      end
    end

    test "update_message/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Chat.update_message(scope, message, @invalid_attrs)
      assert message == Chat.get_message!(scope, message.id)
    end

    test "delete_message/2 deletes the message" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      assert {:ok, %Message{}} = Chat.delete_message(scope, message)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_message!(scope, message.id) end
    end

    test "delete_message/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      message = message_fixture(scope)
      assert_raise MatchError, fn -> Chat.delete_message(other_scope, message) end
    end

    test "change_message/2 returns a message changeset" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      assert %Ecto.Changeset{} = Chat.change_message(scope, message)
    end
  end
end
