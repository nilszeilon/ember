defmodule Emberchat.Repo.Migrations.SetupFtsSearch do
  use Ecto.Migration

  def up do
    # Drop existing FTS table and triggers if they exist
    execute "DROP TRIGGER IF EXISTS messages_fts_delete"
    execute "DROP TRIGGER IF EXISTS messages_fts_update"
    execute "DROP TRIGGER IF EXISTS messages_fts_insert"
    execute "DROP TABLE IF EXISTS messages_fts"
    
    # Create new FTS5 virtual table for full-text search
    execute """
    CREATE VIRTUAL TABLE messages_fts USING fts5(
      content,
      message_id UNINDEXED,
      room_id UNINDEXED,
      user_name UNINDEXED,
      inserted_at UNINDEXED,
      tokenize = 'porter unicode61'
    )
    """

    # Create triggers to keep FTS table in sync with messages table
    execute """
    CREATE TRIGGER messages_fts_insert
    AFTER INSERT ON messages
    BEGIN
      INSERT INTO messages_fts(content, message_id, room_id, user_name, inserted_at)
      SELECT 
        NEW.content,
        NEW.id,
        NEW.room_id,
        u.username,
        NEW.inserted_at
      FROM users u
      WHERE u.id = NEW.user_id;
    END
    """

    execute """
    CREATE TRIGGER messages_fts_update
    AFTER UPDATE ON messages
    BEGIN
      UPDATE messages_fts 
      SET content = NEW.content
      WHERE message_id = NEW.id;
    END
    """

    execute """
    CREATE TRIGGER messages_fts_delete
    AFTER DELETE ON messages
    BEGIN
      DELETE FROM messages_fts WHERE message_id = OLD.id;
    END
    """

    # Populate FTS table with existing messages
    execute """
    INSERT INTO messages_fts(content, message_id, room_id, user_name, inserted_at)
    SELECT 
      m.content,
      m.id,
      m.room_id,
      u.username,
      m.inserted_at
    FROM messages m
    JOIN users u ON m.user_id = u.id
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS messages_fts_delete"
    execute "DROP TRIGGER IF EXISTS messages_fts_update"
    execute "DROP TRIGGER IF EXISTS messages_fts_insert"
    execute "DROP TABLE IF EXISTS messages_fts"
  end
end