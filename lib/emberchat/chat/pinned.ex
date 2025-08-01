defmodule Emberchat.Chat.Pinned do
  import Ecto.Query, warn: false
  alias Emberchat.Repo
  alias Emberchat.Chat.Message
  alias Emberchat.Accounts.Scope

  @doc """
  Pins or unpins a message.
  """
  def toggle_pin_message(%Scope{} = scope, %Message{} = message, pin_slug \\ nil) do
    attrs = if message.is_pinned do
      %{is_pinned: false}
    else
      %{is_pinned: true, pin_slug: pin_slug}
    end

    changeset = Message.pin_changeset(message, attrs, scope)

    case Repo.update(changeset) do
      {:ok, updated_message} ->
        updated_message = Repo.preload(updated_message, [:user, :pinned_by])
        Emberchat.Chat.broadcast_message(scope, {:updated, updated_message})
        {:ok, updated_message}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists all pinned messages in a room.
  """
  def list_pinned_messages(_scope, room_id) do
    from(m in Message,
      where: m.room_id == ^room_id and m.is_pinned == true,
      order_by: [asc: m.pinned_at],
      preload: [:user, :pinned_by]
    )
    |> Repo.all()
  end

  @doc """
  Gets a pinned message by its slug in a room.
  """
  def get_pinned_message_by_slug(_scope, room_id, slug) do
    from(m in Message,
      where: m.room_id == ^room_id and m.pin_slug == ^slug and m.is_pinned == true,
      preload: [:user, :pinned_by]
    )
    |> Repo.one()
  end
end
