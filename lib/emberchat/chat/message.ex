defmodule Emberchat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "messages" do
    field :content, :string
    field :room_id, :id
    field :reply_count, :integer, default: 0
    field :last_reply_at, :utc_datetime
    field :embedding, :string
    
    belongs_to :user, Emberchat.Accounts.User
    belongs_to :parent_message, __MODULE__
    has_many :replies, __MODULE__, foreign_key: :parent_message_id
    has_many :reactions, Emberchat.Chat.Reaction

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs, user_scope) do
    message
    |> cast(attrs, [:content, :room_id, :parent_message_id])
    |> validate_required([:content, :room_id])
    |> put_change(:user_id, user_scope.user.id)
    |> validate_parent_message_exists()
  end

  @doc """
  Changeset for updating the embedding field.
  """
  def embedding_changeset(message, embedding) when is_list(embedding) do
    json_embedding = Jason.encode!(embedding)
    change(message, embedding: json_embedding)
  end

  @doc """
  Get the embedding as a list of floats.
  """
  def get_embedding(%__MODULE__{embedding: nil}), do: nil
  def get_embedding(%__MODULE__{embedding: embedding}) when is_binary(embedding) do
    case Jason.decode(embedding) do
      {:ok, list} when is_list(list) -> list
      _ -> nil
    end
  end

  @doc """
  Check if message has an embedding.
  """
  def has_embedding?(%__MODULE__{embedding: nil}), do: false
  def has_embedding?(%__MODULE__{embedding: ""}), do: false
  def has_embedding?(%__MODULE__{embedding: _}), do: true

  defp validate_parent_message_exists(changeset) do
    case get_field(changeset, :parent_message_id) do
      nil -> changeset
      parent_id ->
        if parent_message_exists?(parent_id) do
          changeset
        else
          add_error(changeset, :parent_message_id, "does not exist")
        end
    end
  end

  defp parent_message_exists?(parent_id) do
    Emberchat.Repo.exists?(from m in __MODULE__, where: m.id == ^parent_id)
  end
end
