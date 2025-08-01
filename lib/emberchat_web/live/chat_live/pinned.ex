defmodule EmberchatWeb.ChatLive.Pinned do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3]
  
  alias Emberchat.Chat.Pinned
  def handle_event("toggle_pin", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    message = Enum.find(socket.assigns.messages, &(&1.id == message_id))
    
    if message do
      # If unpinning, just toggle it. If pinning, show the modal
      if message.is_pinned do
        case Pinned.toggle_pin_message(socket.assigns.current_scope, message) do
          {:ok, _updated_message} ->
            {:noreply, socket}
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to unpin message")}
        end
      else
        # Show modal to get slug
        {:noreply, 
         socket
         |> assign(:show_pin_modal, true)
         |> assign(:pinning_message, message)
         |> assign(:pin_slug, "")}
      end
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("cancel_pin", _params, socket) do
    {:noreply, 
     socket
     |> assign(:show_pin_modal, false)
     |> assign(:pinning_message, nil)
     |> assign(:pin_slug, "")}
  end
  
  def handle_event("confirm_pin", %{"slug" => slug}, socket) do
    if socket.assigns.pinning_message do
      case Pinned.toggle_pin_message(socket.assigns.current_scope, socket.assigns.pinning_message, slug) do
        {:ok, _updated_message} ->
          {:noreply, 
           socket
           |> assign(:show_pin_modal, false)
           |> assign(:pinning_message, nil)
           |> assign(:pin_slug, "")}
        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, format_errors(changeset))}
      end
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("update_pin_slug", %{"slug" => slug}, socket) do
    {:noreply, assign(socket, :pin_slug, slug)}
  end

  def handle_event("scroll_to_pinned", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    
    socket = 
      socket
      |> assign(:highlight_message_id, to_string(message_id))
      |> push_event("scroll_to_message", %{message_id: message_id})
    
    # Clear highlight after 3 seconds
    Process.send_after(self(), :clear_highlight, 3000)
    
    {:noreply, socket}
  end

  def handle_info(:clear_highlight, socket) do
    {:noreply, assign(socket, :highlight_message_id, nil)}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k} #{Enum.join(v, ", ")}" end)
    |> Enum.join(", ")
  end
end
