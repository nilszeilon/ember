defmodule EmberchatWeb.MessageLive.Show do
  use EmberchatWeb, :live_view

  alias Emberchat.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Message {@message.id}
        <:subtitle>This is a message record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/chat/#{@room}"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={~p"/rooms/#{@room}/messages/#{@message}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Edit message
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Content">{@message.content}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id, "room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      Chat.subscribe_messages(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Message")
     |> assign(:room, room_id)
     |> assign(:message, Chat.get_message!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %Emberchat.Chat.Message{id: id} = message},
        %{assigns: %{message: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :message, message)}
  end

  def handle_info(
        {:deleted, %Emberchat.Chat.Message{id: id}},
        %{assigns: %{message: %{id: id}}} = socket,
        room
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current message was deleted.")
     |> push_navigate(to: ~p"/chat/#{room}")}
  end

  def handle_info({type, %Emberchat.Chat.Message{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
