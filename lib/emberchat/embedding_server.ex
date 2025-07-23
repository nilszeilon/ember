defmodule Emberchat.EmbeddingServer do
  @moduledoc """
  GenServer that manages the Bumblebee embedding service.
  """
  
  use GenServer
  require Logger

  @model_repo {:hf, "sentence-transformers/all-MiniLM-L6-v2"}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Logger.info("Starting Bumblebee embedding service...")
    
    case setup_embedding_serving() do
      {:ok, serving} ->
        :persistent_term.put(Emberchat.Embeddings, serving)
        Logger.info("Bumblebee embedding service started successfully")
        {:ok, %{serving: serving}}
      {:error, reason} ->
        Logger.error("Failed to start Bumblebee embedding service: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp setup_embedding_serving do
    try do
      Logger.info("Loading Bumblebee model and tokenizer...")
      
      {:ok, model_info} = Bumblebee.load_model(@model_repo)
      {:ok, tokenizer} = Bumblebee.load_tokenizer(@model_repo)
      
      Logger.info("Setting up text embedding serving...")
      
      serving = Bumblebee.Text.TextEmbedding.text_embedding(model_info, tokenizer,
        output_pool: :mean_pooling,
        output_attribute: :hidden_state,
        embedding_processor: :l2_norm,
        compile: [batch_size: 1, sequence_length: 512],
        defn_options: [compiler: EXLA]
      )
      
      {:ok, serving}
    rescue
      error ->
        Logger.error("Failed to setup Bumblebee serving: #{inspect(error)}")
        {:error, error}
    end
  end
end