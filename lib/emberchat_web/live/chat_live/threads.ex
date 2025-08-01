defmodule EmberchatWeb.ChatLive.Threads do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]
  
  alias Emberchat.Chat

  def handle_event("show_thread", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    parent_message = Enum.find(socket.assigns.messages, &(&1.id == message_id))
    thread_messages = Chat.list_thread_messages(socket.assigns.current_scope, message_id)

    # Get thread draft if exists
    thread_key = "thread_#{message_id}"
    thread_draft = Map.get(socket.assigns.drafts, thread_key, "")

    {:noreply,
     socket
     |> assign(:show_thread, true)
     |> assign(:thread_parent_message, parent_message)
     |> assign(:thread_messages, thread_messages)
     |> assign(:thread_draft, thread_draft)}
  end

  def handle_event("close_thread", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_thread, false)
     |> assign(:thread_parent_message, nil)
     |> assign(:thread_messages, [])
     |> assign(:thread_draft, "")}
  end

  def handle_event("update_thread_draft", %{"message" => %{"content" => draft}}, socket) do
    if socket.assigns.thread_parent_message do
      # Store thread draft with parent message ID as key
      thread_key = "thread_#{socket.assigns.thread_parent_message.id}"
      drafts = Map.put(socket.assigns.drafts, thread_key, draft)
      {:noreply, assign(socket, :drafts, drafts)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("hide_thread", _params, socket) do
    # Hide thread but keep draft
    {:noreply, assign(socket, :show_thread, false)}
  end

  def handle_event("send_thread_message", %{"message" => message_params}, socket) do
    case Chat.create_message(socket.assigns.current_scope, message_params) do
      {:ok, _message} ->
        # Clear thread draft after successful send
        thread_key = "thread_#{socket.assigns.thread_parent_message.id}"
        drafts = Map.delete(socket.assigns.drafts, thread_key)
        {:noreply, socket |> assign(:drafts, drafts) |> assign(:thread_draft, "")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end
end