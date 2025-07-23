defmodule EmberchatWeb.RoomLive.Index do
  use EmberchatWeb, :live_view

  alias Emberchat.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Rooms
        <:actions>
          <.button variant="primary" navigate={~p"/rooms/new"}>
            <.icon name="hero-plus" /> New Room
          </.button>
        </:actions>
      </.header>

      <.table
        id="rooms"
        rows={@streams.rooms}
        row_click={fn {_id, room} -> JS.navigate(~p"/rooms/#{room}") end}
      >
        <:col :let={{_id, room}} label="Name">{room.name}</:col>
        <:col :let={{_id, room}} label="Description">{room.description}</:col>
        <:col :let={{_id, room}} label="Is private">{room.is_private}</:col>
        <:action :let={{_id, room}}>
          <div class="sr-only">
            <.link navigate={~p"/rooms/#{room}"}>Show</.link>
          </div>
          <%= if room.user_id == @current_scope.user.id do %>
            <.link navigate={~p"/rooms/#{room}/edit"}>Edit</.link>
          <% end %>
        </:action>
        <:action :let={{id, room}}>
          <%= if room.user_id == @current_scope.user.id do %>
            <.link
              phx-click={JS.push("delete", value: %{room_id: room.id}) |> hide("##{id}")}
              data-confirm="Are you sure?"
            >
              Delete
            </.link>
          <% end %>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Chat.subscribe_rooms(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Rooms")
     |> stream(:rooms, Chat.list_rooms(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"room_id" => room_id}, socket) do
    room = Chat.get_room!(socket.assigns.current_scope, room_id)
    
    case Chat.delete_room(socket.assigns.current_scope, room) do
      {:ok, _} ->
        {:noreply, stream_delete(socket, :rooms, room)}
      
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You can only delete rooms you own.")}
    end
  rescue
    MatchError ->
      {:noreply, put_flash(socket, :error, "You can only delete rooms you own.")}
  end

  @impl true
  def handle_info({type, %Emberchat.Chat.Room{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :rooms, Chat.list_rooms(socket.assigns.current_scope), reset: true)}
  end
end
