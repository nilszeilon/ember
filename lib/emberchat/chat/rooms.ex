defmodule Emberchat.Chat.Rooms do
  @moduledoc """
  Room-related functions for the Chat context.
  """

  import Ecto.Query, warn: false
  alias Emberchat.Repo
  alias Emberchat.Chat
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

  @doc """
  Broadcasts room-related events to subscribers.
  """
  def broadcast(%Scope{} = scope, {_action, room} = message) do
    # Always broadcast to the room owner
    Phoenix.PubSub.broadcast(Emberchat.PubSub, "user:#{scope.user.id}:rooms", message)

    # If it's a public room, broadcast to all users
    if room.is_private == false do
      Phoenix.PubSub.broadcast(Emberchat.PubSub, "public:rooms", message)
    end
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
end