defmodule EmberchatWeb.ChatLive.Navigation do
  import Phoenix.Component, only: [assign: 3]

  def handle_event("toggle_drawer", _params, socket) do
    new_drawer_state = !socket.assigns.drawer_open

    # Store drawer state in process dictionary for persistence across navigation
    Process.put(:drawer_open, new_drawer_state)

    {:noreply, assign(socket, :drawer_open, new_drawer_state)}
  end

  def handle_event("keyboard_shortcut", %{"key" => "k", "ctrlKey" => true}, socket) do
    # Ctrl+K opens search modal
    EmberchatWeb.ChatLive.Search.handle_event("show_search_modal", %{}, socket)
  end

  def handle_event("keyboard_shortcut", %{"key" => "k", "metaKey" => true}, socket) do
    # Cmd+K opens search modal (for Mac)
    EmberchatWeb.ChatLive.Search.handle_event("show_search_modal", %{}, socket)
  end

  def handle_event("keyboard_shortcut", %{"key" => "Escape"}, socket) do
    # ESC closes open modals/interfaces and focuses search
    socket =
      socket
      |> assign(:show_search_modal, false)
      |> assign(:show_room_modal, false)
      |> assign(:show_thread, false)
      |> assign(:show_keyboard_shortcuts, false)

    {:noreply, socket}
  end

  def handle_event("keyboard_shortcut", %{"key" => "?"}, socket) do
    # Show keyboard shortcuts help
    {:noreply, assign(socket, :show_keyboard_shortcuts, true)}
  end

  def handle_event("keyboard_shortcut", %{"key" => "j"}, socket) do
    # Navigate to next message
    selected_index = Map.get(socket.assigns, :selected_message_index, -1)
    messages = Map.get(socket.assigns, :messages, [])

    new_index = min(selected_index + 1, length(messages) - 1)

    IO.puts(new_index)

    socket =
      socket
      |> assign(:selected_message_index, new_index)
      |> maybe_scroll_to_message(messages, new_index)

    {:noreply, socket}
  end

  def handle_event("keyboard_shortcut", %{"key" => "k"}, socket) do
    # Navigate to previous message
    selected_index = Map.get(socket.assigns, :selected_message_index, 0)

    new_index = max(selected_index - 1, 0)
    messages = Map.get(socket.assigns, :messages, [])

    socket =
      socket
      |> assign(:selected_message_index, new_index)
      |> maybe_scroll_to_message(messages, new_index)

    {:noreply, socket}
  end

  def handle_event("keyboard_shortcut", %{"key" => "r"}, socket) do
    # Reply to selected message
    case get_selected_message(socket) do
      nil ->
        {:noreply, socket}

      message ->
        # Trigger reply action for the selected message
        EmberchatWeb.ChatLive.Messages.handle_event(
          "reply_to_message",
          %{"message_id" => message.id},
          socket
        )
    end
  end

  def handle_event("keyboard_shortcut", %{"key" => "l"}, socket) do
    # Like/React to selected message
    case get_selected_message(socket) do
      nil ->
        IO.puts("no message fool")
        {:noreply, socket}

      message ->
        IO.inspect(message)
        # Toggle thumbs up reaction on selected message
        EmberchatWeb.ChatLive.Reactions.handle_event(
          "toggle_reaction",
          %{"message_id" => to_string(message.id), "emoji" => "👍"},
          socket
        )
    end
  end

  def handle_event("keyboard_shortcut", %{"key" => "p"}, socket) do
    # Pin/Unpin selected message
    case get_selected_message(socket) do
      nil ->
        {:noreply, socket}

      message ->
        if message.pinned_slug do
          # Unpin the message
          EmberchatWeb.ChatLive.Pinned.handle_event(
            "unpin_message",
            %{"message_id" => message.id},
            socket
          )
        else
          # Show pin modal for the message
          socket =
            socket
            |> assign(:pin_message_id, message.id)
            |> assign(:show_pin_modal, true)
            |> assign(:pin_slug, "")

          {:noreply, socket}
        end
    end
  end

  def handle_event("keyboard_shortcut", %{"key" => "n"}, socket) do
    # Focus on new message input
    {:noreply, Phoenix.LiveView.push_event(socket, "focus_message_input", %{})}
  end

  def handle_event("keyboard_shortcut", _params, socket) do
    # Ignore other keyboard shortcuts
    {:noreply, socket}
  end

  def handle_event("hide_keyboard_shortcuts", _params, socket) do
    {:noreply, assign(socket, :show_keyboard_shortcuts, false)}
  end

  # Helper functions
  defp get_selected_message(socket) do
    index = Map.get(socket.assigns, :selected_message_index, -1)
    messages = Map.get(socket.assigns, :messages, [])

    if index >= 0 and index < length(messages) do
      Enum.at(messages, index)
    else
      nil
    end
  end

  defp maybe_scroll_to_message(socket, messages, index) do
    if index >= 0 and index < length(messages) do
      message = Enum.at(messages, index)

      if message do
        Phoenix.LiveView.push_event(socket, "scroll_to_message", %{message_id: message.id})
      else
        socket
      end
    else
      socket
    end
  end

  def handle_event("noop", _params, socket) do
    # Do nothing - used to stop click propagation
    {:noreply, socket}
  end
end
