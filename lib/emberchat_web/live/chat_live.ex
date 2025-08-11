defmodule EmberchatWeb.ChatLive do
  use EmberchatWeb, :live_view
  import EmberchatWeb.ChatComponents

  alias Emberchat.Accounts
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

    rooms = Chat.list_rooms(socket.assigns.current_scope)

    # Get drawer state from process dictionary or default to false
    drawer_open = Process.get(:drawer_open, false)

    {:ok,
     socket
     |> assign(:rooms, rooms)
     |> assign(:current_room, nil)
     |> assign(:messages, [])
     |> assign(:new_message, %Message{})
     |> assign(:replying_to, nil)
     |> assign(:editing_message, nil)
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
     |> assign(:drafts, %{})
     |> assign(:highlight_message_id, nil)
     |> assign(:expanded_threads, MapSet.new())
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
     |> assign(:selected_message_index, -1)
     |> assign(:show_keyboard_shortcuts, false)
     |> assign(:pin_message_id, nil)
     |> assign(:page_title, "Chat"), layout: {EmberchatWeb.Layouts, :chat}}
  end

  @impl true
  def handle_params(%{"room_id" => room_id} = params, _url, socket) do
    room = Chat.get_room!(socket.assigns.current_scope, room_id)
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
    # Auto-select first room if no room is currently selected
    if socket.assigns.current_room == nil && socket.assigns.rooms != [] do
      first_room = List.first(socket.assigns.rooms)
      {:noreply, push_patch(socket, to: ~p"/#{first_room}")}
    else
      {:noreply, socket}
    end
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

  @impl true
  def handle_event("edit_message", params, socket),
    do: MessagesHelpers.handle_event("edit_message", params, socket)

  @impl true
  def handle_event("cancel_edit", params, socket),
    do: MessagesHelpers.handle_event("cancel_edit", params, socket)

  @impl true
  def handle_event("save_edit", params, socket),
    do: MessagesHelpers.handle_event("save_edit", params, socket)

  @impl true
  def handle_event("delete_message", params, socket),
    do: MessagesHelpers.handle_event("delete_message", params, socket)

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

  @impl true
  def handle_event("show_keyboard_shortcuts_modal", params, socket),
    do: NavigationHelpers.handle_event("show_keyboard_shortcuts_modal", params, socket)

  @impl true
  def handle_event("close_keyboard_shortcuts_modal", params, socket),
    do: NavigationHelpers.handle_event("close_keyboard_shortcuts_modal", params, socket)

  @impl true
  def handle_event("highlight_message", %{"message_id" => message_id}, socket) do
    {:noreply, assign(socket, :highlight_message_id, to_string(message_id))}
  end

  @impl true
  def handle_event("toggle_thread", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    expanded_threads = socket.assigns.expanded_threads
    
    new_expanded_threads = 
      if MapSet.member?(expanded_threads, message_id) do
        MapSet.delete(expanded_threads, message_id)
      else
        MapSet.put(expanded_threads, message_id)
      end
    
    {:noreply, assign(socket, :expanded_threads, new_expanded_threads)}
  end

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
    do:
      SearchHelpers.handle_info(
        {:similar_search_results_ready, results, original_message},
        socket
      )

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
    <div class="flex h-screen flex-col md:flex-row" phx-hook="KeyboardShortcuts" id="chat-container">
      <!-- Custom Sidebar - Hidden on mobile -->
      <div class="hidden md:block">
        <.chat_sidebar
          current_user={@current_scope.user}
          rooms={@rooms}
          current_room={@current_room}
          drawer_open={@drawer_open}
        />
      </div>
      
    <!-- Main content area -->
      <div class="flex-1 flex flex-col h-full min-h-0 overflow-hidden">
        <%= if @current_room do %>
          <!-- Chat header -->
          <.chat_header room={@current_room} current_user_id={@current_scope.user.id} pinned_messages={@pinned_messages} />
          
    <!-- Messages container - takes remaining height -->
          <div
            class="flex-1 overflow-y-auto p-4 md:p-6 min-h-0"
            id="messages-container"
            phx-hook="MessageScroll"
            {if @highlight_message_id, do: [{"data-highlight", @highlight_message_id}], else: []}
          >
            <div class="space-y-4">
              <%= for message <- @messages do %>
                <.message_bubble
                  message={message}
                  highlighted={
                    @highlight_message_id && to_string(message.id) == @highlight_message_id
                  }
                  current_user_id={@current_scope.user.id}
                  show_all_reactions={MapSet.member?(@expanded_reactions, message.id)}
                  thread_expanded={MapSet.member?(@expanded_threads, message.id)}
                  editing_message={@editing_message}
                />
              <% end %>
            </div>
          </div>
          
    <!-- Fixed input bar at bottom -->
          <div class="flex-shrink-0 sticky bottom-0 z-10">
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
      
      <!-- Mobile drawer overlay -->
      <%= if @drawer_open do %>
        <div class="md:hidden fixed inset-0 bg-black/50 z-40" phx-click="toggle_drawer"></div>
        <div class="md:hidden fixed left-0 top-0 h-full w-64 bg-base-200 z-50 shadow-xl overflow-y-auto">
          <!-- Mobile drawer header -->
          <div class="h-16 bg-base-300 shadow-sm flex items-center px-4 justify-between">
            <span class="text-xl font-bold">EmberChat</span>
            <button phx-click="toggle_drawer" class="btn btn-ghost btn-sm btn-circle">
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>
          
          <!-- Search button -->
          <div class="p-4">
            <button
              phx-click="show_search_modal"
              class="btn btn-block btn-primary"
            >
              <.icon name="hero-magnifying-glass" class="h-5 w-5" />
              Search Messages
            </button>
          </div>
          
          <!-- Room list -->
          <div class="px-4">
            <div class="divider text-xs">ROOMS</div>
            <div class="space-y-2">
              <%= for room <- @rooms do %>
                <.link
                  patch={~p"/#{room}"}
                  phx-click="toggle_drawer"
                  class={[
                    "block w-full p-3 rounded-lg transition-all duration-200 hover:bg-base-300 border flex items-center gap-3",
                    @current_room && @current_room.id == room.id && "bg-primary/10 border-primary/20",
                    !(@current_room && @current_room.id == room.id) && "border-transparent"
                  ]}
                >
                  <div class="avatar avatar-placeholder">
                    <div class={[
                      "rounded-full text-neutral-content border transition-all duration-200 flex items-center justify-center w-10 h-10",
                      @current_room && @current_room.id == room.id &&
                        "bg-primary text-primary-content border-primary-focus ring-2 ring-primary/30",
                      !(@current_room && @current_room.id == room.id) &&
                        "bg-base-300 border-base-content/10"
                    ]}>
                      <span class="text-lg">{Map.get(room, :emoji, "💬")}</span>
                    </div>
                  </div>
                  <span class="font-medium">{room.name}</span>
                </.link>
              <% end %>
            </div>
            
            <!-- New room button -->
            <div class="mt-4">
              <button
                phx-click="show_new_room_modal"
                class="block w-full p-3 rounded-lg transition-all duration-200 hover:bg-primary/20 border-2 border-dashed border-primary/40 hover:border-primary/60 flex items-center gap-3"
              >
                <div class="avatar avatar-placeholder">
                  <div class="rounded-full border-2 border-dashed border-primary/60 bg-primary/10 text-primary w-10 h-10 flex items-center justify-center">
                    <.icon name="hero-plus" class="h-5 w-5" />
                  </div>
                </div>
                <span class="font-medium text-primary">New Room</span>
              </button>
            </div>
          </div>
          
          <!-- Footer -->
          <div class="p-4 mt-auto">
            <%= if Emberchat.Accounts.anonymous_user?(@current_scope.user) do %>
              <div class="bg-warning/10 border border-warning/20 rounded-lg p-3 mb-3">
                <div class="flex items-center gap-2 text-warning">
                  <.icon name="hero-information-circle" class="h-5 w-5" />
                  <span class="font-medium">Demo Account</span>
                </div>
                <p class="text-sm text-base-content/70 mt-1">
                  You're using a temporary account.
                </p>
                <.link
                  navigate={~p"/users/register"}
                  class="btn btn-sm btn-warning mt-2 w-full"
                >
                  Complete Registration
                </.link>
              </div>
            <% end %>
            
            <div class="bg-base-100 rounded-lg p-2 flex gap-2">
              <.link
                navigate={~p"/users/settings"}
                class="flex-1 p-2 rounded-lg hover:bg-base-200 transition-colors duration-200 flex items-center justify-center"
              >
                <.icon name="hero-cog-6-tooth" class="h-5 w-5" />
                <span class="ml-2">Settings</span>
              </.link>
              <.link
                href={~p"/users/log-out"}
                method="delete"
                class="flex-1 p-2 rounded-lg hover:bg-base-200 transition-colors duration-200 flex items-center justify-center"
              >
                <.icon name="hero-arrow-left-on-rectangle" class="h-5 w-5" />
                <span class="ml-2">Log out</span>
              </.link>
            </div>
          </div>
        </div>
      <% end %>
      
      <!-- Keyboard Shortcuts Modal -->
      <.keyboard_shortcuts_modal show_keyboard_shortcuts={@show_keyboard_shortcuts} />
      
    </div>
    """
  end
end
