defmodule EmberchatWeb.RoomLive.Show do
  use EmberchatWeb, :live_view

  alias Emberchat.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Room {@room.id}
        <:subtitle>This is a room record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <%= if @room.user_id == @current_scope.user.id do %>
            <.button variant="primary" navigate={~p"/rooms/#{@room}/edit?return_to=show"}>
              <.icon name="hero-pencil-square" /> Edit room
            </.button>
          <% end %>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@room.name}</:item>
        <:item title="Description">{@room.description}</:item>
        <:item title="Is private">{@room.is_private}</:item>
      </.list>

      <div class="mt-8">
        <h3 class="text-lg font-semibold">Messages</h3>
        <div class="space-y-2 mt-4">
          <%= for message <- @messages do %>
            <div class="p-3 bg-gray-50 rounded">
              <p>{message.content}</p>
              <small class="text-gray-500">by User {message.user_id}</small>
            </div>
          <% end %>
        </div>
        <.button navigate={~p"/rooms/#{@room.id}/messages/new"} class="mt-4">
          New Message
        </.button>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      Chat.subscribe_rooms(socket.assigns.current_scope)
      Chat.subscribe_messages(socket.assigns.current_scope)
    end

    room = Chat.get_room!(socket.assigns.current_scope, room_id)
    messages = Chat.list_room_messages(socket.assigns.current_scope, room_id)

    {:ok,
     socket
     |> assign(:page_title, "Show Room")
     |> assign(:room, room)
     |> assign(:messages, messages)}
  end

  @impl true
  def handle_info(
        {:updated, %Emberchat.Chat.Room{id: room_id} = room},
        %{assigns: %{room: %{id: room_id}}} = socket
      ) do
    {:noreply, assign(socket, :room, room)}
  end

  def handle_info(
        {:deleted, %Emberchat.Chat.Room{id: room_id}},
        %{assigns: %{room: %{id: room_id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current room was deleted.")
     |> push_navigate(to: ~p"/")}
  end

  def handle_info({type, %Emberchat.Chat.Room{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
