defmodule Emberchat.Repo.Migrations.AddThreadMetadataToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :reply_count, :integer, default: 0, null: false
      add :last_reply_at, :utc_datetime
    end

    create index(:messages, [:room_id, :parent_message_id])
  end
end
