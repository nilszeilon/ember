defmodule EmberchatWeb.RoomLive.Form do
  use EmberchatWeb, :live_view

  alias Emberchat.Chat
  alias Emberchat.Chat.Room

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage room records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="room-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="textarea" label="Description" />

        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">Room Emoji</label>
          <div class="flex items-center gap-4">
            <div class="avatar avatar-placeholder">
              <div class="bg-neutral text-neutral-content rounded-full w-16 h-16">
                <span class="text-3xl">{@selected_emoji}</span>
              </div>
            </div>
            <div class="flex flex-wrap gap-2">
              <%= for emoji <- @emoji_options do %>
                <button
                  type="button"
                  phx-click="select_emoji"
                  phx-value-emoji={emoji}
                  class={[
                    "btn btn-circle",
                    emoji == @selected_emoji && "btn-primary",
                    emoji != @selected_emoji && "btn-ghost"
                  ]}
                >
                  <span class="text-xl">{emoji}</span>
                </button>
              <% end %>
            </div>
          </div>
          <input type="hidden" name="room[emoji]" value={@selected_emoji} />
        </div>

        <.input field={@form[:is_private]} type="checkbox" label="Is private" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Room</.button>
          <.button navigate={return_path(@current_scope, @return_to, @room)}>Cancel</.button>
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
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"room_id" => room_id}) do
    room = Chat.get_room!(socket.assigns.current_scope, room_id)

    try do
      changeset = Chat.change_room(socket.assigns.current_scope, room)

      socket
      |> assign(:page_title, "Edit Room")
      |> assign(:room, room)
      |> assign(:selected_emoji, Map.get(room, :emoji, "💬"))
      |> assign(:form, to_form(changeset))
    rescue
      MatchError ->
        socket
        |> put_flash(:error, "You can only edit rooms you own.")
        |> push_navigate(to: ~p"/chat")
    end
  end

  defp apply_action(socket, :new, _params) do
    room = %Room{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Room")
    |> assign(:room, room)
    |> assign(:selected_emoji, "💬")
    |> assign(:form, to_form(Chat.change_room(socket.assigns.current_scope, room)))
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset = Chat.change_room(socket.assigns.current_scope, socket.assigns.room, room_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"room" => room_params}, socket) do
    save_room(socket, socket.assigns.live_action, room_params)
  end

  def handle_event("select_emoji", %{"emoji" => emoji}, socket) do
    {:noreply, assign(socket, :selected_emoji, emoji)}
  end

  defp save_room(socket, :edit, room_params) do
    case Chat.update_room(socket.assigns.current_scope, socket.assigns.room, room_params) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, room)
         )}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You can only edit rooms you own.")
         |> push_navigate(to: ~p"/chat")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_room(socket, :new, room_params) do
    case Chat.create_room(socket.assigns.current_scope, room_params) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, room)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _room), do: ~p"/chat"
  defp return_path(_scope, "show", room), do: ~p"/chat/#{room}"
end
