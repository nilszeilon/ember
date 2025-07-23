defmodule Emberchat.Repo.Migrations.AddVectorEmbeddingsToMessages do
  use Ecto.Migration

  def up do
    # Add vector embedding column (384 dimensions for all-MiniLM-L6-v2)
    alter table(:messages) do
      add :embedding, :text
    end

    # Create virtual table for vector similarity search using sqlite-vec
    # The extension should already be loaded via configuration
    execute("""
    CREATE VIRTUAL TABLE message_embeddings USING vec0(
      message_id INTEGER PRIMARY KEY,
      embedding FLOAT[384]
    )
    """)

    # Create index for vector search performance
    create index(:messages, [:room_id, :inserted_at])
    create index(:messages, [:user_id, :inserted_at])
  end

  def down do
    # Drop the virtual table
    execute("DROP TABLE IF EXISTS message_embeddings")

    # Remove the embedding column
    alter table(:messages) do
      remove :embedding
    end

    # Drop the new indexes
    drop index(:messages, [:room_id, :inserted_at])
    drop index(:messages, [:user_id, :inserted_at])
  end
end
