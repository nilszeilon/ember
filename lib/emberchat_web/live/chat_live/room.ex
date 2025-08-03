defmodule EmberchatWeb.ChatLive.Room do
  use EmberchatWeb, :live_view
  import Phoenix.LiveView
  import Phoenix.Component

  alias Emberchat.Chat.Room
  alias Emberchat.Chat

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

  def handle_event("close_room_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_room_modal, false)
     |> assign(:room_form, nil)
     |> assign(:editing_room, nil)}
  end

  def handle_event("validate_room", %{"room" => room_params}, socket) do
    changeset =
      Chat.change_room(socket.assigns.current_scope, socket.assigns.editing_room, room_params)

    {:noreply, assign(socket, :room_form, to_form(changeset, action: :validate))}
  end

  def handle_event("select_emoji", %{"emoji" => emoji}, socket) do
    {:noreply, assign(socket, :selected_emoji, emoji)}
  end

  def handle_event("save_room", %{"room" => room_params}, socket) do
    room_params = Map.put(room_params, "emoji", socket.assigns.selected_emoji)
    save_room(socket, socket.assigns.room_modal_mode, room_params)
  end

  defp save_room(socket, :edit, room_params) do
    case Chat.update_room(socket.assigns.current_scope, socket.assigns.editing_room, room_params) do
      {:ok, _room} ->
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
         |> push_patch(to: ~p"/#{room}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :room_form, to_form(changeset))}
    end
  end
end

