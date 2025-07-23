defmodule EmberchatWeb.ChatLive do
  use EmberchatWeb, :live_view
  import EmberchatWeb.ChatComponents

  alias Emberchat.Chat
  alias Emberchat.Chat.Message
  alias Emberchat.Chat.Room

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Chat.subscribe_rooms(socket.assigns.current_scope)
      Chat.subscribe_messages(socket.assigns.current_scope)
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
     |> assign(:drawer_open, drawer_open)
     |> assign(:show_room_modal, false)
     |> assign(:room_modal_mode, :new)
     |> assign(:room_form, nil)
     |> assign(:editing_room, nil)
     |> assign(:selected_emoji, "💬")
     |> assign(:emoji_options, [
       "💬", "🔥", "✨", "🎉", "🚀", "💡", "🎯", "🏆", "🌟", "💼", "🎨", "🎮", "🎵", "📚", "🍕", "☕"
     ])
     |> assign(:page_title, "Chat"), layout: {EmberchatWeb.Layouts, :chat}}
  end

  @impl true
  def handle_params(%{"room_id" => room_id}, _url, socket) do
    room = Chat.get_room!(socket.assigns.current_scope, room_id)
    messages = Chat.list_room_messages(socket.assigns.current_scope, room.id)

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
    end

    {:noreply,
     socket
     |> assign(:current_room, room)
     |> assign(:messages, messages)
     |> assign(:new_message, %Message{room_id: room.id})
     |> assign(:replying_to, nil)
     |> assign(:page_title, room.name)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("reply_to", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    replying_to = Enum.find(socket.assigns.messages, &(&1.id == message_id))

    {:noreply, assign(socket, :replying_to, replying_to)}
  end

  @impl true
  def handle_event("cancel_reply", _params, socket) do
    {:noreply, assign(socket, :replying_to, nil)}
  end

  @impl true
  def handle_event("toggle_drawer", _params, socket) do
    new_drawer_state = !socket.assigns.drawer_open
    
    # Store drawer state in process dictionary for persistence across navigation
    Process.put(:drawer_open, new_drawer_state)
    
    {:noreply, assign(socket, :drawer_open, new_drawer_state)}
  end

  @impl true
  def handle_event("show_new_room_modal", _params, socket) do
    room = %Room{user_id: socket.assigns.current_scope.user.id}
    changeset = Chat.change_room(socket.assigns.current_scope, room)

    {:noreply,
     socket
     |> assign(:show_room_modal, true)
     |> assign(:room_modal_mode, :new)
     |> assign(:editing_room, room)
     |> assign(:selected_emoji, "💬")
     |> assign(:room_form, to_form(changeset))}
  end

  @impl true
  def handle_event("show_edit_room_modal", %{"room_id" => room_id}, socket) do
    room = Chat.get_room!(socket.assigns.current_scope, room_id)

    try do
      changeset = Chat.change_room(socket.assigns.current_scope, room)

      {:noreply,
       socket
       |> assign(:show_room_modal, true)
       |> assign(:room_modal_mode, :edit)
       |> assign(:editing_room, room)
       |> assign(:selected_emoji, Map.get(room, :emoji, "💬"))
       |> assign(:room_form, to_form(changeset))}
    rescue
      MatchError ->
        {:noreply,
         socket
         |> put_flash(:error, "You can only edit rooms you own.")}
    end
  end

  @impl true
  def handle_event("close_room_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_room_modal, false)
     |> assign(:room_form, nil)
     |> assign(:editing_room, nil)}
  end

  @impl true
  def handle_event("validate_room", %{"room" => room_params}, socket) do
    changeset = Chat.change_room(socket.assigns.current_scope, socket.assigns.editing_room, room_params)
    {:noreply, assign(socket, :room_form, to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("select_emoji", %{"emoji" => emoji}, socket) do
    {:noreply, assign(socket, :selected_emoji, emoji)}
  end

  @impl true
  def handle_event("save_room", %{"room" => room_params}, socket) do
    # Add selected emoji to room params
    room_params = Map.put(room_params, "emoji", socket.assigns.selected_emoji)
    save_room(socket, socket.assigns.room_modal_mode, room_params)
  end

  @impl true
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
        {:noreply,
         socket
         |> assign(:new_message, %Message{room_id: socket.assigns.current_room.id})
         |> assign(:replying_to, nil)
         |> put_flash(:info, "Message sent successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :new_message, changeset)}
    end
  end

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

  @impl true
  def handle_info({:created, %Message{} = message}, socket) do
    if socket.assigns.current_room && message.room_id == socket.assigns.current_room.id do
      {:noreply, update(socket, :messages, &(&1 ++ [message]))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:updated, %Message{} = message}, socket) do
    if socket.assigns.current_room && message.room_id == socket.assigns.current_room.id do
      messages =
        Enum.map(socket.assigns.messages, fn m ->
          if m.id == message.id, do: message, else: m
        end)

      {:noreply, assign(socket, :messages, messages)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:deleted, %Message{} = message}, socket) do
    if socket.assigns.current_room && message.room_id == socket.assigns.current_room.id do
      messages = Enum.reject(socket.assigns.messages, &(&1.id == message.id))
      {:noreply, assign(socket, :messages, messages)}
    else
      {:noreply, socket}
    end
  end

  defp save_room(socket, :edit, room_params) do
    case Chat.update_room(socket.assigns.current_scope, socket.assigns.editing_room, room_params) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room updated successfully")
         |> assign(:show_room_modal, false)
         |> assign(:room_form, nil)
         |> assign(:editing_room, nil)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You can only edit rooms you own.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :room_form, to_form(changeset))}
    end
  end

  defp save_room(socket, :new, room_params) do
    case Chat.create_room(socket.assigns.current_scope, room_params) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room created successfully")
         |> assign(:show_room_modal, false)
         |> assign(:room_form, nil)
         |> assign(:editing_room, nil)
         |> push_patch(to: ~p"/chat/#{room}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :room_form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen">
      <!-- Custom Sidebar -->
      <.chat_sidebar 
        current_user={@current_scope.user} 
        rooms={@rooms} 
        current_room={@current_room}
        drawer_open={@drawer_open}
      />
      
      <!-- Main content area -->
      <div class="flex-1 flex flex-col">
        
        <!-- Chat content -->
        <div class="flex-1 flex flex-col">
          <%= if @current_room do %>
            <.chat_header 
              room={@current_room} 
              current_user_id={@current_scope.user.id} 
            />
            
            <div class="flex-1 overflow-y-auto p-6" id="messages-container" phx-hook="ScrollToBottom">
              <div class="space-y-4">
                <%= for message <- @messages do %>
                  <.message_bubble message={message} />
                <% end %>
              </div>
            </div>
            
            <.message_input 
              replying_to={@replying_to} 
              room_id={@current_room.id} 
            />
          <% else %>
            <.empty_chat_state />
          <% end %>
        </div>
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
    </div>
    """
  end
end
