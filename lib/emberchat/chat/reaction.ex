defmodule Emberchat.Chat.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reactions" do
    field :emoji, :string
    belongs_to :message, Emberchat.Chat.Message
    belongs_to :user, Emberchat.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:emoji, :message_id, :user_id])
    |> validate_required([:emoji, :message_id, :user_id])
    |> validate_emoji()
    |> unique_constraint([:message_id, :user_id, :emoji])
  end

  defp validate_emoji(changeset) do
    validate_change(changeset, :emoji, fn :emoji, emoji ->
      allowed_emojis = ["👍", "❤️", "😂", "🎉", "🤔", "👎", "🔥", "👏", "💯", "😢"]
      
      if emoji in allowed_emojis do
        []
      else
        [emoji: "is not a valid reaction emoji"]
      end
    end)
  end
end