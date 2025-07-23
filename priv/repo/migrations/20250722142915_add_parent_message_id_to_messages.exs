defmodule Emberchat.Repo.Migrations.AddParentMessageIdToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :parent_message_id, references(:messages, on_delete: :nilify_all)
    end
    
    create index(:messages, [:parent_message_id])
  end
end
