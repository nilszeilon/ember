defmodule EmberchatWeb.ChatLive.Search do
  import Phoenix.Component, only: [assign: 3]
  
  alias Emberchat.Chat

  def handle_event("show_search_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_search_modal, true)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:searching, false)
     |> assign(:search_error, nil)
     |> assign(:show_suggestions, false)
     |> assign(:search_stats, nil)}
  end

  def handle_event("close_search_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_search_modal, false)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:searching, false)
     |> assign(:search_error, nil)
     |> assign(:show_suggestions, false)
     |> assign(:search_stats, nil)}
  end

  def handle_event("search", %{"query" => query}, socket) when byte_size(query) < 2 do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, [])
     |> assign(:searching, false)
     |> assign(:search_error, nil)
     |> assign(:show_suggestions, false)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:searching, true)
     |> assign(:search_error, nil)
     |> assign(:show_suggestions, false)
     |> start_search()}
  end

  def handle_event("search_with_filters", params, socket) do
    query = params["query"] || socket.assigns.search_query

    room_id =
      case params["room_id"] do
        "" -> nil
        room_id -> String.to_integer(room_id)
      end

    similarity_weight = String.to_float(params["similarity_weight"] || "0.7")
    recency_weight = String.to_float(params["recency_weight"] || "0.3")

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:selected_search_room, room_id)
     |> assign(:similarity_weight, similarity_weight)
     |> assign(:recency_weight, recency_weight)
     |> assign(:searching, true)
     |> assign(:search_error, nil)
     |> start_search()}
  end

  def handle_event("get_search_suggestions", %{"key" => "Enter", "value" => query}, socket)
      when byte_size(query) >= 2 do
    # When Enter is pressed, trigger search instead of suggestions
    handle_event("search", %{"query" => query}, socket)
  end

  def handle_event("get_search_suggestions", %{"value" => partial_query}, socket)
      when byte_size(partial_query) >= 2 do
    Task.start(fn ->
      case Chat.get_search_suggestions(partial_query, socket.assigns.current_scope,
             room_id: socket.assigns.selected_search_room
           ) do
        {:ok, suggestions} ->
          send(self(), {:search_suggestions_ready, suggestions})

        {:error, _reason} ->
          send(self(), {:search_suggestions_ready, []})
      end
    end)

    {:noreply, assign(socket, :show_suggestions, true)}
  end

  def handle_event("get_search_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  def handle_event("select_search_suggestion", %{"suggestion" => suggestion}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, suggestion)
     |> assign(:show_suggestions, false)
     |> assign(:searching, true)
     |> assign(:search_error, nil)
     |> start_search()}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:searching, false)
     |> assign(:search_error, nil)
     |> assign(:show_suggestions, false)
     |> assign(:search_stats, nil)}
  end

  def handle_info({:search_results_ready, results, stats}, socket) do
    {:noreply,
     socket
     |> assign(:search_results, results)
     |> assign(:search_stats, stats)
     |> assign(:searching, false)}
  end

  def handle_info({:similar_search_results_ready, results, original_message}, socket) do
    stats = %{
      total_results: length(results),
      search_type: "similar_to",
      original_message: original_message
    }

    {:noreply,
     socket
     |> assign(:search_results, results)
     |> assign(:search_stats, stats)
     |> assign(:searching, false)}
  end

  def handle_info({:search_suggestions_ready, suggestions}, socket) do
    {:noreply, assign(socket, :suggestions, suggestions)}
  end

  def handle_info({:search_error, error}, socket) do
    {:noreply,
     socket
     |> assign(:search_error, error)
     |> assign(:searching, false)}
  end

  defp start_search(socket) do
    query = socket.assigns.search_query
    scope = socket.assigns.current_scope
    room_id = socket.assigns.selected_search_room
    similarity_weight = socket.assigns.similarity_weight
    recency_weight = socket.assigns.recency_weight

    parent = self()

    Task.start(fn ->
      start_time = System.monotonic_time(:millisecond)

      case Chat.search_messages(query, scope,
             room_id: room_id,
             limit: 20,
             similarity_weight: similarity_weight,
             recency_weight: recency_weight
           ) do
        {:ok, results} ->
          end_time = System.monotonic_time(:millisecond)
          search_time = end_time - start_time

          stats = %{
            total_results: length(results),
            search_time_ms: search_time,
            search_type: "semantic",
            query: query,
            room_filter: room_id,
            similarity_weight: similarity_weight,
            recency_weight: recency_weight
          }

          send(parent, {:search_results_ready, results, stats})

        {:error, reason} ->
          send(parent, {:search_error, "Search failed: #{inspect(reason)}"})
      end
    end)

    socket
  end
end