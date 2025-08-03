defmodule EmberchatWeb.ChatLive.Navigation do
  import Phoenix.Component, only: [assign: 3]
  use Phoenix.VerifiedRoutes, endpoint: EmberchatWeb.Endpoint, router: EmberchatWeb.Router

  def handle_event("toggle_drawer", _params, socket) do
    new_drawer_state = !socket.assigns.drawer_open

    # Store drawer state in process dictionary for persistence across navigation
    Process.put(:drawer_open, new_drawer_state)

    {:noreply, assign(socket, :drawer_open, new_drawer_state)}
  end

  def handle_event("keyboard_shortcut", %{"key" => "/"}, socket) do
    # / opens search modal
    EmberchatWeb.ChatLive.Search.handle_event("show_search_modal", %{}, socket)
  end

  def handle_event("keyboard_shortcut", %{"key" => "j", "ctrlKey" => true}, socket) do
    # Ctrl+J moves to next room
    navigate_to_next_room(socket)
  end

  def handle_event("keyboard_shortcut", %{"key" => "k", "ctrlKey" => true}, socket) do
    # Ctrl+K moves to previous room
    navigate_to_previous_room(socket)
  end

  def handle_event("keyboard_shortcut", %{"key" => "Escape"}, socket) do
    socket =
      socket
      |> assign(:show_search_modal, false)
      |> assign(:show_room_modal, false)
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

  def handle_event("keyboard_shortcut", %{"key" => "n"}, socket) do
    {:noreply, Phoenix.LiveView.push_event(socket, "focus_message_input", %{})}
  end

  def handle_event("keyboard_shortcut", %{"key" => "r"}, socket) do
    # Reply to selected message
    case get_selected_message(socket) do
      nil ->
        {:noreply, socket}

      message ->
        # Trigger reply action for the selected message
        case EmberchatWeb.ChatLive.Messages.handle_event(
               "reply_to",
               %{"message_id" => to_string(message.id)},
               socket
             ) do
          {:noreply, updated_socket} ->
            # Push focus event after successfully setting up reply
            {:noreply, Phoenix.LiveView.push_event(updated_socket, "focus_message_input", %{})}

          other ->
            other
        end
    end
  end

  def handle_event("keyboard_shortcut", %{"key" => "l"}, socket) do
    # Like/React to selected message
    case get_selected_message(socket) do
      nil ->
        {:noreply, socket}

      message ->
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
            %{"message_id" => to_string(message.id)},
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

  def handle_event("keyboard_shortcut", %{"key" => "s"}, socket) do
    # Toggle thread for selected message

    case get_selected_message(socket) do
      nil ->
        {:noreply, socket}

      message ->
        if message.reply_count > 0 do
          # Toggle thread for this message
          expanded_threads = socket.assigns.expanded_threads
          is_expanded = MapSet.member?(expanded_threads, message.id)

          new_expanded_threads =
            if is_expanded do
              MapSet.delete(expanded_threads, message.id)
            else
              MapSet.put(expanded_threads, message.id)
            end

          {:noreply, assign(socket, :expanded_threads, new_expanded_threads)}
        else
          IO.puts("Message has no replies, ignoring")
          {:noreply, socket}
        end
    end
  end

  def handle_event("keyboard_shortcut", _params, socket) do
    # Ignore other keyboard shortcuts
    {:noreply, socket}
  end

  def handle_event("hide_keyboard_shortcuts", _params, socket) do
    {:noreply, assign(socket, :show_keyboard_shortcuts, false)}
  end

  def handle_event("noop", _params, socket) do
    # Do nothing - used to stop click propagation
    {:noreply, socket}
  end

  defp navigate_to_next_room(socket) do
    rooms = Map.get(socket.assigns, :rooms, [])
    current_room = Map.get(socket.assigns, :current_room)

    case {rooms, current_room} do
      {[], _} ->
        {:noreply, socket}

      {[_ | _] = rooms, nil} ->
        # No current room, navigate to first room
        first_room = hd(rooms)
        {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/#{first_room.id}")}

      {rooms, current_room} ->
        # Find current room index
        current_index = Enum.find_index(rooms, fn room -> room.id == current_room.id end)

        case current_index do
          nil ->
            # Current room not found in list, navigate to first room
            first_room = hd(rooms)
            {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/#{first_room.id}")}

          index when index < length(rooms) - 1 ->
            # Navigate to next room
            next_room = Enum.at(rooms, index + 1)
            {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/#{next_room.id}")}

          _ ->
            # Already at last room, wrap to first
            first_room = hd(rooms)
            {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/#{first_room.id}")}
        end
    end
  end

  defp navigate_to_previous_room(socket) do
    rooms = Map.get(socket.assigns, :rooms, [])
    current_room = Map.get(socket.assigns, :current_room)

    case {rooms, current_room} do
      {[], _} ->
        {:noreply, socket}

      {[_ | _] = rooms, nil} ->
        # No current room, navigate to last room
        last_room = List.last(rooms)
        {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/#{last_room.id}")}

      {rooms, current_room} ->
        # Find current room index
        current_index = Enum.find_index(rooms, fn room -> room.id == current_room.id end)

        case current_index do
          nil ->
            # Current room not found in list, navigate to last room
            last_room = List.last(rooms)
            {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/#{last_room.id}")}

          0 ->
            # Already at first room, wrap to last
            last_room = List.last(rooms)
            {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/#{last_room.id}")}

          index ->
            # Navigate to previous room
            prev_room = Enum.at(rooms, index - 1)
            {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/#{prev_room.id}")}
        end
    end
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
end
