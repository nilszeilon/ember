defmodule Emberchat.EctoTypes.TruncatedDateTime do
  @behaviour Ecto.Type

  def type, do: :utc_datetime

  def cast(value) do
    case Ecto.Type.cast(:utc_datetime, value) do
      {:ok, datetime} -> {:ok, DateTime.truncate(datetime, :second)}
      error -> error
    end
  end

  def load(value) do
    case Ecto.Type.load(:utc_datetime, value) do
      {:ok, datetime} -> {:ok, DateTime.truncate(datetime, :second)}
      error -> error
    end
  end

  def dump(value) do
    case Ecto.Type.dump(:utc_datetime, value) do
      {:ok, datetime} -> {:ok, DateTime.truncate(datetime, :second)}
      error -> error
    end
  end

  def equal?(term1, term2) do
    term1 == term2
  end

  def embed_as(_), do: :self
end