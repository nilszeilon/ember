defmodule Emberchat.Repo.Migrations.CreateReactions do
  use Ecto.Migration

  def change do
    create table(:reactions) do
      add :emoji, :string, null: false
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:reactions, [:message_id])
    create index(:reactions, [:user_id])
    create unique_index(:reactions, [:message_id, :user_id, :emoji])
  end
end