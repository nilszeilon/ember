defmodule EmberchatWeb.ChatLive do
  use EmberchatWeb, :live_view
  import EmberchatWeb.ChatComponents

  alias Emberchat.Chat
  alias Emberchat.Chat.Message
  alias Emberchat.Chat.Room
  alias Emberchat.Chat.Pinned
  alias EmberchatWeb.ChatLive.Pinned, as: PinnedHelpers
  alias EmberchatWeb.ChatLive.Room, as: RoomHelpers
  alias EmberchatWeb.ChatLive.Messages, as: MessagesHelpers
  alias EmberchatWeb.ChatLive.Search, as: SearchHelpers
  alias EmberchatWeb.ChatLive.Threads, as: ThreadsHelpers
  alias EmberchatWeb.ChatLive.Reactions, as: ReactionsHelpers
  alias EmberchatWeb.ChatLive.Navigation, as: NavigationHelpers

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Chat.subscribe_rooms(socket.assigns.current_scope)
      Chat.subscribe_messages(socket.assigns.current_scope)
      Chat.subscribe_search(socket.assigns.current_scope)
    end

    rooms = Room.list_rooms(socket.assigns.current_scope)

    # Get drawer state from process dictionary or default to false
    drawer_open = Process.get(:drawer_open, false)

    {:ok,
     socket
     |> assign(:rooms, rooms)
     |> assign(:current_room, nil)
     |> assign(:messages, [])
     |> assign(:new_message, %Message{})
     |> assign(:replying_to, nil)
     |> assign(:drawer_open, drawer_open)
     |> assign(:show_room_modal, false)
     |> assign(:room_modal_mode, :new)
     |> assign(:room_form, nil)
     |> assign(:editing_room, nil)
     |> assign(:selected_emoji, "💬")
     |> assign(:emoji_options, [
       "💬",
       "🔥",
       "✨",
       "🎉",
       "🚀",
       "💡",
       "🎯",
       "🏆",
       "🌟",
       "💼",
       "🎨",
       "🎮",
       "🎵",
       "📚",
       "🍕",
       "☕"
     ])
     |> assign(:show_thread, false)
     |> assign(:thread_parent_message, nil)
     |> assign(:thread_messages, [])
     |> assign(:thread_draft, "")
     |> assign(:drafts, %{})
     |> assign(:highlight_message_id, nil)
     |> assign(:show_search_modal, false)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:searching, false)
     |> assign(:search_error, nil)
     |> assign(:selected_search_room, nil)
     |> assign(:suggestions, [])
     |> assign(:show_suggestions, false)
     |> assign(:search_stats, nil)
     |> assign(:similarity_weight, 0.7)
     |> assign(:recency_weight, 0.3)
     |> assign(:expanded_reactions, MapSet.new())
     |> assign(:show_pin_modal, false)
     |> assign(:pinning_message, nil)
     |> assign(:pin_slug, "")
     |> assign(:pinned_messages, [])
     |> assign(:page_title, "Chat"), layout: {EmberchatWeb.Layouts, :chat}}
  end

  @impl true
  def handle_params(%{"room_id" => room_id} = params, _url, socket) do
    room = Room.get_room!(socket.assigns.current_scope, room_id)
    messages = Chat.list_room_messages(socket.assigns.current_scope, room.id)
    pinned_messages = Pinned.list_pinned_messages(socket.assigns.current_scope, room.id)
    highlight_message_id = params["highlight"]

    # Unsubscribe from previous room if any
    if connected?(socket) && socket.assigns.current_room do
      Phoenix.PubSub.unsubscribe(
        Emberchat.PubSub,
        "room:#{socket.assigns.current_room.id}:messages"
      )
    end

    # Subscribe to messages for this specific room
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Emberchat.PubSub, "room:#{room.id}:messages")

      # Subscribe to reactions for all messages in the room
      Enum.each(messages, fn message ->
        Chat.subscribe_reactions(message.id)
      end)
    end

    socket =
      socket
      |> assign(:current_room, room)
      |> assign(:messages, messages)
      |> assign(:pinned_messages, pinned_messages)
      |> assign(:new_message, %Message{room_id: room.id})
      |> assign(:replying_to, nil)
      |> assign(:highlight_message_id, highlight_message_id)
      |> assign(:page_title, room.name)

    # If we have a message to highlight, scroll to it after the page loads
    socket =
      if highlight_message_id do
        push_event(socket, "scroll_to_message", %{message_id: highlight_message_id})
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # Delegate message events to MessagesHelpers
  @impl true
  def handle_event("reply_to", params, socket),
    do: MessagesHelpers.handle_event("reply_to", params, socket)

  @impl true
  def handle_event("cancel_reply", params, socket),
    do: MessagesHelpers.handle_event("cancel_reply", params, socket)

  @impl true
  def handle_event("update_draft", params, socket),
    do: MessagesHelpers.handle_event("update_draft", params, socket)

  @impl true
  def handle_event("send_message", params, socket),
    do: MessagesHelpers.handle_event("send_message", params, socket)

  @impl true
  def handle_event("find_similar", params, socket),
    do: MessagesHelpers.handle_event("find_similar", params, socket)

  # Delegate navigation events to NavigationHelpers
  @impl true
  def handle_event("toggle_drawer", params, socket),
    do: NavigationHelpers.handle_event("toggle_drawer", params, socket)

  @impl true
  def handle_event("noop", params, socket),
    do: NavigationHelpers.handle_event("noop", params, socket)

  # Delegate room events to RoomHelpers
  @impl true
  def handle_event("show_new_room_modal", params, socket),
    do: RoomHelpers.handle_event("show_new_room_modal", params, socket)

  @impl true
  def handle_event("show_edit_room_modal", params, socket),
    do: RoomHelpers.handle_event("show_edit_room_modal", params, socket)

  @impl true
  def handle_event("close_room_modal", params, socket),
    do: RoomHelpers.handle_event("close_room_modal", params, socket)

  @impl true
  def handle_event("validate_room", params, socket),
    do: RoomHelpers.handle_event("validate_room", params, socket)

  @impl true
  def handle_event("select_emoji", params, socket),
    do: RoomHelpers.handle_event("select_emoji", params, socket)

  @impl true
  def handle_event("save_room", params, socket),
    do: RoomHelpers.handle_event("save_room", params, socket)

  # Delegate thread events to ThreadsHelpers
  @impl true
  def handle_event("show_thread", params, socket),
    do: ThreadsHelpers.handle_event("show_thread", params, socket)

  @impl true
  def handle_event("close_thread", params, socket),
    do: ThreadsHelpers.handle_event("close_thread", params, socket)

  @impl true
  def handle_event("update_thread_draft", params, socket),
    do: ThreadsHelpers.handle_event("update_thread_draft", params, socket)

  @impl true
  def handle_event("hide_thread", params, socket),
    do: ThreadsHelpers.handle_event("hide_thread", params, socket)

  @impl true
  def handle_event("send_thread_message", params, socket),
    do: ThreadsHelpers.handle_event("send_thread_message", params, socket)

  # Delegate search events to SearchHelpers
  @impl true
  def handle_event("show_search_modal", params, socket),
    do: SearchHelpers.handle_event("show_search_modal", params, socket)

  @impl true
  def handle_event("close_search_modal", params, socket),
    do: SearchHelpers.handle_event("close_search_modal", params, socket)

  @impl true
  def handle_event("search", params, socket),
    do: SearchHelpers.handle_event("search", params, socket)

  @impl true
  def handle_event("search_with_filters", params, socket),
    do: SearchHelpers.handle_event("search_with_filters", params, socket)

  @impl true
  def handle_event("get_search_suggestions", params, socket),
    do: SearchHelpers.handle_event("get_search_suggestions", params, socket)

  @impl true
  def handle_event("select_search_suggestion", params, socket),
    do: SearchHelpers.handle_event("select_search_suggestion", params, socket)

  @impl true
  def handle_event("clear_search", params, socket),
    do: SearchHelpers.handle_event("clear_search", params, socket)

  # Delegate keyboard shortcuts to NavigationHelpers
  @impl true
  def handle_event("keyboard_shortcut", params, socket),
    do: NavigationHelpers.handle_event("keyboard_shortcut", params, socket)

  # Delegate reaction events to ReactionsHelpers
  @impl true
  def handle_event("toggle_reaction", params, socket),
    do: ReactionsHelpers.handle_event("toggle_reaction", params, socket)

  @impl true
  def handle_event("toggle_show_all_reactions", params, socket),
    do: ReactionsHelpers.handle_event("toggle_show_all_reactions", params, socket)

  # Delegate pinning events to PinnedHelpers
  @impl true
  def handle_event("toggle_pin", params, socket),
    do: PinnedHelpers.handle_event("toggle_pin", params, socket)

  @impl true
  def handle_event("cancel_pin", params, socket),
    do: PinnedHelpers.handle_event("cancel_pin", params, socket)

  @impl true
  def handle_event("confirm_pin", params, socket),
    do: PinnedHelpers.handle_event("confirm_pin", params, socket)

  @impl true
  def handle_event("update_pin_slug", params, socket),
    do: PinnedHelpers.handle_event("update_pin_slug", params, socket)

  @impl true
  def handle_event("scroll_to_pinned", params, socket),
    do: PinnedHelpers.handle_event("scroll_to_pinned", params, socket)

  # Delegate search info messages to SearchHelpers
  @impl true
  def handle_info({:search_results_ready, results, stats}, socket),
    do: SearchHelpers.handle_info({:search_results_ready, results, stats}, socket)

  @impl true
  def handle_info({:similar_search_results_ready, results, original_message}, socket),
    do: SearchHelpers.handle_info({:similar_search_results_ready, results, original_message}, socket)

  @impl true
  def handle_info({:search_suggestions_ready, suggestions}, socket),
    do: SearchHelpers.handle_info({:search_suggestions_ready, suggestions}, socket)

  @impl true
  def handle_info({:search_error, error}, socket),
    do: SearchHelpers.handle_info({:search_error, error}, socket)

  @impl true
  def handle_info({:created, %Room{} = room}, socket) do
    # Check if room already exists to prevent duplicates
    room_exists = Enum.any?(socket.assigns.rooms, &(&1.id == room.id))

    if room_exists do
      {:noreply, socket}
    else
      {:noreply, update(socket, :rooms, &(&1 ++ [room]))}
    end
  end

  @impl true
  def handle_info({:updated, %Room{} = room}, socket) do
    rooms =
      Enum.map(socket.assigns.rooms, fn r ->
        if r.id == room.id, do: room, else: r
      end)

    current_room =
      if socket.assigns.current_room && socket.assigns.current_room.id == room.id do
        room
      else
        socket.assigns.current_room
      end

    {:noreply,
     socket
     |> assign(:rooms, rooms)
     |> assign(:current_room, current_room)}
  end

  @impl true
  def handle_info({:deleted, %Room{} = room}, socket) do
    rooms = Enum.reject(socket.assigns.rooms, &(&1.id == room.id))

    current_room =
      if socket.assigns.current_room && socket.assigns.current_room.id == room.id do
        nil
      else
        socket.assigns.current_room
      end

    {:noreply,
     socket
     |> assign(:rooms, rooms)
     |> assign(:current_room, current_room)}
  end

  # Delegate reaction info messages to ReactionsHelpers
  @impl true
  def handle_info({:reaction_added, %{message_id: message_id}}, socket),
    do: ReactionsHelpers.handle_info({:reaction_added, %{message_id: message_id}}, socket)

  @impl true
  def handle_info({:reaction_removed, %{message_id: message_id}}, socket),
    do: ReactionsHelpers.handle_info({:reaction_removed, %{message_id: message_id}}, socket)

  # Delegate message info messages to MessagesHelpers
  @impl true
  def handle_info({:created, %Message{} = message}, socket),
    do: MessagesHelpers.handle_info({:created, message}, socket)

  @impl true
  def handle_info({:updated, %Message{} = message}, socket),
    do: MessagesHelpers.handle_info({:updated, message}, socket)

  @impl true
  def handle_info({:deleted, %Message{} = message}, socket),
    do: MessagesHelpers.handle_info({:deleted, message}, socket)

  @impl true
  def handle_info(:clear_highlight, socket),
    do: MessagesHelpers.handle_info(:clear_highlight, socket)


  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen" phx-hook="KeyboardShortcuts" id="chat-container">
      <!-- Custom Sidebar -->
      <.chat_sidebar
        current_user={@current_scope.user}
        rooms={@rooms}
        current_room={@current_room}
        drawer_open={@drawer_open}
      />
      
    <!-- Main content area -->
      <div class="flex-1 flex flex-col h-full">
        <%= if @current_room do %>
          <!-- Chat header -->
          <.chat_header room={@current_room} current_user_id={@current_scope.user.id} />
          
    <!-- Messages container - takes remaining height -->
          <div
            class="flex-1 overflow-y-auto p-6 min-h-0"
            id="messages-container"
            phx-hook="MessageScroll"
            phx-click="hide_thread"
          >
            <!-- Pinned Messages Section -->
            <%= if @pinned_messages != [] do %>
              <div class="mb-4 px-2">
                <div class="flex items-center gap-2 text-xs text-base-content/60 mb-2">
                  <.icon name="hero-bookmark-solid" class="h-3 w-3" />
                  <span>Pinned</span>
                </div>
                <div class="flex gap-2 overflow-x-auto pb-2 scrollbar-thin">
                  <%= for pinned_message <- @pinned_messages do %>
                    <button
                      class="flex-shrink-0 px-3 py-1 bg-base-200 hover:bg-base-300 rounded-full text-xs font-medium border border-base-300 hover:border-primary/20 transition-colors cursor-pointer"
                      phx-click="scroll_to_pinned"
                      phx-value-message_id={pinned_message.id}
                    >
                      <%= if pinned_message.pin_slug do %>
                        #{pinned_message.pin_slug}
                      <% else %>
                        Pinned message
                      <% end %>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>

            <div class="space-y-4">
              <%= for message <- @messages do %>
                <.message_bubble
                  message={message}
                  highlighted={
                    @highlight_message_id && to_string(message.id) == @highlight_message_id
                  }
                  current_user_id={@current_scope.user.id}
                  show_all_reactions={MapSet.member?(@expanded_reactions, message.id)}
                />
              <% end %>
            </div>
          </div>
          
    <!-- Fixed input bar at bottom -->
          <div class="flex-shrink-0">
            <.message_input
              replying_to={@replying_to}
              room_id={@current_room.id}
              draft={Map.get(@drafts, @current_room.id, "")}
            />
          </div>
        <% else %>
          <.empty_chat_state />
        <% end %>
      </div>
      
    <!-- Room Form Modal -->
      <%= if @room_form do %>
        <.room_form_modal
          show={@show_room_modal}
          title={if @room_modal_mode == :new, do: "Create New Room", else: "Edit Room"}
          form={@room_form}
          selected_emoji={@selected_emoji}
          emoji_options={@emoji_options}
        />
      <% end %>
      
    <!-- Search Modal -->
      <.search_modal
        show={@show_search_modal}
        query={@search_query}
        search_results={@search_results}
        searching={@searching}
        search_error={@search_error}
        suggestions={@suggestions}
        show_suggestions={@show_suggestions}
        search_stats={@search_stats}
        rooms={@rooms}
        selected_room={@selected_search_room}
        similarity_weight={@similarity_weight}
        recency_weight={@recency_weight}
      />
      
    <!-- Pin Modal -->
      <%= if @show_pin_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Pin Message</h3>
            <p class="py-4">Enter a slug to easily identify this pinned message:</p>
            <form phx-submit="confirm_pin">
              <input
                type="text"
                name="slug"
                value={@pin_slug}
                phx-change="update_pin_slug"
                class="input input-bordered w-full"
                placeholder="e.g., important-announcement"
                pattern="[a-z0-9-]+"
                title="Only lowercase letters, numbers, and hyphens"
                required
              />
              <div class="modal-action">
                <button type="button" class="btn" phx-click="cancel_pin">Cancel</button>
                <button type="submit" class="btn btn-primary">Pin Message</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
      
    <!-- Thread View -->
      <.thread_view
        show={@show_thread}
        parent_message={@thread_parent_message}
        thread_messages={@thread_messages}
        room_id={@current_room && @current_room.id}
        parent_message_id={@thread_parent_message && @thread_parent_message.id}
        draft={
          if @thread_parent_message,
            do: Map.get(@drafts, "thread_#{@thread_parent_message.id}", ""),
            else: ""
        }
      />
    </div>
    """
  end
end
