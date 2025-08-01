defmodule Emberchat.Repo.Migrations.AddPinningToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :is_pinned, :boolean, default: false, null: false
      add :pin_slug, :string
      add :pinned_at, :utc_datetime
      add :pinned_by_id, references(:users, on_delete: :nilify_all)
    end

    create index(:messages, [:room_id, :is_pinned])
    create unique_index(:messages, [:room_id, :pin_slug])
  end
end