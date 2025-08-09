defmodule Emberchat.Repo.Migrations.AddSoftDeleteAndEditTrackingToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :deleted_at, :utc_datetime
      add :edited_at, :utc_datetime
    end

    create index(:messages, [:deleted_at])
  end
end
