defmodule Emberchat.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Emberchat.Repo
  require Logger

  alias Emberchat.Chat.Room
  alias Emberchat.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any room changes.

  The broadcasted messages match the pattern:

    * {:created, %Room{}}
    * {:updated, %Room{}}
    * {:deleted, %Room{}}

  """
  def subscribe_rooms(%Scope{} = scope) do
    key = scope.user.id

    # Subscribe to user's own room updates
    Phoenix.PubSub.subscribe(Emberchat.PubSub, "user:#{key}:rooms")

    # Subscribe to all public room updates
    Phoenix.PubSub.subscribe(Emberchat.PubSub, "public:rooms")
  end

  defp broadcast(%Scope{} = scope, {_action, room} = message) do
    # Always broadcast to the room owner
    Phoenix.PubSub.broadcast(Emberchat.PubSub, "user:#{scope.user.id}:rooms", message)

    # If it's a public room, broadcast to all users
    if room.is_private == false do
      Phoenix.PubSub.broadcast(Emberchat.PubSub, "public:rooms", message)
    end
  end

  defp broadcast_message(%Scope{} = _scope, {_action, message} = msg) do
    # Broadcast to the room channel so all users in the room receive messages
    Phoenix.PubSub.broadcast(Emberchat.PubSub, "room:#{message.room_id}:messages", msg)
  end

  @doc """
  Returns the list of rooms.

  ## Examples

      iex> list_rooms(scope)
      [%Room{}, ...]

  """
  def list_rooms(%Scope{} = scope) do
    from(r in Room,
      where: r.is_private == false or r.user_id == ^scope.user.id,
      order_by: [asc: r.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single room.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room!(123)
      %Room{}

      iex> get_room!(456)
      ** (Ecto.NoResultsError)

  """
  def get_room!(%Scope{} = scope, id) do
    room = Repo.get!(Room, id)

    # Allow access if room is public or owned by user
    if room.is_private == false or room.user_id == scope.user.id do
      room
    else
      raise Ecto.NoResultsError, queryable: Room
    end
  end

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(%{field: value})
      {:ok, %Room{}}

      iex> create_room(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(%Scope{} = scope, attrs) do
    with {:ok, room = %Room{}} <-
           %Room{}
           |> Room.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast(scope, {:created, room})
      {:ok, room}
    end
  end

  @doc """
  Updates a room.

  ## Examples

      iex> update_room(room, %{field: new_value})
      {:ok, %Room{}}

      iex> update_room(room, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Scope{} = scope, %Room{} = room, attrs) do
    if room.user_id == scope.user.id do
      with {:ok, room = %Room{}} <-
             room
             |> Room.changeset(attrs, scope)
             |> Repo.update() do
        broadcast(scope, {:updated, room})
        {:ok, room}
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(room)
      {:ok, %Room{}}

      iex> delete_room(room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Scope{} = scope, %Room{} = room) do
    true = room.user_id == scope.user.id

    with {:ok, room = %Room{}} <-
           Repo.delete(room) do
      broadcast(scope, {:deleted, room})
      {:ok, room}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Scope{} = scope, %Room{} = room, attrs \\ %{}) do
    true = room.user_id == scope.user.id

    Room.changeset(room, attrs, scope)
  end

  alias Emberchat.Chat.{Message, EmbeddingGenerator, SemanticSearch, Reaction}
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
    
    query = from(m in Message, 
      where: m.room_id == ^room_id,
      preload: [:user, :reactions, :pinned_by, parent_message: :user],
      order_by: [asc: m.inserted_at]
    )
    
    query = if include_replies do
      query
    else
      from(m in query, where: is_nil(m.parent_message_id))
    end
    
    messages = Repo.all(query)
    
    # Add reaction summaries to each message
    Enum.map(messages, fn message ->
      reactions = get_message_reactions(message.id)
      Map.put(message, :reaction_summary, reactions)
    end)
  end
  
  def list_thread_messages(_scope, parent_message_id) do
    messages = from(m in Message,
      where: m.parent_message_id == ^parent_message_id,
      preload: [:user, :reactions, :pinned_by, parent_message: :user],
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
    
    # Add reaction summaries to each message
    Enum.map(messages, fn message ->
      reactions = get_message_reactions(message.id)
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

  @doc """
  Updates a message.

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
  Deletes a message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

      iex> delete_message(message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Scope{} = scope, %Message{} = message) do
    true = message.user_id == scope.user.id

    Repo.transaction(fn ->
      with {:ok, deleted_message = %Message{}} <- Repo.delete(message) do
        # Update parent message thread metadata if this was a reply
        if deleted_message.parent_message_id do
          decrement_thread_metadata(deleted_message.parent_message_id)
        end
        
        # Remove from vector table asynchronously
        Task.start(fn -> EmbeddingGenerator.remove_from_vector_table(deleted_message.id) end)
        
        broadcast_message(scope, {:deleted, deleted_message})
        deleted_message
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end
  
  defp decrement_thread_metadata(parent_message_id) do
    from(m in Message,
      where: m.id == ^parent_message_id,
      update: [inc: [reply_count: -1]]
    )
    |> Repo.update_all([])
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

  # Semantic Search Functions

  @doc """
  Search messages using semantic similarity and recency scoring.
  
  ## Examples
  
      iex> search_messages("machine learning", scope)
      {:ok, [%Message{}, ...]}
      
      iex> search_messages("invalid query", scope, room_id: 123, limit: 10)
      {:error, reason}
  """
  def search_messages(query, %Scope{} = scope, opts \\ []) do
    SemanticSearch.search_messages(query, scope, opts)
  end

  @doc """
  Find messages similar to a given message.
  """
  def find_similar_messages(%Message{} = message, opts \\ []) do
    SemanticSearch.find_similar_messages(message, opts)
  end

  @doc """
  Get search suggestions based on partial query input.
  """
  def get_search_suggestions(partial_query, %Scope{} = scope, opts \\ []) do
    SemanticSearch.get_search_suggestions(partial_query, scope, opts)
  end

  @doc """
  Generate embeddings for messages that don't have them yet.
  Useful for backfilling embeddings after the feature is added.
  """
  def backfill_embeddings(batch_size \\ 50) do
    EmbeddingGenerator.backfill_missing_embeddings(batch_size)
  end

  @doc """
  Count how many messages don't have embeddings yet.
  """
  def count_messages_without_embeddings do
    EmbeddingGenerator.count_messages_without_embeddings()
  end

  @doc """
  Subscribe to search-related events for a user scope.
  """
  def subscribe_search(%Scope{} = scope) do
    key = scope.user.id
    Phoenix.PubSub.subscribe(Emberchat.PubSub, "user:#{key}:search")
  end

  # Reaction functions

  @doc """
  Adds a reaction to a message. If the user has already reacted with the same emoji,
  the reaction will be removed (toggle behavior).
  """
  def toggle_reaction(%Scope{} = scope, message_id, emoji) do
    user_id = scope.user.id
    
    # Check if reaction already exists
    existing_reaction = 
      Repo.get_by(Reaction, message_id: message_id, user_id: user_id, emoji: emoji)
    
    if existing_reaction do
      # Remove the reaction
      {:ok, _} = Repo.delete(existing_reaction)
      broadcast_reaction_removed(message_id, user_id, emoji)
      {:ok, :removed}
    else
      # Add the reaction
      %Reaction{}
      |> Reaction.changeset(%{
        message_id: message_id,
        user_id: user_id,
        emoji: emoji
      })
      |> Repo.insert()
      |> case do
        {:ok, reaction} ->
          broadcast_reaction_added(message_id, user_id, emoji)
          {:ok, reaction}
        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Gets all reactions for a message grouped by emoji with user info.
  """
  def get_message_reactions(message_id) do
    from(r in Reaction,
      where: r.message_id == ^message_id,
      join: u in assoc(r, :user),
      select: %{emoji: r.emoji, user: u, user_id: r.user_id}
    )
    |> Repo.all()
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, reactions} ->
      %{
        emoji: emoji,
        count: length(reactions),
        users: Enum.map(reactions, & &1.user),
        user_ids: Enum.map(reactions, & &1.user_id)
      }
    end)
  end

  defp broadcast_reaction_added(message_id, user_id, emoji) do
    Phoenix.PubSub.broadcast(
      Emberchat.PubSub,
      "reactions:#{message_id}",
      {:reaction_added, %{message_id: message_id, user_id: user_id, emoji: emoji}}
    )
  end

  defp broadcast_reaction_removed(message_id, user_id, emoji) do
    Phoenix.PubSub.broadcast(
      Emberchat.PubSub,
      "reactions:#{message_id}",
      {:reaction_removed, %{message_id: message_id, user_id: user_id, emoji: emoji}}
    )
  end

  @doc """
  Subscribe to reactions for a specific message.
  """
  def subscribe_reactions(message_id) do
    Phoenix.PubSub.subscribe(Emberchat.PubSub, "reactions:#{message_id}")
  end

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

    Logger.info("test")

    IO.puts("=== REACHED THIS POINT ===")
    IO.inspect(changeset)

    case Repo.update(changeset) do
      {:ok, updated_message} ->
        updated_message = Repo.preload(updated_message, [:user, :pinned_by])
        broadcast_message(scope, {:updated, updated_message})
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
