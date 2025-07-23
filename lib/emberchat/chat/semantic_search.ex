defmodule Emberchat.Chat.SemanticSearch do
  @moduledoc """
  Semantic search functionality for chat messages.
  Combines vector similarity with recency scoring for optimal search results.
  """

  require Logger
  alias Emberchat.{Repo, Embeddings}
  alias Emberchat.Chat.Message
  alias Emberchat.Accounts.Scope
  import Ecto.Query

  @default_limit 20
  @similarity_weight 0.7
  @recency_weight 0.3
  @min_similarity_threshold 0.1

  @doc """
  Search messages using semantic similarity combined with recency scoring.
  
  Options:
  - limit: Maximum number of results (default: 20)
  - room_id: Filter by specific room
  - similarity_weight: Weight for similarity score (default: 0.7)
  - recency_weight: Weight for recency score (default: 0.3)
  - min_similarity: Minimum similarity threshold (default: 0.1)
  """
  def search_messages(query_text, %Scope{} = _scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    room_id = Keyword.get(opts, :room_id)
    similarity_weight = Keyword.get(opts, :similarity_weight, @similarity_weight)
    recency_weight = Keyword.get(opts, :recency_weight, @recency_weight)
    min_similarity = Keyword.get(opts, :min_similarity, @min_similarity_threshold)

    with {:ok, query_embedding} <- Embeddings.generate_embedding(query_text) do
      search_with_embedding(query_embedding, room_id, limit, similarity_weight, recency_weight, min_similarity)
    else
      {:error, reason} ->
        Logger.error("Failed to generate embedding for search query: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Search messages using a pre-computed embedding vector.
  """
  def search_with_embedding(query_embedding, room_id, limit, similarity_weight, recency_weight, min_similarity) do
    # Get vector similarity results from sqlite-vec
    vector_results = get_vector_similarities(query_embedding, room_id, limit * 2)
    
    case vector_results do
      {:ok, similarities} ->
        # Filter by minimum similarity threshold
        filtered_similarities = Enum.filter(similarities, fn {_id, similarity} -> 
          similarity >= min_similarity 
        end)
        
        if Enum.empty?(filtered_similarities) do
          {:ok, []}
        else
          # Get message details and calculate combined scores
          message_ids = Enum.map(filtered_similarities, fn {id, _sim} -> id end)
          messages = get_messages_with_timestamps(message_ids, room_id)
          
          # Calculate combined scores and sort
          scored_messages = calculate_combined_scores(
            messages, 
            filtered_similarities, 
            similarity_weight, 
            recency_weight
          )
          
          # Return top results
          results = scored_messages
          |> Enum.take(limit)
          |> Enum.map(fn {message, _score} -> message end)
          
          {:ok, results}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get similar messages to a given message.
  """
  def find_similar_messages(%Message{} = message, opts \\ []) do
    case Message.get_embedding(message) do
      nil ->
        {:error, :no_embedding}
      embedding ->
        limit = Keyword.get(opts, :limit, @default_limit)
        room_id = Keyword.get(opts, :room_id, message.room_id)
        similarity_weight = Keyword.get(opts, :similarity_weight, @similarity_weight)
        recency_weight = Keyword.get(opts, :recency_weight, @recency_weight)
        min_similarity = Keyword.get(opts, :min_similarity, @min_similarity_threshold)
        
        # Exclude the current message from results
        results = search_with_embedding(embedding, room_id, limit + 1, similarity_weight, recency_weight, min_similarity)
        
        case results do
          {:ok, messages} ->
            filtered_messages = Enum.reject(messages, fn m -> m.id == message.id end)
            {:ok, Enum.take(filtered_messages, limit)}
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # Private helper functions

  defp get_vector_similarities(query_embedding, room_id, limit) do
    # Convert embedding to JSON format expected by sqlite-vec
    embedding_json = Jason.encode!(query_embedding)
    
    # Build the query based on whether we're filtering by room
    {query, params} = case room_id do
      nil ->
        query = """
        SELECT me.message_id, vec_distance_cosine(me.embedding, ?) as distance
        FROM message_embeddings me
        ORDER BY distance ASC
        LIMIT ?
        """
        {query, [embedding_json, limit]}
      
      room_id ->
        query = """
        SELECT me.message_id, vec_distance_cosine(me.embedding, ?) as distance
        FROM message_embeddings me
        JOIN messages m ON me.message_id = m.id
        WHERE m.room_id = ?
        ORDER BY distance ASC
        LIMIT ?
        """
        {query, [embedding_json, room_id, limit]}
    end

    case Repo.query(query, params) do
      {:ok, %{rows: rows}} ->
        # Convert distance to similarity (1 - distance)
        similarities = Enum.map(rows, fn [message_id, distance] -> 
          similarity = 1.0 - distance
          {message_id, similarity}
        end)
        {:ok, similarities}
      
      {:error, reason} ->
        Logger.error("Vector similarity query failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_messages_with_timestamps(message_ids, room_id) do
    query = from(m in Message,
      where: m.id in ^message_ids,
      preload: [:user, parent_message: :user],
      select: m
    )
    
    query = case room_id do
      nil -> query
      room_id -> from(m in query, where: m.room_id == ^room_id)
    end
    
    Repo.all(query)
    |> Enum.map(fn message -> 
      {message.id, message}
    end)
    |> Map.new()
  end

  defp calculate_combined_scores(messages, similarities, similarity_weight, recency_weight) do
    # Find the newest message timestamp for normalization
    newest_timestamp = messages
    |> Map.values()
    |> Enum.map(& &1.inserted_at)
    |> Enum.max(DateTime)
    
    # Calculate scores for each message
    similarities
    |> Enum.filter(fn {message_id, _similarity} -> Map.has_key?(messages, message_id) end)
    |> Enum.map(fn {message_id, similarity} ->
        message = Map.fetch!(messages, message_id)
        
        # Calculate recency score (0-1, where 1 is most recent)
        time_diff_seconds = DateTime.diff(newest_timestamp, message.inserted_at, :second)
        max_age_seconds = 30 * 24 * 60 * 60  # 30 days
        recency_score = max(0.0, 1.0 - (time_diff_seconds / max_age_seconds))
        
        # Calculate combined score
        combined_score = (similarity * similarity_weight) + (recency_score * recency_weight)
        
        {message, combined_score}
      end)
    |> Enum.sort_by(fn {_message, score} -> score end, :desc)
  end

  @doc """
  Get search suggestions based on partial query.
  Returns common terms that might help with search.
  """
  def get_search_suggestions(partial_query, %Scope{} = _scope, opts \\ []) do
    room_id = Keyword.get(opts, :room_id)
    limit = Keyword.get(opts, :limit, 10)
    
    # Simple word-based suggestions from recent messages
    # This could be enhanced with more sophisticated NLP
    # SQLite doesn't support ilike, use LIKE with LOWER for case-insensitive search
    query = from(m in Message,
      where: fragment("LOWER(?) LIKE LOWER(?)", m.content, ^"%#{partial_query}%"),
      order_by: [desc: m.inserted_at],
      limit: ^(limit * 2),
      select: m.content
    )
    
    query = case room_id do
      nil -> query
      room_id -> from(m in query, where: m.room_id == ^room_id)
    end
    
    suggestions = query
    |> Repo.all()
    |> Enum.flat_map(&extract_relevant_phrases(&1, partial_query))
    |> Enum.uniq()
    |> Enum.take(limit)
    
    {:ok, suggestions}
  end

  defp extract_relevant_phrases(content, partial_query) do
    # Extract phrases containing the partial query
    words = String.split(content, ~r/\s+/)
    query_words = String.split(String.downcase(partial_query), ~r/\s+/)
    
    words
    |> Enum.filter(fn word -> 
      String.contains?(String.downcase(word), query_words)
    end)
    |> Enum.map(&String.trim(&1, ".,!?;:"))
    |> Enum.reject(&(String.length(&1) < 3))
  end
end