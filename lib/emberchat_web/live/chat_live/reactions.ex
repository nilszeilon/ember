defmodule EmberchatWeb.ChatLive.Reactions do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]
  
  alias Emberchat.Chat

  def handle_event("toggle_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    message_id = String.to_integer(message_id)

    case Chat.toggle_reaction(socket.assigns.current_scope, message_id, emoji) do
      {:ok, :removed} ->
        {:noreply, socket}

      {:ok, _reaction} ->
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add reaction")}
    end
  end

  def handle_event("toggle_show_all_reactions", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)

    expanded_reactions =
      if MapSet.member?(socket.assigns.expanded_reactions, message_id) do
        MapSet.delete(socket.assigns.expanded_reactions, message_id)
      else
        MapSet.put(socket.assigns.expanded_reactions, message_id)
      end

    {:noreply, assign(socket, :expanded_reactions, expanded_reactions)}
  end

  def handle_info({:reaction_added, %{message_id: message_id}}, socket) do
    # Update the message's reaction summary
    messages =
      Enum.map(socket.assigns.messages, fn message ->
        if message.id == message_id do
          reactions = Chat.get_message_reactions(message_id)
          Map.put(message, :reaction_summary, reactions)
        else
          message
        end
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:reaction_removed, %{message_id: message_id}}, socket) do
    # Update the message's reaction summary
    messages =
      Enum.map(socket.assigns.messages, fn message ->
        if message.id == message_id do
          reactions = Chat.get_message_reactions(message_id)
          Map.put(message, :reaction_summary, reactions)
        else
          message
        end
      end)

    {:noreply, assign(socket, :messages, messages)}
  end
end