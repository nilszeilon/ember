defmodule Emberchat.Chat.Messages do
  @moduledoc """
  Message-related functions for the Chat context.
  """

  import Ecto.Query, warn: false
  alias Emberchat.Repo
  alias Emberchat.Chat.{Message, EmbeddingGenerator, Reactions}
  alias Emberchat.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any message changes.

  The broadcasted messages match the pattern:

    * {:created, %Message{}}
    * {:updated, %Message{}}
    * {:deleted, %Message{}}

  """
  def subscribe_messages(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Emberchat.PubSub, "user:#{key}:messages")
  end

  @doc """
  Subscribe to search-related events for a user scope.
  """
  def subscribe_search(%Scope{} = scope) do
    key = scope.user.id
    Phoenix.PubSub.subscribe(Emberchat.PubSub, "user:#{key}:search")
  end

  @doc """
  Broadcasts message-related events to subscribers.
  """
  def broadcast_message(%Scope{} = _scope, {_action, message} = msg) do
    # Broadcast to the room channel so all users in the room receive messages
    Phoenix.PubSub.broadcast(Emberchat.PubSub, "room:#{message.room_id}:messages", msg)
  end

  @doc """
  Returns the list of messages.

  ## Examples

      iex> list_messages(scope)
      [%Message{}, ...]

  """
  def list_messages(%Scope{} = scope) do
    Repo.all_by(Message, user_id: scope.user.id)
  end

  def list_room_messages(_scope, room_id, opts \\ []) do
    include_replies = Keyword.get(opts, :include_replies, false)

    # Base query for all messages in the room
    base_query =
      from(m in Message,
        where: m.room_id == ^room_id,
        preload: [:user, :reactions, :pinned_by, parent_message: :user],
        order_by: [asc: m.inserted_at]
      )

    query =
      if include_replies do
        base_query
      else
        from(m in base_query, where: is_nil(m.parent_message_id))
      end

    # Get all messages (including deleted ones) to check reply counts
    all_messages = Repo.all(query)
    
    # Filter out deleted messages that have no replies (reply_count = 0)
    messages = Enum.filter(all_messages, fn message ->
      case message.deleted_at do
        nil -> true  # Not deleted, always show
        _ -> message.reply_count > 0  # Deleted, only show if it has replies
      end
    end)

    # Add reaction summaries and thread messages to each message
    Enum.map(messages, fn message ->
      reactions = Reactions.get_message_reactions(message.id)
      
      # If this is a top-level message and has replies, fetch them
      thread_messages = if is_nil(message.parent_message_id) and message.reply_count > 0 do
        list_thread_messages(nil, message.id, include_deleted: true)
      else
        []
      end
      
      message
      |> Map.put(:reaction_summary, reactions)
      |> Map.put(:thread_messages, thread_messages)
    end)
  end

  def list_thread_messages(_scope, parent_message_id, opts \\ []) do
    include_deleted = Keyword.get(opts, :include_deleted, false)
    
    query =
      from(m in Message,
        where: m.parent_message_id == ^parent_message_id,
        preload: [:user, :reactions, :pinned_by, parent_message: :user],
        order_by: [asc: m.inserted_at]
      )

    query =
      if include_deleted do
        query
      else
        from(m in query, where: is_nil(m.deleted_at))
      end

    messages = Repo.all(query)

    # Add reaction summaries to each message
    Enum.map(messages, fn message ->
      reactions = Reactions.get_message_reactions(message.id)
      Map.put(message, :reaction_summary, reactions)
    end)
  end

  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the Message does not exist.

  ## Examples

      iex> get_message!(123)
      %Message{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(%Scope{} = scope, id) do
    Repo.get_by!(Message, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(%{field: value})
      {:ok, %Message{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(%Scope{} = scope, attrs) do
    Repo.transaction(fn ->
      with {:ok, message = %Message{}} <-
             %Message{}
             |> Message.changeset(attrs, scope)
             |> Repo.insert() do
        # Update parent message thread metadata if this is a reply
        if message.parent_message_id do
          update_thread_metadata(message.parent_message_id)
        end

        # Generate embedding asynchronously to avoid blocking message creation
        Task.start(fn -> EmbeddingGenerator.generate_embedding_for_message(message) end)

        message = Repo.preload(message, [:user, parent_message: :user])
        broadcast_message(scope, {:created, message})
        message
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates a message (internal use).

  ## Examples

      iex> update_message(message, %{field: new_value})
      {:ok, %Message{}}

      iex> update_message(message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_message(%Scope{} = scope, %Message{} = message, attrs) do
    true = message.user_id == scope.user.id

    with {:ok, updated_message = %Message{}} <-
           message
           |> Message.changeset(attrs, scope)
           |> Repo.update() do
      # Regenerate embedding if content changed
      if Map.has_key?(attrs, "content") or Map.has_key?(attrs, :content) do
        Task.start(fn -> EmbeddingGenerator.generate_embedding_for_message(updated_message) end)
      end

      broadcast_message(scope, {:updated, updated_message})
      {:ok, updated_message}
    end
  end

  @doc """
  Edits a message with edit tracking.

  ## Examples

      iex> edit_message(message, %{content: "new content"})
      {:ok, %Message{}}

      iex> edit_message(message, %{content: ""})
      {:error, %Ecto.Changeset{}}

  """
  def edit_message(%Scope{} = scope, %Message{} = message, attrs) do
    true = message.user_id == scope.user.id

    with {:ok, edited_message = %Message{}} <-
           message
           |> Message.edit_changeset(attrs, scope)
           |> Repo.update() do
      # Regenerate embedding if content changed
      Task.start(fn -> EmbeddingGenerator.generate_embedding_for_message(edited_message) end)

      broadcast_message(scope, {:updated, edited_message})
      {:ok, edited_message}
    end
  end

  @doc """
  Soft deletes a message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

      iex> delete_message(message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Scope{} = scope, %Message{} = message) do
    true = message.user_id == scope.user.id

    Repo.transaction(fn ->
      with {:ok, deleted_message = %Message{}} <- 
             message
             |> Message.soft_delete_changeset()
             |> Repo.update() do
        # Note: We don't decrement thread metadata for soft deletes
        # to maintain thread structure and show placeholder messages

        # Remove from vector table asynchronously
        Task.start(fn -> EmbeddingGenerator.remove_from_vector_table(deleted_message.id) end)

        broadcast_message(scope, {:deleted, deleted_message})
        deleted_message
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Scope{} = scope, %Message{} = message, attrs \\ %{}) do
    # Only check ownership for existing messages
    if message.id do
      true = message.user_id == scope.user.id
    end

    Message.changeset(message, attrs, scope)
  end

  defp update_thread_metadata(parent_message_id) do
    from(m in Message,
      where: m.id == ^parent_message_id,
      update: [
        inc: [reply_count: 1],
        set: [last_reply_at: ^DateTime.utc_now()]
      ]
    )
    |> Repo.update_all([])
  end

  defp decrement_thread_metadata(parent_message_id) do
    from(m in Message,
      where: m.id == ^parent_message_id,
      update: [inc: [reply_count: -1]]
    )
    |> Repo.update_all([])
  end

end