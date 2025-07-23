defmodule Emberchat.Chat.EmbeddingGenerator do
  @moduledoc """
  Handles generation and management of embeddings for chat messages.
  """

  require Logger
  alias Emberchat.{Repo, Embeddings}
  alias Emberchat.Chat.Message
  import Ecto.Query

  @doc """
  Generate and store embedding for a message.
  """
  def generate_embedding_for_message(%Message{} = message) do
    case Embeddings.generate_embedding(message.content) do
      {:ok, embedding} ->
        update_message_embedding(message, embedding)
      {:error, reason} ->
        Logger.error("Failed to generate embedding for message #{message.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Generate embeddings for multiple messages in batch.
  """
  def generate_embeddings_for_messages(messages) when is_list(messages) do
    contents = Enum.map(messages, & &1.content)
    
    case Embeddings.generate_batch_embeddings(contents) do
      {:ok, embeddings} ->
        messages
        |> Enum.zip(embeddings)
        |> Enum.map(fn {message, embedding} ->
          update_message_embedding(message, embedding)
        end)
        |> handle_batch_results()
      {:error, reason} ->
        Logger.error("Failed to generate batch embeddings: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Update message embedding in database and sync to vector table.
  """
  def update_message_embedding(%Message{} = message, embedding) when is_list(embedding) do
    changeset = Message.embedding_changeset(message, embedding)
    
    case Repo.update(changeset) do
      {:ok, updated_message} ->
        sync_to_vector_table(updated_message, embedding)
        {:ok, updated_message}
      {:error, changeset} ->
        Logger.error("Failed to update embedding for message #{message.id}: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Sync message embedding to sqlite-vec virtual table.
  """
  def sync_to_vector_table(%Message{id: message_id}, embedding) when is_list(embedding) do
    # Convert embedding list to JSON array string for sqlite-vec
    embedding_json = Jason.encode!(embedding)
    
    query = """
    INSERT OR REPLACE INTO message_embeddings (message_id, embedding)
    VALUES (?, ?)
    """
    
    case Repo.query(query, [message_id, embedding_json]) do
      {:ok, _result} ->
        Logger.debug("Synced embedding for message #{message_id} to vector table")
        :ok
      {:error, reason} ->
        Logger.error("Failed to sync embedding to vector table for message #{message_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Remove message from vector table.
  """
  def remove_from_vector_table(message_id) when is_integer(message_id) do
    query = "DELETE FROM message_embeddings WHERE message_id = ?"
    
    case Repo.query(query, [message_id]) do
      {:ok, _result} ->
        Logger.debug("Removed message #{message_id} from vector table")
        :ok
      {:error, reason} ->
        Logger.error("Failed to remove message #{message_id} from vector table: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Generate embeddings for all messages that don't have them yet.
  """
  def backfill_missing_embeddings(batch_size \\ 50) do
    Logger.info("Starting embedding backfill process...")
    
    count = count_messages_without_embeddings()
    Logger.info("Found #{count} messages without embeddings")
    
    if count > 0 do
      process_batches(batch_size, count)
    else
      {:ok, 0}
    end
  end

  @doc """
  Count messages without embeddings.
  """
  def count_messages_without_embeddings do
    from(m in Message, where: is_nil(m.embedding) or m.embedding == "")
    |> Repo.aggregate(:count)
  end

  # Private helper functions

  defp handle_batch_results(results) do
    successes = Enum.count(results, &match?({:ok, _}, &1))
    failures = Enum.count(results, &match?({:error, _}, &1))
    
    if failures > 0 do
      Logger.warning("Batch embedding generation completed with #{failures} failures out of #{successes + failures} total")
    end
    
    {:ok, %{successes: successes, failures: failures, results: results}}
  end

  defp process_batches(batch_size, total_count) do
    total_processed = 0
    process_batch_recursive(batch_size, total_count, total_processed)
  end

  defp process_batch_recursive(_batch_size, total_count, total_processed) when total_processed >= total_count do
    Logger.info("Embedding backfill completed. Processed #{total_processed} messages.")
    {:ok, total_processed}
  end

  defp process_batch_recursive(batch_size, total_count, total_processed) do
    messages = 
      from(m in Message, 
        where: is_nil(m.embedding) or m.embedding == "",
        limit: ^batch_size,
        order_by: [asc: m.id]
      )
      |> Repo.all()

    if Enum.empty?(messages) do
      Logger.info("No more messages to process. Completed #{total_processed} messages.")
      {:ok, total_processed}
    else
      Logger.info("Processing batch of #{length(messages)} messages (#{total_processed + length(messages)}/#{total_count})...")
      
      case generate_embeddings_for_messages(messages) do
        {:ok, %{successes: successes}} ->
          new_total = total_processed + successes
          process_batch_recursive(batch_size, total_count, new_total)
        {:error, reason} ->
          Logger.error("Batch processing failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end