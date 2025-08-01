defmodule Emberchat.Chat.Reactions do
  @moduledoc """
  Reaction-related functions for the Chat context.
  """

  import Ecto.Query, warn: false
  alias Emberchat.Repo
  alias Emberchat.Chat.Reaction
  alias Emberchat.Accounts.Scope

  @doc """
  Adds a reaction to a message. If the user has already reacted with the same emoji,
  the reaction will be removed (toggle behavior).
  """
  def toggle_reaction(%Scope{} = scope, message_id, emoji) do
    user_id = scope.user.id

    # Check if reaction already exists
    existing_reaction =
      Repo.get_by(Reaction, message_id: message_id, user_id: user_id, emoji: emoji)

    if existing_reaction do
      # Remove the reaction
      {:ok, _} = Repo.delete(existing_reaction)
      broadcast_reaction_removed(message_id, user_id, emoji)
      {:ok, :removed}
    else
      # Add the reaction
      %Reaction{}
      |> Reaction.changeset(%{
        message_id: message_id,
        user_id: user_id,
        emoji: emoji
      })
      |> Repo.insert()
      |> case do
        {:ok, reaction} ->
          broadcast_reaction_added(message_id, user_id, emoji)
          {:ok, reaction}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Gets all reactions for a message grouped by emoji with user info.
  """
  def get_message_reactions(message_id) do
    from(r in Reaction,
      where: r.message_id == ^message_id,
      join: u in assoc(r, :user),
      select: %{emoji: r.emoji, user: u, user_id: r.user_id}
    )
    |> Repo.all()
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, reactions} ->
      %{
        emoji: emoji,
        count: length(reactions),
        users: Enum.map(reactions, & &1.user),
        user_ids: Enum.map(reactions, & &1.user_id)
      }
    end)
  end

  @doc """
  Subscribe to reactions for a specific message.
  """
  def subscribe_reactions(message_id) do
    Phoenix.PubSub.subscribe(Emberchat.PubSub, "reactions:#{message_id}")
  end

  defp broadcast_reaction_added(message_id, user_id, emoji) do
    Phoenix.PubSub.broadcast(
      Emberchat.PubSub,
      "reactions:#{message_id}",
      {:reaction_added, %{message_id: message_id, user_id: user_id, emoji: emoji}}
    )
  end

  defp broadcast_reaction_removed(message_id, user_id, emoji) do
    Phoenix.PubSub.broadcast(
      Emberchat.PubSub,
      "reactions:#{message_id}",
      {:reaction_removed, %{message_id: message_id, user_id: user_id, emoji: emoji}}
    )
  end
end