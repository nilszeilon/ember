defmodule EmberchatWeb.MessageLive.Form do
  use EmberchatWeb, :live_view

  alias Emberchat.Chat
  alias Emberchat.Chat.Message

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage message records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="message-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:content]} type="textarea" label="Content" />
        <.input field={@form[:room_id]} type="hidden" value={@room} />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Message</.button>
          <.button navigate={return_path(@current_scope, @return_to, @room, @message)}>
            Cancel
          </.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(:room, params["room_id"])
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    message = Chat.get_message!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Message")
    |> assign(:message, message)
    |> assign(:form, to_form(Chat.change_message(socket.assigns.current_scope, message)))
  end

  defp apply_action(socket, :new, _params) do
    message = %Message{
      user_id: socket.assigns.current_scope.user.id,
      room_id: socket.assigns.room
    }

    socket
    |> assign(:page_title, "New Message")
    |> assign(:message, message)
    |> assign(:form, to_form(Chat.change_message(socket.assigns.current_scope, message)))
  end

  @impl true
  def handle_event("validate", %{"message" => message_params}, socket) do
    message_params = Map.put(message_params, "room_id", socket.assigns.room)

    changeset =
      Chat.change_message(socket.assigns.current_scope, socket.assigns.message, message_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"message" => message_params}, socket) do
    save_message(socket, socket.assigns.live_action, message_params)
  end

  defp save_message(socket, :edit, message_params) do
    case Chat.update_message(socket.assigns.current_scope, socket.assigns.message, message_params) do
      {:ok, message} ->
        {:noreply,
         socket
         |> put_flash(:info, "Message updated successfully")
         |> push_navigate(
           to:
             return_path(
               socket.assigns.current_scope,
               socket.assigns.return_to,
               socket.assigns.room,
               message
             )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_message(socket, :new, message_params) do
    case Chat.create_message(socket.assigns.current_scope, message_params) do
      {:ok, message} ->
        {:noreply,
         socket
         |> put_flash(:info, "Message created successfully")
         |> push_navigate(
           to:
             return_path(
               socket.assigns.current_scope,
               socket.assigns.return_to,
               socket.assigns.room,
               message
             )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", room, _message),
    do: ~p"/chat/#{room}"

  defp return_path(_scope, "show", room, message), do: ~p"/chat/#{room}/messages/#{message}"
end
