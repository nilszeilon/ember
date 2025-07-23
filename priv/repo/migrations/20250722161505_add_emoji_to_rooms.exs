defmodule Emberchat.Repo.Migrations.AddEmojiToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :emoji, :string, default: "💬"
    end
  end
end
