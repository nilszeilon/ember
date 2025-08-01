defmodule Emberchat.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias __MODULE__, as: Room
  alias Emberchat.Repo
  alias Emberchat.Chat
  alias Emberchat.Accounts.Scope

  schema "rooms" do
    field :name, :string
    field :description, :string
    field :is_private, :boolean, default: false
    field :emoji, :string, default: "💬"
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs, user_scope) do
    room
    |> cast(attrs, [:name, :description, :is_private, :emoji])
    |> validate_required([:name, :description, :is_private])
    |> validate_length(:emoji, max: 10)
    |> put_change(:user_id, user_scope.user.id)
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
      Chat.broadcast(scope, {:created, room})
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
        Chat.broadcast(scope, {:updated, room})
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
      Chat.broadcast(scope, {:deleted, room})
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
