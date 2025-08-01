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

    {:noreply, socket}
  end

  def handle_event("keyboard_shortcut", _params, socket) do
    # Ignore other keyboard shortcuts
    {:noreply, socket}
  end

  def handle_event("noop", _params, socket) do
    # Do nothing - used to stop click propagation
    {:noreply, socket}
  end
end