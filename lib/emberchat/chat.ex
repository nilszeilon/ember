defmodule Emberchat.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Emberchat.Repo

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

  alias Emberchat.Chat.Message
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
      preload: [:user, parent_message: :user],
      order_by: [asc: m.inserted_at]
    )
    
    query = if include_replies do
      query
    else
      from(m in query, where: is_nil(m.parent_message_id))
    end
    
    Repo.all(query)
  end
  
  def list_thread_messages(_scope, parent_message_id) do
    from(m in Message,
      where: m.parent_message_id == ^parent_message_id,
      preload: [:user, parent_message: :user],
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
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

    with {:ok, message = %Message{}} <-
           message
           |> Message.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_message(scope, {:updated, message})
      {:ok, message}
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
      with {:ok, message = %Message{}} <- Repo.delete(message) do
        # Update parent message thread metadata if this was a reply
        if message.parent_message_id do
          decrement_thread_metadata(message.parent_message_id)
        end
        
        broadcast_message(scope, {:deleted, message})
        message
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
end
