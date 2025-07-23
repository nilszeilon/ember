defmodule EmberchatWeb.MessageLive.Index do
  use EmberchatWeb, :live_view

  alias Emberchat.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Messages
        <:actions>
          <.button variant="primary" navigate={~p"/rooms/#{@room}/messages/new"}>
            <.icon name="hero-plus" /> New Message
          </.button>
        </:actions>
      </.header>

      <.table
        id="messages"
        rows={@streams.messages}
        row_click={fn {_id, message} -> JS.navigate(~p"/rooms/#{@room}/messages/#{message}") end}
      >
        <:col :let={{_id, message}} label="Content">{message.content}</:col>
        <:action :let={{_id, message}}>
          <div class="sr-only">
            <.link navigate={~p"/rooms/#{@room}/messages/#{message}"}>Show</.link>
          </div>
          <.link navigate={~p"/rooms/#{@room}/messages/#{message}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, message}}>
          <.link
            phx-click={JS.push("delete", value: %{id: message.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      Chat.subscribe_messages(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Messages")
     |> assign(:room, params["room_id"])
     |> stream(:messages, Chat.list_messages(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    message = Chat.get_message!(socket.assigns.current_scope, id)
    {:ok, _} = Chat.delete_message(socket.assigns.current_scope, message)

    {:noreply, stream_delete(socket, :messages, message)}
  end

  @impl true
  def handle_info({type, %Emberchat.Chat.Message{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(socket, :messages, Chat.list_messages(socket.assigns.current_scope), reset: true)}
  end
end
