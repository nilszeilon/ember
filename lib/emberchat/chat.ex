defmodule Emberchat.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Emberchat.Repo
  require Logger

  alias Emberchat.Accounts.Scope
  alias Emberchat.Chat.{Message, EmbeddingGenerator, SemanticSearch}

  # Import all the extracted modules
  alias Emberchat.Chat.{Messages, Reactions, Rooms}

  # Delegate room functions
  defdelegate list_rooms(scope), to: Rooms
  defdelegate get_room!(scope, id), to: Rooms
  defdelegate create_room(scope, attrs), to: Rooms
  defdelegate update_room(scope, room, attrs), to: Rooms
  defdelegate delete_room(scope, room), to: Rooms
  defdelegate change_room(scope, room, attrs \\ %{}), to: Rooms
  defdelegate subscribe_rooms(scope), to: Rooms
  defdelegate broadcast(scope, message), to: Rooms

  # Delegate message functions
  defdelegate list_messages(scope), to: Messages
  defdelegate list_room_messages(scope, room_id, opts \\ []), to: Messages
  defdelegate list_thread_messages(scope, parent_message_id), to: Messages
  defdelegate get_message!(scope, id), to: Messages
  defdelegate create_message(scope, attrs), to: Messages
  defdelegate update_message(scope, message, attrs), to: Messages
  defdelegate delete_message(scope, message), to: Messages
  defdelegate change_message(scope, message, attrs \\ %{}), to: Messages
  defdelegate subscribe_messages(scope), to: Messages
  defdelegate subscribe_search(scope), to: Messages
  defdelegate broadcast_message(scope, message), to: Messages

  # Delegate reaction functions
  defdelegate toggle_reaction(scope, message_id, emoji), to: Reactions
  defdelegate get_message_reactions(message_id), to: Reactions
  defdelegate subscribe_reactions(message_id), to: Reactions

  # Semantic Search Functions

  @doc """
  Search messages using semantic similarity and recency scoring.

  ## Examples

      iex> search_messages("machine learning", scope)
      {:ok, [%Message{}, ...]}
      
      iex> search_messages("invalid query", scope, room_id: 123, limit: 10)
      {:error, reason}
  """
  def search_messages(query, %Scope{} = scope, opts \\ []) do
    SemanticSearch.search_messages(query, scope, opts)
  end

  @doc """
  Find messages similar to a given message.
  """
  def find_similar_messages(%Message{} = message, opts \\ []) do
    SemanticSearch.find_similar_messages(message, opts)
  end

  @doc """
  Get search suggestions based on partial query input.
  """
  def get_search_suggestions(partial_query, %Scope{} = scope, opts \\ []) do
    SemanticSearch.get_search_suggestions(partial_query, scope, opts)
  end

  @doc """
  Generate embeddings for messages that don't have them yet.
  Useful for backfilling embeddings after the feature is added.
  """
  def backfill_embeddings(batch_size \\ 50) do
    EmbeddingGenerator.backfill_missing_embeddings(batch_size)
  end

  @doc """
  Count how many messages don't have embeddings yet.
  """
  def count_messages_without_embeddings do
    EmbeddingGenerator.count_messages_without_embeddings()
  end
end