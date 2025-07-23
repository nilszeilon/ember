defmodule Emberchat.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

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
end
