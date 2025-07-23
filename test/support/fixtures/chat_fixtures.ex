defmodule Emberchat.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Emberchat.Chat` context.
  """

  @doc """
  Generate a room.
  """
  def room_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        description: "some description",
        is_private: true,
        name: "some name"
      })

    {:ok, room} = Emberchat.Chat.create_room(scope, attrs)
    room
  end

  @doc """
  Generate a message.
  """
  def message_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        content: "some content"
      })

    {:ok, message} = Emberchat.Chat.create_message(scope, attrs)
    message
  end
end
