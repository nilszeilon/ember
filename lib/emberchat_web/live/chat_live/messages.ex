defmodule EmberchatWeb.ChatLive.Messages do
  import Phoenix.Component, only: [assign: 3, update: 3]
  import Phoenix.LiveView, only: [put_flash: 3]
  
  alias Emberchat.Chat
  alias Emberchat.Chat.Message

  def handle_event("reply_to", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    replying_to = Enum.find(socket.assigns.messages, &(&1.id == message_id))

    {:noreply, assign(socket, :replying_to, replying_to)}
  end

  def handle_event("cancel_reply", _params, socket) do
    {:noreply, assign(socket, :replying_to, nil)}
  end

  def handle_event("update_draft", %{"message" => %{"content" => draft}}, socket) do
    room_id = socket.assigns.current_room.id
    drafts = Map.put(socket.assigns.drafts, room_id, draft)
    {:noreply, assign(socket, :drafts, drafts)}
  end

  def handle_event("send_message", %{"message" => message_params}, socket) do
    # Add parent_message_id if replying
    message_params =
      if socket.assigns.replying_to do
        Map.put(message_params, "parent_message_id", socket.assigns.replying_to.id)
      else
        message_params
      end

    case Chat.create_message(socket.assigns.current_scope, message_params) do
      {:ok, _message} ->
        # Clear draft for this room after successful send
        room_id = socket.assigns.current_room.id
        drafts = Map.delete(socket.assigns.drafts, room_id)

        {:noreply,
         socket
         |> assign(:new_message, %Message{room_id: socket.assigns.current_room.id})
         |> assign(:replying_to, nil)
         |> assign(:drafts, drafts)
         |> put_flash(:info, "Message sent successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :new_message, changeset)}
    end
  end

  def handle_event("find_similar", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)

    Task.start(fn ->
      # Get the message first
      case Emberchat.Repo.get(Message, message_id) do
        nil ->
          send(self(), {:search_error, "Message not found"})

        message ->
          case Chat.find_similar_messages(message,
                 limit: 10,
                 room_id: socket.assigns.selected_search_room
               ) do
            {:ok, similar_messages} ->
              send(self(), {:similar_search_results_ready, similar_messages, message})

            {:error, reason} ->
              send(self(), {:search_error, "Failed to find similar messages: #{inspect(reason)}"})
          end
      end
    end)

    {:noreply, assign(socket, :searching, true)}
  end

  def handle_info({:created, %Message{} = message}, socket) do
    if socket.assigns.current_room && message.room_id == socket.assigns.current_room.id do
      # If it's a reply, update the parent message's reply count and don't show in main chat
      if message.parent_message_id do
        # Update parent message reply count
        messages =
          Enum.map(socket.assigns.messages, fn m ->
            if m.id == message.parent_message_id do
              m
              |> Map.put(:reply_count, (m.reply_count || 0) + 1)
              |> Map.put(:last_reply_at, message.inserted_at)
            else
              m
            end
          end)

        # If thread is open for this parent message, add to thread messages
        socket =
          if socket.assigns.thread_parent_message &&
               socket.assigns.thread_parent_message.id == message.parent_message_id do
            update(socket, :thread_messages, &(&1 ++ [message]))
          else
            socket
          end

        {:noreply, assign(socket, :messages, messages)}
      else
        # It's a top-level message, add to main chat
        # Subscribe to reactions for the new message
        if Phoenix.LiveView.connected?(socket) do
          Chat.subscribe_reactions(message.id)
        end

        # Add the message with empty reaction summary
        message_with_reactions = Map.put(message, :reaction_summary, [])

        {:noreply, update(socket, :messages, &(&1 ++ [message_with_reactions]))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:updated, %Message{} = message}, socket) do
    if socket.assigns.current_room && message.room_id == socket.assigns.current_room.id do
      messages =
        Enum.map(socket.assigns.messages, fn m ->
          if m.id == message.id, do: message, else: m
        end)

      # Update pinned messages list if the message's pin status changed
      old_message = Enum.find(socket.assigns.messages, &(&1.id == message.id))

      pinned_messages =
        if old_message && message.is_pinned != old_message.is_pinned do
          Emberchat.Chat.Pinned.list_pinned_messages(
            socket.assigns.current_scope,
            socket.assigns.current_room.id
          )
        else
          socket.assigns.pinned_messages
        end

      {:noreply,
       socket
       |> assign(:messages, messages)
       |> assign(:pinned_messages, pinned_messages)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, %Message{} = message}, socket) do
    if socket.assigns.current_room && message.room_id == socket.assigns.current_room.id do
      messages = Enum.reject(socket.assigns.messages, &(&1.id == message.id))
      {:noreply, assign(socket, :messages, messages)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:clear_highlight, socket) do
    {:noreply, assign(socket, :highlight_message_id, nil)}
  end
end