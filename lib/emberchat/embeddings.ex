defmodule Emberchat.Embeddings do
  @moduledoc """
  Service for generating text embeddings using all-MiniLM-L6-v2 model.
  Uses Bumblebee for native Elixir embedding generation.
  """

  require Logger

  @embedding_dimensions 384
  @model_repo {:hf, "sentence-transformers/all-MiniLM-L6-v2"}


  @doc """
  Check if the embedding service is healthy and ready.
  """
  def health_check do
    try do
      serving = :persistent_term.get(__MODULE__)
      # Try a simple embedding to verify the service works
      case Nx.Serving.run(serving, "test") do
        %{embedding: _} -> {:ok, :healthy}
        _ -> {:error, :unhealthy}
      end
    catch
      :error, {:badkey, _} -> {:error, :not_started}
      error -> {:error, {:service_error, error}}
    end
  end

  @doc """
  Generate embedding for a single text string.
  Returns {:ok, embedding_vector} or {:error, reason}.
  """
  def generate_embedding(text) when is_binary(text) do
    if String.trim(text) == "" do
      {:error, :empty_text}
    else
      try do
        serving = :persistent_term.get(__MODULE__)
        result = Nx.Serving.run(serving, text)
        embedding = result.embedding |> Nx.to_list()
        {:ok, embedding}
      catch
        :error, {:badkey, _} -> {:error, :service_not_started}
        error -> {:error, {:embedding_error, error}}
      end
    end
  end

  @doc """
  Generate embeddings for multiple text strings.
  Returns {:ok, [embedding_vectors]} or {:error, reason}.
  """
  def generate_batch_embeddings(texts) when is_list(texts) do
    valid_texts = texts |> Enum.filter(&is_binary/1) |> Enum.reject(&(String.trim(&1) == ""))
    
    if Enum.empty?(valid_texts) do
      {:error, :no_valid_texts}
    else
      try do
        serving = :persistent_term.get(__MODULE__)
        embeddings = 
          valid_texts
          |> Enum.map(fn text ->
            result = Nx.Serving.run(serving, text)
            result.embedding |> Nx.to_list()
          end)
        {:ok, embeddings}
      catch
        :error, {:badkey, _} -> {:error, :service_not_started}
        error -> {:error, {:embedding_error, error}}
      end
    end
  end

  @doc """
  Calculate cosine similarity between two embedding vectors.
  """
  def cosine_similarity(vec1, vec2) when is_list(vec1) and is_list(vec2) do
    if length(vec1) != length(vec2) do
      {:error, :dimension_mismatch}
    else
      dot_product = vec1 |> Enum.zip(vec2) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()
      magnitude1 = vec1 |> Enum.map(&(&1 * &1)) |> Enum.sum() |> :math.sqrt()
      magnitude2 = vec2 |> Enum.map(&(&1 * &1)) |> Enum.sum() |> :math.sqrt()
      
      if magnitude1 == 0 or magnitude2 == 0 do
        {:ok, 0.0}
      else
        similarity = dot_product / (magnitude1 * magnitude2)
        {:ok, similarity}
      end
    end
  end

  @doc """
  Get the expected embedding dimensions for this service.
  """
  def embedding_dimensions, do: @embedding_dimensions

end