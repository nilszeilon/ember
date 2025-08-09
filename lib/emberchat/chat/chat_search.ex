defmodule Emberchat.Chat.ChatSearch do
  @moduledoc """
  Hybrid search functionality combining full-text search and semantic search.
  Provides instant FTS results with optional semantic search enhancement.
  """

  require Logger
  alias Emberchat.{Repo, Chat}
  alias Emberchat.Chat.{Message, SemanticSearch}
  alias Emberchat.Accounts.Scope
  import Ecto.Query

  @default_limit 20
  @semantic_threshold 1000 # Messages threshold for automatic semantic search
  @fts_min_score 0.1

  @doc """
  Perform hybrid search with instant FTS results and optional semantic enhancement.
  
  Options:
  - mode: :fts (default), :semantic, or :hybrid
  - limit: Maximum number of results (default: 20)
  - room_id: Filter by specific room
  - semantic_threshold: Message count threshold for auto-semantic (default: 1000)
  """
  def search(query_text, %Scope{} = scope, opts \\ []) do
    mode = Keyword.get(opts, :mode, :fts)
    limit = Keyword.get(opts, :limit, @default_limit)
    room_id = Keyword.get(opts, :room_id)
    
    case mode do
      :fts ->
        fts_search(query_text, scope, room_id, limit)
      
      :semantic ->
        SemanticSearch.search_messages(query_text, scope, opts)
      
      :hybrid ->
        # Get FTS results immediately
        {:ok, fts_results} = fts_search(query_text, scope, room_id, limit)
        
        # Determine if we should also run semantic search
        if should_use_semantic?(query_text, room_id, opts) do
          # Return FTS results immediately, semantic will be loaded async
          {:ok, fts_results, :semantic_pending}
        else
          {:ok, fts_results}
        end
    end
  end

  @doc """
  Perform full-text search using SQLite FTS5.
  Returns results ordered by relevance and recency.
  """
  def fts_search(query_text, %Scope{} = _scope, room_id, limit) do
    if String.trim(query_text) == "" do
      {:ok, []}
    else
      # Prepare query for FTS5 (escape special characters)
      fts_query = prepare_fts_query(query_text)
      
      # Build the FTS query
      {query_sql, params} = build_fts_query(fts_query, room_id, limit)
      
      case Repo.query(query_sql, params) do
        {:ok, %{rows: rows}} ->
          message_ids = Enum.map(rows, fn [id | _] -> id end)
          messages = load_messages_with_associations(message_ids)
          {:ok, messages}
        
        {:error, reason} ->
          Logger.error("FTS search failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Get search suggestions using FTS5 for autocomplete.
  """
  def get_suggestions(partial_query, %Scope{} = _scope, opts \\ []) do
    room_id = Keyword.get(opts, :room_id)
    limit = Keyword.get(opts, :limit, 10)
    
    if String.length(partial_query) < 2 do
      {:ok, []}
    else
      fts_query = prepare_fts_query(partial_query) <> "*"
      
      query_sql = """
      SELECT DISTINCT highlight(messages_fts, 1, '<b>', '</b>') as highlighted,
             messages_fts.content
      FROM messages_fts
      JOIN messages m ON messages_fts.message_id = m.id
      WHERE messages_fts MATCH ? AND m.deleted_at IS NULL
      #{if room_id, do: "AND m.room_id = ?", else: ""}
      ORDER BY rank
      LIMIT ?
      """
      
      params = if room_id do
        [fts_query, room_id, limit]
      else
        [fts_query, limit]
      end
      
      case Repo.query(query_sql, params) do
        {:ok, %{rows: rows}} ->
          suggestions = rows
          |> Enum.map(fn [highlighted, _content] -> 
            # Extract the highlighted portion
            extract_highlighted_text(highlighted, partial_query)
          end)
          |> Enum.uniq()
          |> Enum.take(limit)
          
          {:ok, suggestions}
        
        {:error, reason} ->
          Logger.error("FTS suggestions failed: #{inspect(reason)}")
          {:ok, []}
      end
    end
  end

  @doc """
  Count messages in a room to determine search strategy.
  """
  def count_room_messages(room_id) do
    from(m in Message, where: m.room_id == ^room_id and is_nil(m.deleted_at), select: count(m.id))
    |> Repo.one()
  end

  # Private functions

  defp prepare_fts_query(text) do
    # Escape special FTS5 characters and prepare query
    text
    |> String.replace(~r/['"*]/, "")
    |> String.split(~r/\s+/)
    |> Enum.map(&("\"" <> &1 <> "\""))
    |> Enum.join(" OR ")
  end

  defp build_fts_query(fts_query, room_id, limit) do
    base_query = """
    SELECT messages_fts.message_id, 
           bm25(messages_fts) as score,
           snippet(messages_fts, 1, '[', ']', '...', 30) as snippet
    FROM messages_fts
    JOIN messages m ON messages_fts.message_id = m.id
    WHERE messages_fts MATCH ? AND m.deleted_at IS NULL
    """
    
    {query_sql, params} = if room_id do
      query = base_query <> " AND m.room_id = ?"
      {query, [fts_query, room_id]}
    else
      {base_query, [fts_query]}
    end
    
    # Add ordering and limit
    final_query = query_sql <> """
    ORDER BY score DESC, m.inserted_at DESC
    LIMIT ?
    """
    
    {final_query, params ++ [limit]}
  end

  defp load_messages_with_associations(message_ids) do
    messages = from(m in Message,
      where: m.id in ^message_ids and is_nil(m.deleted_at),
      preload: [:user, parent_message: :user]
    )
    |> Repo.all()
    
    # Sort messages according to the order in message_ids
    message_map = Map.new(messages, &{&1.id, &1})
    Enum.map(message_ids, &Map.get(message_map, &1))
    |> Enum.filter(&(&1 != nil))
  end

  defp should_use_semantic?(query_text, room_id, opts) do
    threshold = Keyword.get(opts, :semantic_threshold, @semantic_threshold)
    
    # Check if query is complex enough for semantic search
    word_count = length(String.split(query_text, ~r/\s+/))
    
    if word_count >= 3 do
      # Check room size if room_id is provided
      if room_id do
        count_room_messages(room_id) >= threshold
      else
        true # For global search, use semantic if query is complex
      end
    else
      false
    end
  end

  defp extract_highlighted_text(highlighted, partial_query) do
    # Extract text between <b> tags or use partial query
    case Regex.run(~r/<b>(.*?)<\/b>/, highlighted) do
      [_, match] -> match
      _ -> 
        # Fallback to extracting relevant phrase
        words = String.split(highlighted, ~r/\s+/)
        relevant_word = Enum.find(words, fn word ->
          String.contains?(String.downcase(word), String.downcase(partial_query))
        end)
        relevant_word || partial_query
    end
  end

  @doc """
  Merge FTS and semantic results intelligently.
  Removes duplicates and maintains relevance ordering.
  """
  def merge_search_results(fts_results, semantic_results) do
    # Create a map of message IDs to track duplicates
    seen_ids = MapSet.new(Enum.map(fts_results, & &1.id))
    
    # Add semantic results that aren't in FTS results
    unique_semantic = Enum.reject(semantic_results, fn msg ->
      MapSet.member?(seen_ids, msg.id)
    end)
    
    # Combine results, FTS first (more relevant for exact matches)
    fts_results ++ unique_semantic
  end
end