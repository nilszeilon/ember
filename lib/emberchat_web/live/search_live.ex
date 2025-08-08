defmodule EmberchatWeb.SearchLive do
  use EmberchatWeb, :live_view

  alias Emberchat.Chat
  alias Emberchat.Chat.Message

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Chat.subscribe_search(socket.assigns.current_scope)
    end

    rooms = Chat.list_rooms(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:rooms, rooms)
     |> assign(:query, "")
     |> assign(:search_results, [])
     |> assign(:searching, false)
     |> assign(:search_error, nil)
     |> assign(:selected_room, nil)
     |> assign(:suggestions, [])
     |> assign(:show_suggestions, false)
     |> assign(:search_stats, nil)
     |> assign(:similarity_weight, 0.7)
     |> assign(:recency_weight, 0.3)
     |> assign(:search_mode, :fts)
     |> assign(:semantic_results, [])
     |> assign(:semantic_loading, false)
     |> assign(:page_title, "Search Messages"), layout: {EmberchatWeb.Layouts, :chat}}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) when byte_size(query) < 2 do
    {:noreply, 
     socket
     |> assign(:query, query)
     |> assign(:search_results, [])
     |> assign(:searching, false)
     |> assign(:search_error, nil)
     |> assign(:show_suggestions, false)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:searching, true)
     |> assign(:search_error, nil)
     |> assign(:show_suggestions, false)
     |> start_search()}
  end

  @impl true
  def handle_event("search_with_filters", params, socket) do
    query = params["query"] || socket.assigns.query
    room_id = case params["room_id"] do
      "" -> nil
      room_id -> String.to_integer(room_id)
    end
    
    search_mode = String.to_existing_atom(params["search_mode"] || "fts")
    similarity_weight = String.to_float(params["similarity_weight"] || "0.7")
    recency_weight = String.to_float(params["recency_weight"] || "0.3")

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:selected_room, room_id)
     |> assign(:search_mode, search_mode)
     |> assign(:similarity_weight, similarity_weight)
     |> assign(:recency_weight, recency_weight)
     |> assign(:searching, true)
     |> assign(:search_error, nil)
     |> start_search()}
  end

  @impl true
  def handle_event("get_suggestions", %{"key" => "Enter", "value" => query}, socket) when byte_size(query) >= 2 do
    # When Enter is pressed, trigger search instead of suggestions
    handle_event("search", %{"query" => query}, socket)
  end

  def handle_event("get_suggestions", %{"value" => partial_query}, socket) when byte_size(partial_query) >= 2 do
    Task.start(fn ->
      case Chat.get_search_suggestions(partial_query, socket.assigns.current_scope, 
                                       room_id: socket.assigns.selected_room) do
        {:ok, suggestions} ->
          send(self(), {:suggestions_ready, suggestions})
        {:error, _reason} ->
          send(self(), {:suggestions_ready, []})
      end
    end)

    {:noreply, assign(socket, :show_suggestions, true)}
  end

  @impl true
  def handle_event("get_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  @impl true
  def handle_event("select_suggestion", %{"suggestion" => suggestion}, socket) do
    {:noreply,
     socket
     |> assign(:query, suggestion)
     |> assign(:show_suggestions, false)
     |> assign(:searching, true)
     |> assign(:search_error, nil)
     |> start_search()}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:query, "")
     |> assign(:search_results, [])
     |> assign(:searching, false)
     |> assign(:search_error, nil)
     |> assign(:show_suggestions, false)
     |> assign(:search_stats, nil)}
  end

  @impl true
  def handle_event("find_similar", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    
    Task.start(fn ->
      # Get the message first
      case Emberchat.Repo.get(Message, message_id) do
        nil -> 
          send(self(), {:search_error, "Message not found"})
        message ->
          case Chat.find_similar_messages(message, limit: 10, room_id: socket.assigns.selected_room) do
            {:ok, similar_messages} ->
              send(self(), {:similar_results_ready, similar_messages, message})
            {:error, reason} ->
              send(self(), {:search_error, "Failed to find similar messages: #{inspect(reason)}"})
          end
      end
    end)

    {:noreply, assign(socket, :searching, true)}
  end

  @impl true
  def handle_info({:search_results_ready, results, stats}, socket) do
    {:noreply,
     socket
     |> assign(:search_results, results)
     |> assign(:search_stats, stats)
     |> assign(:searching, false)}
  end

  @impl true
  def handle_info({:fts_results_ready, results, stats}, socket) do
    {:noreply,
     socket
     |> assign(:search_results, results)
     |> assign(:search_stats, stats)
     |> assign(:searching, false)
     |> assign(:semantic_loading, true)}
  end

  @impl true
  def handle_info({:semantic_results_ready, semantic_results}, socket) do
    # Merge FTS and semantic results
    merged_results = Emberchat.Chat.ChatSearch.merge_search_results(
      socket.assigns.search_results,
      semantic_results
    )
    
    {:noreply,
     socket
     |> assign(:search_results, merged_results)
     |> assign(:semantic_results, semantic_results)
     |> assign(:semantic_loading, false)
     |> update(:search_stats, fn stats ->
       Map.put(stats, :search_type, "hybrid")
     end)}
  end

  @impl true
  def handle_info({:similar_results_ready, results, original_message}, socket) do
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

  @impl true
  def handle_info({:suggestions_ready, suggestions}, socket) do
    {:noreply, assign(socket, :suggestions, suggestions)}
  end

  @impl true
  def handle_info({:search_error, error}, socket) do
    {:noreply,
     socket
     |> assign(:search_error, error)
     |> assign(:searching, false)}
  end

  defp start_search(socket) do
    query = socket.assigns.query
    scope = socket.assigns.current_scope
    room_id = socket.assigns.selected_room
    search_mode = socket.assigns.search_mode
    similarity_weight = socket.assigns.similarity_weight
    recency_weight = socket.assigns.recency_weight

    parent = self()
    Task.start(fn ->
      start_time = System.monotonic_time(:millisecond)
      
      case Chat.search_messages(query, scope, 
                               mode: search_mode,
                               room_id: room_id, 
                               limit: 20,
                               similarity_weight: similarity_weight,
                               recency_weight: recency_weight) do
        {:ok, results} ->
          end_time = System.monotonic_time(:millisecond)
          search_time = end_time - start_time
          
          stats = %{
            total_results: length(results),
            search_time_ms: search_time,
            search_type: to_string(search_mode),
            query: query,
            room_filter: room_id,
            similarity_weight: similarity_weight,
            recency_weight: recency_weight
          }
          
          send(parent, {:search_results_ready, results, stats})
          
        {:ok, results, :semantic_pending} ->
          # Hybrid mode - FTS results ready, semantic loading
          end_time = System.monotonic_time(:millisecond)
          search_time = end_time - start_time
          
          stats = %{
            total_results: length(results),
            search_time_ms: search_time,
            search_type: "fts",
            query: query,
            room_filter: room_id
          }
          
          send(parent, {:fts_results_ready, results, stats})
          
          # Start semantic search in background
          Task.start(fn ->
            case Chat.search_messages_semantic(query, scope,
                                     room_id: room_id,
                                     limit: 20,
                                     similarity_weight: similarity_weight,
                                     recency_weight: recency_weight) do
              {:ok, semantic_results} ->
                send(parent, {:semantic_results_ready, semantic_results})
              {:error, _reason} ->
                # Silently fail, we already have FTS results
                :ok
            end
          end)
          
        {:error, reason} ->
          send(parent, {:search_error, "Search failed: #{inspect(reason)}"})
      end
    end)

    socket
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <!-- Search Header -->
      <div class="bg-white border-b border-gray-200 p-4">
        <div class="max-w-4xl mx-auto">
          <h1 class="text-2xl font-bold text-gray-900 mb-4">Search Messages</h1>
          
          <!-- Search Form -->
          <form phx-submit="search" class="space-y-4">
            <div class="relative">
              <input
                type="text"
                name="query"
                value={@query}
                placeholder="Search for messages using natural language..."
                phx-keyup="get_suggestions"
                phx-debounce="300"
                class="w-full px-4 py-3 text-lg border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                autofocus
              />
              
              <!-- Search/Clear Buttons -->
              <div class="absolute right-2 top-2 flex space-x-2">
                <%= if @query != "" do %>
                  <button
                    type="button"
                    phx-click="clear_search"
                    class="px-3 py-1 text-sm text-gray-500 hover:text-gray-700"
                  >
                    Clear
                  </button>
                <% end %>
                
                <button
                  type="submit"
                  disabled={@searching or String.length(@query) < 2}
                  class="px-4 py-1 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <%= if @searching do %>
                    <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                  <% else %>
                    Search
                  <% end %>
                </button>
              </div>
              
              <!-- Suggestions Dropdown -->
              <%= if @show_suggestions and length(@suggestions) > 0 do %>
                <div class="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg">
                  <%= for suggestion <- @suggestions do %>
                    <button
                      type="button"
                      phx-click="select_suggestion"
                      phx-value-suggestion={suggestion}
                      class="w-full px-4 py-2 text-left hover:bg-gray-100 first:rounded-t-lg last:rounded-b-lg"
                    >
                      <%= suggestion %>
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>

            <!-- Search Filters -->
            <details class="text-sm">
              <summary class="cursor-pointer text-gray-600 hover:text-gray-800">
                Advanced Options
              </summary>
              <div class="mt-3 p-4 bg-gray-50 rounded-lg space-y-3">
                <!-- Search Mode Selector -->
                <div class="mb-4">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Search Mode
                  </label>
                  <div class="grid grid-cols-3 gap-2">
                    <label class={"cursor-pointer rounded-lg border-2 p-3 text-center transition-all " <> 
                                  if @search_mode == :fts, do: "border-blue-500 bg-blue-50", else: "border-gray-200 hover:border-gray-300"}>
                      <input type="radio" name="search_mode" value="fts" class="sr-only" checked={@search_mode == :fts} />
                      <div class="font-medium">Quick Search</div>
                      <div class="text-xs text-gray-600 mt-1">Instant results</div>
                    </label>
                    
                    <label class={"cursor-pointer rounded-lg border-2 p-3 text-center transition-all " <> 
                                  if @search_mode == :hybrid, do: "border-blue-500 bg-blue-50", else: "border-gray-200 hover:border-gray-300"}>
                      <input type="radio" name="search_mode" value="hybrid" class="sr-only" checked={@search_mode == :hybrid} />
                      <div class="font-medium">Smart Search</div>
                      <div class="text-xs text-gray-600 mt-1">Best of both</div>
                    </label>
                    
                    <label class={"cursor-pointer rounded-lg border-2 p-3 text-center transition-all " <> 
                                  if @search_mode == :semantic, do: "border-blue-500 bg-blue-50", else: "border-gray-200 hover:border-gray-300"}>
                      <input type="radio" name="search_mode" value="semantic" class="sr-only" checked={@search_mode == :semantic} />
                      <div class="font-medium">Deep Search</div>
                      <div class="text-xs text-gray-600 mt-1">AI-powered</div>
                    </label>
                  </div>
                </div>
                
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <!-- Room Filter -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Filter by Room
                    </label>
                    <select name="room_id" class="w-full px-3 py-2 border border-gray-300 rounded-md">
                      <option value="">All Rooms</option>
                      <%= for room <- @rooms do %>
                        <option value={room.id} selected={@selected_room == room.id}>
                          <%= room.emoji %> <%= room.name %>
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <!-- Similarity Weight -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Similarity Weight: <%= @similarity_weight %>
                    </label>
                    <input
                      type="range"
                      name="similarity_weight"
                      min="0.1"
                      max="1.0"
                      step="0.1"
                      value={@similarity_weight}
                      class="w-full"
                    />
                  </div>

                  <!-- Recency Weight -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Recency Weight: <%= @recency_weight %>
                    </label>
                    <input
                      type="range"
                      name="recency_weight"
                      min="0.1"
                      max="1.0"
                      step="0.1"
                      value={@recency_weight}
                      class="w-full"
                    />
                  </div>
                </div>

                <button
                  type="button"
                  phx-click="search_with_filters"
                  phx-value-query={@query}
                  phx-value-room_id={@selected_room}
                  phx-value-search_mode={@search_mode}
                  phx-value-similarity_weight={@similarity_weight}
                  phx-value-recency_weight={@recency_weight}
                  class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700"
                >
                  Apply Filters
                </button>
              </div>
            </details>
          </form>
        </div>
      </div>

      <!-- Search Results -->
      <div class="flex-1 overflow-auto">
        <div class="max-w-4xl mx-auto p-4">
          <!-- Search Stats -->
          <%= if @search_stats do %>
            <div class="mb-4 text-sm text-gray-600">
              <%= cond do %>
                <% @search_stats.search_type == "fts" -> %>
                  Found <%= @search_stats.total_results %> messages for "<%= @search_stats.query %>" 
                  in <%= @search_stats.search_time_ms %>ms (Quick Search)
                  <%= if @semantic_loading do %>
                    <span class="ml-2 text-blue-600">
                      <svg class="inline animate-spin h-3 w-3" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      Enhancing with AI...
                    </span>
                  <% end %>
                <% @search_stats.search_type == "semantic" -> %>
                  Found <%= @search_stats.total_results %> messages for "<%= @search_stats.query %>" 
                  in <%= @search_stats.search_time_ms %>ms (Deep Search)
                <% @search_stats.search_type == "hybrid" -> %>
                  Found <%= @search_stats.total_results %> messages for "<%= @search_stats.query %>" 
                  (Smart Search - Combined Results)
                <% @search_stats.original_message -> %>
                  Found <%= @search_stats.total_results %> messages similar to:
                  <div class="mt-1 p-2 bg-gray-100 rounded text-xs">
                    <%= @search_stats.original_message.content %>
                  </div>
                <% true -> %>
                  Found <%= @search_stats.total_results %> messages
              <% end %>
            </div>
          <% end %>

          <!-- Error Display -->
          <%= if @search_error do %>
            <div class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
              <p class="text-red-700"><%= @search_error %></p>
            </div>
          <% end %>

          <!-- Results List -->
          <%= if length(@search_results) > 0 do %>
            <div class="space-y-4">
              <%= for message <- @search_results do %>
                <div class="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-lg hover:border-blue-300 transition-all cursor-pointer"
                     phx-click={JS.navigate(~p"/#{message.room_id}?highlight=#{message.id}")}>
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <!-- Message Header -->
                      <div class="flex items-center space-x-2 mb-2">
                        <span class="font-medium text-gray-900">
                          <%= message.user.username || message.user.email %>
                        </span>
                        <span class="text-sm text-gray-500">
                          <%= Calendar.strftime(message.inserted_at, "%b %d, %Y at %I:%M %p") %>
                        </span>
                        <%= if room = Enum.find(@rooms, &(&1.id == message.room_id)) do %>
                          <span class="text-xs bg-gray-100 px-2 py-1 rounded">
                            <%= room.emoji %> <%= room.name %>
                          </span>
                        <% end %>
                      </div>

                      <!-- Message Content -->
                      <div class="text-gray-800 mb-3">
                        <%= message.content %>
                      </div>

                      <!-- Thread Info -->
                      <%= if message.parent_message do %>
                        <div class="text-sm text-gray-600 bg-gray-50 p-2 rounded mb-2">
                          Reply to: <%= String.slice(message.parent_message.content, 0, 100) %>...
                        </div>
                      <% end %>

                      <%= if message.reply_count > 0 do %>
                        <div class="text-sm text-blue-600">
                          <%= message.reply_count %> <%= if message.reply_count == 1, do: "reply", else: "replies" %>
                        </div>
                      <% end %>
                    </div>

                    <!-- Actions -->
                    <div class="ml-4 flex flex-col space-y-1">
                      <button
                        phx-click="find_similar"
                        phx-value-message_id={message.id}
                        class="text-xs text-blue-600 hover:text-blue-800"
                        onclick="event.stopPropagation()"
                      >
                        Find Similar
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <%= if @query != "" and not @searching and @search_stats do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                </svg>
                <p>No messages found for your search.</p>
                <p class="text-sm mt-1">Try different keywords or adjust the search filters.</p>
              </div>
            <% else %>
              <div class="text-center py-12 text-gray-500">
                <svg class="mx-auto h-16 w-16 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                </svg>
                <h3 class="text-lg font-medium text-gray-900 mb-2">Semantic Search</h3>
                <p>Search through messages using natural language.</p>
                <p class="text-sm mt-1">Try queries like "machine learning discussion" or "project deadlines"</p>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end