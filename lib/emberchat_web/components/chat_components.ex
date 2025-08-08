defmodule EmberchatWeb.ChatComponents do
  use EmberchatWeb, :html

  def room_list(assigns) do
    ~H"""
    <div class="flex md:flex-col gap-2 md:space-y-2">
      <%= for room <- @rooms do %>
        <div class="flex-shrink-0 md:w-full">
          <.link
            patch={~p"/#{room}"}
            class={[
              "block w-full p-2 rounded-lg transition-all duration-200 hover:bg-base-300 border",
              @drawer_open && "flex items-center gap-3",
              !@drawer_open && "flex justify-center",
              @current_room && @current_room.id == room.id && "bg-primary/10 border-primary/20",
              !(@current_room && @current_room.id == room.id) && "border-transparent"
            ]}
          >
            <div class="flex-shrink-0">
              <div class={[
                "rounded-full text-neutral-content border transition-all duration-200 flex items-center justify-center",
                @drawer_open && "w-8 h-8",
                !@drawer_open && "w-10 h-10",
                @current_room && @current_room.id == room.id &&
                  "bg-primary text-primary-content border-primary-focus ring-2 ring-primary/30",
                !(@current_room && @current_room.id == room.id) &&
                  "bg-base-300 border-base-content/10 hover:border-primary/50"
              ]}>
                <span
                  class={[
                    @drawer_open && "text-xs",
                    !@drawer_open && "text-sm"
                  ]}
                  style="text-shadow: 0 0 2px rgba(0,0,0,0.5), 0 0 4px rgba(255,255,255,0.5);"
                >
                  {Map.get(room, :emoji, "💬")}
                </span>
              </div>
            </div>
            <%= if @drawer_open do %>
              <div class="flex-1 min-w-0">
                <span class="block truncate font-medium text-xs">{room.name}</span>
              </div>
              <%= if @current_room && @current_room.id == room.id do %>
                <div class="flex-shrink-0">
                  <div class="w-2 h-2 bg-primary rounded-full"></div>
                </div>
              <% end %>
            <% end %>
          </.link>
        </div>
      <% end %>
    </div>
    """
  end

  def message_bubble(assigns) do
    assigns = assign_new(assigns, :highlighted, fn -> false end)
    assigns = assign_new(assigns, :current_user_id, fn -> nil end)
    assigns = assign_new(assigns, :show_all_reactions, fn -> false end)
    assigns = assign_new(assigns, :thread_expanded, fn -> false end)
    
    ~H"""
    <div id={"message-#{@message.id}"}>
      <%= if @message.is_pinned do %>
        <div class="mb-2 flex items-center gap-2 text-xs text-primary">
          <.icon name="hero-bookmark-solid" class="h-4 w-4" />
          <span class="font-medium">Pinned</span>
          <%= if @message.pin_slug do %>
            <span class="text-base-content/60">#{@message.pin_slug}</span>
          <% end %>
          <%= if @message.pinned_by && Ecto.assoc_loaded?(@message.pinned_by) do %>
            <span class="text-base-content/60">by {@message.pinned_by.username}</span>
          <% end %>
        </div>
      <% end %>
      

      <div class="flex gap-3">
        <div class="flex-shrink-0">
          <div class="avatar avatar-placeholder">
            <div class="w-10 rounded-full bg-neutral text-primary-content placeholder">
              <span class="text-xl">
                {String.first(@message.user.username || @message.user.email) |> String.upcase()}
              </span>
            </div>
          </div>
        </div>
        
        <div class="flex-1 min-w-0">
          <div class="mb-1">
            <span class="font-medium">{@message.user.username}</span>
            <time class="text-xs opacity-50 ml-2">
              {Calendar.strftime(@message.inserted_at, "%I:%M %p")}
            </time>
          </div>
          
          <div class="inline-block">
            <div class={[
              "rounded-2xl px-4 py-2 group relative transition-all duration-500",
              @message.user_id == @current_user_id && "bg-primary text-primary-content",
              @message.user_id != @current_user_id && "bg-transparent border border-base-content/20 text-base-content",
              @highlighted && "!bg-yellow-100 !text-gray-900 border-4 border-yellow-400 shadow-lg"
            ]}>
              <span class="break-words">{@message.content}</span>
              <div class="absolute -top-2 -right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                <.message_actions_menu message={@message} />
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <.message_reactions 
        reactions={Map.get(@message, :reaction_summary, [])} 
        message_id={@message.id}
        current_user_id={@current_user_id}
        show_all={@show_all_reactions}
      />
      
      <%= if @message.reply_count > 0 do %>
        <div class="mt-2 ml-14">
          <button
            phx-click="toggle_thread"
            phx-value-message_id={@message.id}
            class="btn btn-xs btn-ghost gap-1 text-primary hover:bg-primary/10"
          >
            <.icon name={if @thread_expanded, do: "hero-chevron-down", else: "hero-chevron-right"} class="h-3 w-3" />
            <.icon name="hero-chat-bubble-left-ellipsis" class="h-3 w-3" />
            <span>{@message.reply_count} {if @message.reply_count == 1, do: "reply", else: "replies"}</span>
            <%= if @message.last_reply_at do %>
              <span class="text-xs opacity-70">
                · {Calendar.strftime(@message.last_reply_at, "%I:%M %p")}
              </span>
            <% end %>
          </button>
        </div>

        <%= if @thread_expanded and length(Map.get(@message, :thread_messages, [])) > 0 do %>
          <div class="mt-3 ml-14">
            <div class="pl-4 border-l-2 border-base-300 space-y-3">
              <%= for thread_message <- Map.get(@message, :thread_messages, []) do %>
                <div class="flex gap-3">
                  <div class="flex-shrink-0">
                    <div class="avatar avatar-placeholder">
                      <div class="w-8 rounded-full bg-neutral text-primary-content placeholder">
                        <span class="text-sm">
                          {String.first(thread_message.user.username || thread_message.user.email) |> String.upcase()}
                        </span>
                      </div>
                    </div>
                  </div>
                  
                  <div class="flex-1 min-w-0">
                    <div class="mb-1">
                      <span class="font-medium text-sm">{thread_message.user.username}</span>
                      <time class="text-xs opacity-50 ml-2">
                        {Calendar.strftime(thread_message.inserted_at, "%I:%M %p")}
                      </time>
                    </div>
                    
                    <div class="inline-block">
                      <div class="bg-base-200 text-base-content rounded-2xl px-4 py-2 group relative transition-all duration-200">
                        <span class="break-words text-sm">{thread_message.content}</span>
                        <div class="absolute -top-2 -right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                          <.message_actions_menu message={thread_message} parent_message_id={@message.id} />
                        </div>
                      </div>
                    </div>
                    
                    <.message_reactions 
                      reactions={Map.get(thread_message, :reaction_summary, [])} 
                      message_id={thread_message.id}
                      current_user_id={@current_user_id}
                      show_all={false}
                    />
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def reply_preview(assigns) do
    ~H"""
    <%= if @replying_to do %>
      <div class="alert alert-info mb-3">
        <.icon name="hero-arrow-uturn-left" class="h-4 w-4" />
        <div class="flex-1">
          <div class="text-sm font-semibold">Replying to {@replying_to.user.username}</div>
          <div class="text-xs opacity-70 truncate">{@replying_to.content}</div>
        </div>
        <button class="btn btn-ghost btn-circle btn-sm" phx-click="cancel_reply" title="Cancel reply">
          <.icon name="hero-x-mark" class="h-4 w-4" />
        </button>
      </div>
    <% end %>
    """
  end

  def chat_header(assigns) do
    ~H"""
    <div class="h-16 bg-base-200 shadow-sm flex items-center px-4">
      <!-- Mobile menu button -->
      <button class="md:hidden mr-2" phx-click="toggle_drawer">
        <.icon name="hero-bars-3" class="h-6 w-6" />
      </button>
      <div class="flex-1">
        <div>
          <h2 class="text-sm md:text-lg font-bold flex items-center gap-2">
            <div class="avatar avatar-placeholder">
              <div class="bg-neutral text-neutral-content rounded-full w-8">
                <span class="text-xs">{Map.get(@room, :emoji, "💬")}</span>
              </div>
            </div>
            {@room.name}
            <%= if @room.is_private do %>
              <span class="text-xs opacity-60">🔒</span>
            <% end %>
          </h2>
          <%= if @room.description do %>
            <p class="text-sm text-base-content/60 ml-10">{@room.description}</p>
          <% end %>
        </div>
      </div>
      
      <!-- Mobile search button -->
      <button class="md:hidden mr-2" phx-click="show_search_modal">
        <.icon name="hero-magnifying-glass" class="h-6 w-6" />
      </button>

      <%= if @current_user_id == @room.user_id do %>
        <div>
          <button
            phx-click="show_edit_room_modal"
            phx-value-room_id={@room.id}
            class="btn btn-sm btn-ghost gap-2"
          >
            <.icon name="hero-pencil" class="h-4 w-4" />
            <span class="hidden sm:inline">Edit</span>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  def chat_sidebar(assigns) do
    ~H"""
    <!-- Custom sidebar with toggle support -->
    <aside class={[
      "bg-base-200 flex transition-all duration-300 flex-shrink-0",
      "w-full md:w-auto md:min-h-full md:flex-col",
      "flex-row overflow-x-auto md:overflow-x-visible",
      @drawer_open && "md:w-64",
      !@drawer_open && "md:w-20"
    ]}>
      <!-- Sidebar Header - Hidden on mobile -->
      <div class="hidden md:flex h-16 bg-base-300 shadow-sm items-center px-2">
        <%= if @drawer_open do %>
          <button
            phx-click="toggle_drawer"
            class="w-full px-2 py-2 rounded-lg hover:bg-base-200 transition-colors duration-200 flex items-center gap-3"
          >
            <.icon name="hero-bars-3" class="h-5 w-5 flex-shrink-0" />
            <span class="text-xl font-bold flex-1 text-left">EmberChat</span>
            <.icon name="hero-chevron-left" class="h-4 w-4 flex-shrink-0" />
          </button>
        <% else %>
          <button
            phx-click="toggle_drawer"
            class="w-full h-12 rounded-lg hover:bg-base-200 transition-colors duration-200 flex items-center justify-center"
          >
            <.icon name="hero-bars-3" class="h-5 w-5" />
          </button>
        <% end %>
      </div>
      
    <!-- Navigation - Hidden on mobile -->
      <div class="hidden md:block px-2 py-2">
        <button
          phx-click="show_search_modal"
          class={[
            "block w-full p-2 rounded-lg transition-all duration-200 hover:bg-base-300 border border-transparent hover:border-primary/20",
            @drawer_open && "flex items-center gap-3",
            !@drawer_open && "flex justify-center"
          ]}
        >
          <div class="flex-shrink-0">
            <div class={[
              "rounded-full bg-base-300 border border-base-content/10 hover:border-primary/50 transition-all duration-200 flex items-center justify-center",
              @drawer_open && "w-8 h-8",
              !@drawer_open && "w-10 h-10"
            ]}>
              <.icon name="hero-magnifying-glass" class={
                if @drawer_open, do: "h-4 w-4", else: "h-5 w-5"
              } />
            </div>
          </div>
          <%= if @drawer_open do %>
            <div class="flex-1 min-w-0">
              <span class="block truncate font-medium text-xs">Search Messages</span>
            </div>
          <% end %>
        </button>
      </div>

    <!-- Room List -->
      <div class="flex md:flex-1 overflow-x-auto md:overflow-y-auto overflow-y-hidden px-2 py-2 md:py-0">
        <%= if @drawer_open do %>
          <div class="divider text-xs hidden md:block">ROOMS</div>
        <% end %>
        <.room_list rooms={@rooms} current_room={@current_room} drawer_open={@drawer_open} />
        <div class="mt-4 hidden md:block">
          <div class="w-full">
            <button
              phx-click="show_new_room_modal"
              class={[
                "block w-full p-2 rounded-lg transition-all duration-200 hover:bg-primary/20 border-2 border-dashed border-primary/40 hover:border-primary/60",
                @drawer_open && "flex items-center gap-3",
                !@drawer_open && "flex justify-center"
              ]}
            >
              <div class="flex-shrink-0">
                <div class={[
                  "rounded-full border-2 border-dashed border-primary/60 bg-primary/10 text-primary transition-all duration-200 flex items-center justify-center hover:bg-primary/20",
                  @drawer_open && "w-8 h-8",
                  !@drawer_open && "w-10 h-10"
                ]}>
                  <.icon name="hero-plus" class={if @drawer_open, do: "h-4 w-4", else: "h-5 w-5"} />
                </div>
              </div>
              <%= if @drawer_open do %>
                <div class="flex-1 min-w-0">
                  <span class="block truncate font-medium text-sm text-primary">New Room</span>
                </div>
              <% end %>
            </button>
          </div>
        </div>
      </div>
      
    <!-- Sidebar Footer - Hidden on mobile -->
      <div class="hidden md:block p-2">
        <%= if @drawer_open do %>
          <div class="bg-base-100 rounded-lg p-2 flex gap-2">
            <.link
              navigate={~p"/users/settings"}
              class="flex-1 p-2 rounded-lg hover:bg-base-200 transition-colors duration-200 flex items-center justify-center tooltip tooltip-top"
              data-tip="Settings"
            >
              <.icon name="hero-cog-6-tooth" class="h-5 w-5" />
            </.link>
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="flex-1 p-2 rounded-lg hover:bg-base-200 transition-colors duration-200 flex items-center justify-center tooltip tooltip-top"
              data-tip="Log out"
            >
              <.icon name="hero-arrow-left-on-rectangle" class="h-5 w-5" />
            </.link>
          </div>
        <% else %>
          <div class="space-y-2 flex flex-col items-center">
            <.link
              navigate={~p"/users/settings"}
              class="w-10 h-10 rounded-full hover:bg-base-300 transition-colors duration-200 flex items-center justify-center tooltip tooltip-right"
              data-tip="Settings"
            >
              <.icon name="hero-cog-6-tooth" class="h-4 w-4" />
            </.link>
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="w-10 h-10 rounded-full hover:bg-base-300 transition-colors duration-200 flex items-center justify-center tooltip tooltip-right"
              data-tip="Log out"
            >
              <.icon name="hero-arrow-left-on-rectangle" class="h-4 w-4" />
            </.link>
          </div>
        <% end %>
      </div>
    </aside>
    """
  end

  def message_input(assigns) do
    assigns = assign_new(assigns, :draft, fn -> "" end)
    
    ~H"""
    <div class="p-4 bg-base-200">
      <.reply_preview replying_to={@replying_to} />

      <.form for={%{}} phx-submit="send_message" phx-change="update_draft" class="join w-full">
        <div class="form-control flex-1">
          <input
            type="text"
            name="message[content]"
            value={@draft}
            placeholder={
              if @replying_to,
                do: "Reply to #{@replying_to.user.username}...",
                else: "Type a message..."
            }
            class="input input-bordered join-item w-full focus:input-primary"
            required
          />
        </div>
        <input type="hidden" name="message[room_id]" value={@room_id} />
        <button type="submit" class="btn btn-primary join-item">
          <.icon name="hero-paper-airplane" class="h-5 w-5" />
          <span class="hidden sm:inline ml-2">
            {if @replying_to, do: "Reply", else: "Send"}
          </span>
        </button>
      </.form>
    </div>
    """
  end

  def room_form_modal(assigns) do
    ~H"""
    <div class={[
      "modal",
      @show && "modal-open"
    ]}>
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">{@title}</h3>

        <.form for={@form} id="room-form" phx-change="validate_room" phx-submit="save_room">
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
        </.form>

        <div class="modal-action">
          <button form="room-form" type="submit" class="btn btn-primary" phx-disable-with="Saving...">
            Save Room
          </button>
          <button class="btn" phx-click="close_room_modal">Cancel</button>
        </div>
      </div>
      <label class="modal-backdrop cursor-pointer" phx-click="close_room_modal"></label>
    </div>
    """
  end

  def empty_chat_state(assigns) do
    ~H"""
    <div class="hero min-h-full bg-base-200">
      <div class="hero-content text-center">
        <div class="max-w-md">
          <div class="avatar avatar-placeholder mb-4">
            <div class="bg-neutral text-neutral-content rounded-full w-24">
              <span class="text-4xl">💬</span>
            </div>
          </div>
          <h1 class="text-4xl font-bold">Welcome to EmberChat</h1>
          <p class="py-6 text-base-content/70">
            Select a room from the sidebar to start chatting with your friends and colleagues.
          </p>
          <button class="btn btn-primary" phx-click="show_new_room_modal">
            Create Your First Room
          </button>
        </div>
      </div>
    </div>
    """
  end
  
  def search_modal(assigns) do
    ~H"""
    <div class={[
      "modal",
      @show && "modal-open"
    ]} phx-hook="SearchModal" id="search-modal">
      <div class="modal-box max-w-4xl w-11/12 max-h-[90vh] flex flex-col">
        <div class="flex items-center justify-between mb-4">
          <h3 class="font-bold text-xl">Search Messages</h3>
          <button class="btn btn-sm btn-ghost btn-circle" phx-click="close_search_modal">
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>

        <!-- Search Form -->
        <form phx-submit="search" class="space-y-4 mb-4">
          <div class="relative">
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Search for messages using natural language..."
              phx-keyup="get_search_suggestions"
              phx-debounce="300"
              class="input input-bordered w-full text-lg focus:input-primary"
              autofocus
            />
            
            <!-- Search/Clear Buttons -->
            <div class="absolute right-2 top-2 flex space-x-2">
              <%= if @query != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="btn btn-sm btn-ghost"
                >
                  Clear
                </button>
              <% end %>
              
              <button
                type="submit"
                disabled={@searching or String.length(@query) < 2}
                class="btn btn-sm btn-primary"
              >
                <%= if @searching do %>
                  <span class="loading loading-spinner loading-sm"></span>
                <% else %>
                  <.icon name="hero-magnifying-glass" class="h-4 w-4" />
                <% end %>
                Search
              </button>
            </div>
            
            <!-- Suggestions Dropdown -->
            <%= if @show_suggestions and length(@suggestions) > 0 do %>
              <div class="absolute z-10 w-full mt-1 bg-base-100 border border-base-300 rounded-lg shadow-lg max-h-40 overflow-y-auto">
                <%= for suggestion <- @suggestions do %>
                  <button
                    type="button"
                    phx-click="select_search_suggestion"
                    phx-value-suggestion={suggestion}
                    class="w-full px-4 py-2 text-left hover:bg-base-200 first:rounded-t-lg last:rounded-b-lg text-sm"
                  >
                    <%= suggestion %>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Search Filters -->
          <details class="text-sm">
            <summary class="cursor-pointer text-base-content/70 hover:text-base-content">
              Advanced Options
            </summary>
            <div class="mt-3 p-4 bg-base-200 rounded-lg space-y-3">
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <!-- Room Filter -->
                <div>
                  <label class="block text-sm font-medium mb-1">
                    Filter by Room
                  </label>
                  <select name="room_id" class="select select-bordered w-full select-sm">
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
                  <label class="block text-sm font-medium mb-1">
                    Similarity Weight: <%= @similarity_weight %>
                  </label>
                  <input
                    type="range"
                    name="similarity_weight"
                    min="0.1"
                    max="1.0"
                    step="0.1"
                    value={@similarity_weight}
                    class="range range-primary range-sm"
                  />
                </div>

                <!-- Recency Weight -->
                <div>
                  <label class="block text-sm font-medium mb-1">
                    Recency Weight: <%= @recency_weight %>
                  </label>
                  <input
                    type="range"
                    name="recency_weight"
                    min="0.1"
                    max="1.0"
                    step="0.1"
                    value={@recency_weight}
                    class="range range-primary range-sm"
                  />
                </div>
              </div>

              <button
                type="button"
                phx-click="search_with_filters"
                phx-value-query={@query}
                phx-value-room_id={@selected_room}
                phx-value-similarity_weight={@similarity_weight}
                phx-value-recency_weight={@recency_weight}
                class="btn btn-sm btn-secondary"
              >
                Apply Filters
              </button>
            </div>
          </details>
        </form>

        <!-- Search Results -->
        <div class="flex-1 overflow-auto">
          <!-- Search Stats -->
          <%= if @search_stats do %>
            <div class="mb-4 text-sm text-base-content/70">
              <%= if @search_stats.search_type == "semantic" do %>
                Found <%= @search_stats.total_results %> messages for "<%= @search_stats.query %>" 
                in <%= @search_stats.search_time_ms %>ms
              <% else %>
                Found <%= @search_stats.total_results %> messages similar to:
                <div class="mt-1 p-2 bg-base-200 rounded text-xs">
                  <%= @search_stats.original_message.content %>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Error Display -->
          <%= if @search_error do %>
            <div class="alert alert-error mb-4">
              <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
              <span><%= @search_error %></span>
            </div>
          <% end %>

          <!-- Results List -->
          <%= if length(@search_results) > 0 do %>
            <div class="space-y-3">
              <%= for message <- @search_results do %>
                <div class="card bg-base-100 border border-base-300 hover:border-primary/50 transition-all cursor-pointer"
                     phx-click={JS.navigate(~p"/#{message.room_id}?highlight=#{message.id}")}>
                  <div class="card-body p-4">
                    <!-- Message Header -->
                    <div class="flex items-center justify-between mb-2">
                      <div class="flex items-center space-x-2">
                        <div class="avatar avatar-placeholder">
                          <div class="bg-neutral text-neutral-content rounded-full w-6">
                            <span class="text-xs">
                              <%= String.first(message.user.username || message.user.email) |> String.upcase() %>
                            </span>
                          </div>
                        </div>
                        <span class="font-medium text-sm">
                          <%= message.user.username || message.user.email %>
                        </span>
                        <span class="text-xs text-base-content/60">
                          <%= Calendar.strftime(message.inserted_at, "%b %d, %Y at %I:%M %p") %>
                        </span>
                        <%= if room = Enum.find(@rooms, &(&1.id == message.room_id)) do %>
                          <span class="badge badge-sm">
                            <%= room.emoji %> <%= room.name %>
                          </span>
                        <% end %>
                      </div>
                      
                      <button
                        phx-click="find_similar"
                        phx-value-message_id={message.id}
                        class="btn btn-xs btn-ghost text-primary"
                        onclick="event.stopPropagation()"
                      >
                        Find Similar
                      </button>
                    </div>

                    <!-- Message Content -->
                    <div class="text-sm">
                      <%= message.content %>
                    </div>

                    <!-- Thread Info -->
                    <%= if message.parent_message do %>
                      <div class="text-xs text-base-content/60 bg-base-200 p-2 rounded mt-2">
                        Reply to: <%= String.slice(message.parent_message.content, 0, 100) %>...
                      </div>
                    <% end %>

                    <%= if message.reply_count > 0 do %>
                      <div class="text-xs text-primary mt-1">
                        <%= message.reply_count %> <%= if message.reply_count == 1, do: "reply", else: "replies" %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <%= if @query != "" and not @searching and @search_stats do %>
              <div class="text-center py-8 text-base-content/60">
                <.icon name="hero-magnifying-glass" class="mx-auto h-12 w-12 mb-4 text-base-content/40" />
                <p>No messages found for your search.</p>
                <p class="text-xs mt-1">Try different keywords or adjust the search filters.</p>
              </div>
            <% else %>
              <div class="text-center py-12 text-base-content/60">
                <.icon name="hero-magnifying-glass" class="mx-auto h-16 w-16 mb-4 text-base-content/40" />
                <h4 class="text-lg font-medium text-base-content mb-2">Semantic Search</h4>
                <p>Search through messages using natural language.</p>
                <p class="text-sm mt-1">Try queries like "machine learning discussion" or "project deadlines"</p>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
      <label class="modal-backdrop cursor-pointer" phx-click="close_search_modal"></label>
    </div>
    """
  end

  def thread_view(assigns) do
    ~H"""
    <div class={[
      "fixed inset-y-0 right-0 w-96 bg-base-100 shadow-2xl transform transition-transform duration-300 z-50",
      @show && "translate-x-0",
      !@show && "translate-x-full"
    ]} phx-click-away="hide_thread">
      <div class="flex flex-col h-full" phx-click="noop">
        <!-- Thread Header -->
        <div class="navbar bg-base-200 shadow-sm px-4">
          <div class="navbar-start flex-1">
            <h3 class="text-lg font-bold">Thread</h3>
          </div>
          <div class="navbar-end">
            <button class="btn btn-sm btn-ghost btn-circle" phx-click="close_thread">
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>
        </div>
        
        <!-- Original Message -->
        <%= if @parent_message do %>
          <div class="p-4 bg-base-200 border-b">
            <div class="chat chat-start">
              <div class="chat-image avatar avatar-placeholder">
                <div class="w-8 rounded-full bg-neutral text-primary-content placeholder">
                  <span class="text-sm">
                    {String.first(@parent_message.user.username || @parent_message.user.email) |> String.upcase()}
                  </span>
                </div>
              </div>
              <div class="chat-header">
                <span class="font-medium text-sm">{@parent_message.user.username}</span>
                <time class="text-xs opacity-50">
                  {Calendar.strftime(@parent_message.inserted_at, "%I:%M %p")}
                </time>
              </div>
              <div class="chat-bubble chat-bubble-neutral">
                <span class="break-words text-sm">{@parent_message.content}</span>
              </div>
            </div>
          </div>
        <% end %>
        
        <!-- Thread Messages -->
        <div class="flex-1 overflow-y-auto p-4 space-y-4" id="thread-messages">
          <%= for message <- @thread_messages do %>
            <div class="chat chat-start">
              <div class="chat-image avatar avatar-placeholder">
                <div class="w-8 rounded-full bg-neutral text-primary-content placeholder">
                  <span class="text-sm">
                    {String.first(message.user.username || message.user.email) |> String.upcase()}
                  </span>
                </div>
              </div>
              <div class="chat-header">
                <span class="font-medium text-sm">{message.user.username}</span>
                <time class="text-xs opacity-50">
                  {Calendar.strftime(message.inserted_at, "%I:%M %p")}
                </time>
              </div>
              <div class="chat-bubble chat-bubble-primary">
                <span class="break-words text-sm">{message.content}</span>
              </div>
            </div>
          <% end %>
        </div>
        
        <!-- Thread Input -->
        <div class="p-4 bg-base-200">
          <.form for={%{}} phx-submit="send_thread_message" phx-change="update_thread_draft" class="join w-full">
            <div class="form-control flex-1">
              <input
                type="text"
                name="message[content]"
                value={@draft || ""}
                placeholder="Reply in thread..."
                class="input input-bordered join-item w-full focus:input-primary input-sm"
                required
              />
            </div>
            <input type="hidden" name="message[room_id]" value={@room_id} />
            <input type="hidden" name="message[parent_message_id]" value={@parent_message_id} />
            <button type="submit" class="btn btn-primary join-item btn-sm">
              <.icon name="hero-paper-airplane" class="h-4 w-4" />
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def reaction_picker(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <label tabindex="0" class="btn btn-circle btn-ghost btn-xs" title="Add reaction">
        <.icon name="hero-face-smile" class="h-3 w-3" />
      </label>
      <div tabindex="0" class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-64">
        <div class="grid grid-cols-5 gap-1 p-2">
          <% allowed_emojis = ["👍", "❤️", "😂", "🎉", "🤔", "👎", "🔥", "👏", "💯", "😢"] %>
          <%= for emoji <- allowed_emojis do %>
            <button
              phx-click="toggle_reaction"
              phx-value-message_id={@message_id}
              phx-value-emoji={emoji}
              class="btn btn-ghost btn-sm text-xl hover:bg-base-200"
              title={"React with #{emoji}"}
            >
              {emoji}
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def message_reactions(assigns) do
    assigns = assign_new(assigns, :show_all, fn -> false end)
    
    ~H"""
    <%= if length(@reactions) > 0 do %>
      <div class="mt-2 ml-14">
        <div class="flex flex-wrap gap-1">
          <% visible_reactions = if @show_all, do: @reactions, else: Enum.take(@reactions, 10) %>
          <%= for reaction <- visible_reactions do %>
            <button
              phx-click="toggle_reaction"
              phx-value-message_id={@message_id}
              phx-value-emoji={reaction.emoji}
              class={[
                "btn btn-xs gap-1 h-7",
                @current_user_id in (reaction.user_ids || []) && "btn-primary",
                !(@current_user_id in (reaction.user_ids || [])) && "btn-ghost border-base-300"
              ]}
              title={
                reaction.users
                |> Enum.map(& &1.username || &1.email)
                |> Enum.join(", ")
              }
            >
              <span class="text-sm">{reaction.emoji}</span>
              <span class="text-xs font-normal">{reaction.count}</span>
            </button>
          <% end %>
          
          <%= if length(@reactions) > 10 && !@show_all do %>
            <button
              phx-click="toggle_show_all_reactions"
              phx-value-message_id={@message_id}
              class="btn btn-xs btn-ghost border-base-300 h-7"
              title="Show all reactions"
            >
              <span class="text-xs">+{length(@reactions) - 10} more</span>
            </button>
          <% end %>
          
          <%= if @show_all && length(@reactions) > 10 do %>
            <button
              phx-click="toggle_show_all_reactions"
              phx-value-message_id={@message_id}
              class="btn btn-xs btn-ghost border-base-300 h-7"
              title="Show less reactions"
            >
              <span class="text-xs">Show less</span>
            </button>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  def keyboard_shortcuts_modal(assigns) do
    ~H"""
    <div
      id="keyboard-shortcuts-modal"
      class={[
        "modal",
        @show_keyboard_shortcuts && "modal-open"
      ]}
      phx-click-away="hide_keyboard_shortcuts"
    >
      <div class="modal-box max-w-2xl">
        <h3 class="font-bold text-lg mb-4">Keyboard Shortcuts</h3>
        
        <div class="space-y-6">
          <div>
            <h4 class="font-semibold text-sm mb-2 text-base-content/70">Navigation</h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Next message</span>
                <kbd class="kbd kbd-sm">j</kbd>
              </div>
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Previous message</span>
                <kbd class="kbd kbd-sm">k</kbd>
              </div>
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Search</span>
                <kbd class="kbd kbd-sm">/</kbd>
              </div>
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Next room</span>
                <div class="flex gap-1">
                  <kbd class="kbd kbd-sm">Ctrl</kbd>
                  <span class="text-xs self-center">+</span>
                  <kbd class="kbd kbd-sm">j</kbd>
                </div>
              </div>
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Previous room</span>
                <div class="flex gap-1">
                  <kbd class="kbd kbd-sm">Ctrl</kbd>
                  <span class="text-xs self-center">+</span>
                  <kbd class="kbd kbd-sm">k</kbd>
                </div>
              </div>
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Close modals</span>
                <kbd class="kbd kbd-sm">Esc</kbd>
              </div>
            </div>
          </div>
          
          <div>
            <h4 class="font-semibold text-sm mb-2 text-base-content/70">Actions</h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Reply to message</span>
                <kbd class="kbd kbd-sm">r</kbd>
              </div>
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Like/React to message</span>
                <kbd class="kbd kbd-sm">l</kbd>
              </div>
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Pin message</span>
                <kbd class="kbd kbd-sm">p</kbd>
              </div>
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Show this help</span>
                <kbd class="kbd kbd-sm">?</kbd>
              </div>
              <div class="flex items-center justify-between p-2 rounded bg-base-200">
                <span class="text-sm">Toggle thread (selected message)</span>
                <kbd class="kbd kbd-sm">s</kbd>
              </div>
            </div>
          </div>
          
          <div class="text-sm text-base-content/60 mt-4">
            <p>Note: Keyboard shortcuts are disabled when typing in input fields.</p>
          </div>
        </div>
        
        <div class="modal-action">
          <button
            type="button"
            class="btn btn-sm"
            phx-click="hide_keyboard_shortcuts"
          >
            Close
          </button>
        </div>
      </div>
    </div>
    """
  end

  def message_actions_menu(assigns) do
    assigns = assign_new(assigns, :parent_message_id, fn -> nil end)
    
    ~H"""
    <div class="dropdown dropdown-end">
      <label tabindex="0" class="btn btn-circle btn-xs bg-base-300 hover:bg-base-content hover:text-base-100 border border-base-content/20 shadow-sm" title="Message actions">
        <.icon name="hero-ellipsis-horizontal" class="h-3 w-3" />
      </label>
      <div tabindex="0" class="dropdown-content menu p-1 shadow bg-base-100 rounded-box w-48 z-50">
        <ul class="menu-compact">
          <li>
            <button
              phx-click="reply_to"
              phx-value-message_id={@parent_message_id || @message.id}
              class="flex items-center gap-2 px-3 py-2 text-sm hover:bg-base-200 rounded"
            >
              <.icon name="hero-arrow-uturn-left" class="h-4 w-4" />
              Reply
            </button>
          </li>
          <li>
            <button
              phx-click="toggle_pin"
              phx-value-message_id={@message.id}
              class="flex items-center gap-2 px-3 py-2 text-sm hover:bg-base-200 rounded"
            >
              <.icon name={if @message.is_pinned, do: "hero-bookmark-solid", else: "hero-bookmark"} class="h-4 w-4" />
              {if @message.is_pinned, do: "Unpin", else: "Pin"}
            </button>
          </li>
          <li>
            <div class="px-3 py-2">
              <div class="grid grid-cols-5 gap-1">
                <% allowed_emojis = ["👍", "❤️", "😂", "🎉", "🤔", "👎", "🔥", "👏", "💯", "😢"] %>
                <%= for emoji <- allowed_emojis do %>
                  <button
                    phx-click="toggle_reaction"
                    phx-value-message_id={@message.id}
                    phx-value-emoji={emoji}
                    class="btn btn-ghost btn-xs text-lg hover:bg-base-200 w-8 h-8 p-0"
                    title={"React with #{emoji}"}
                  >
                    {emoji}
                  </button>
                <% end %>
              </div>
            </div>
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
