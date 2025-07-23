defmodule EmberchatWeb.ChatComponents do
  use EmberchatWeb, :html

  def room_list(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= for room <- @rooms do %>
        <div class="w-full">
          <.link
            patch={~p"/chat/#{room}"}
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
    
    ~H"""
    <div class={[
      "chat chat-start transition-all duration-500 rounded-lg",
      @highlighted && "bg-yellow-100 border-2 border-yellow-400 p-2 -m-2"
    ]} id={"message-#{@message.id}"}>
      <%= if @message.parent_message do %>
        <div class="mb-2 opacity-70">
          <div
            class="card card-compact bg-base-200 cursor-pointer hover:bg-neutral transition-colors"
            phx-click={JS.dispatch("scroll-to-message", to: "#message-#{@message.parent_message.id}")}
          >
            <div class="card-body p-2">
              <div class="text-xs font-medium">
                <.icon name="hero-arrow-uturn-left" class="h-3 w-3 inline" />
                Replying to {@message.parent_message.user.username}
              </div>
              <div class="text-sm truncate">
                {@message.parent_message.content}
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <div class="chat-image avatar avatar-placeholder">
        <div class="w-10 rounded-full bg-neutral text-primary-content placeholder">
          <span class="text-xl">
            {String.first(@message.user.username || @message.user.email) |> String.upcase()}
          </span>
        </div>
      </div>
      <div class="chat-header">
        <span class="font-medium">{@message.user.username}</span>
        <time class="text-xs opacity-50">
          {Calendar.strftime(@message.inserted_at, "%I:%M %p")}
        </time>
      </div>

      <div class="chat-bubble chat-bubble-primary group relative">
        <span class="break-words">{@message.content}</span>
        <button
          class="absolute -top-2 -right-2 opacity-0 group-hover:opacity-100 transition-opacity btn btn-circle btn-ghost btn-xs"
          phx-click="reply_to"
          phx-value-message_id={@message.id}
          title="Reply to this message"
        >
          <.icon name="hero-arrow-uturn-left" class="h-3 w-3" />
        </button>
      </div>
      
      <%= if @message.reply_count > 0 do %>
        <div class="mt-2">
          <button
            phx-click="show_thread"
            phx-value-message_id={@message.id}
            class="btn btn-xs btn-ghost gap-1 text-primary hover:bg-primary/10"
          >
            <.icon name="hero-chat-bubble-left-ellipsis" class="h-3 w-3" />
            <span>{@message.reply_count} {if @message.reply_count == 1, do: "reply", else: "replies"}</span>
            <%= if @message.last_reply_at do %>
              <span class="text-xs opacity-70">
                · {Calendar.strftime(@message.last_reply_at, "%I:%M %p")}
              </span>
            <% end %>
          </button>
        </div>
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
    <div class="navbar bg-base-200 shadow-sm px-6">
      <div class="navbar-start flex-1">
        <div>
          <h2 class="text-lg font-bold flex items-center gap-2">
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

      <%= if @current_user_id == @room.user_id do %>
        <div class="navbar-end">
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
      "min-h-full bg-base-200 flex flex-col transition-all duration-300 flex-shrink-0",
      @drawer_open && "w-64",
      !@drawer_open && "w-20"
    ]}>
      <!-- Sidebar Header -->
      <div class="bg-base-300 shadow-sm p-2">
        <%= if @drawer_open do %>
          <button
            phx-click="toggle_drawer"
            class="w-full p-2 rounded-lg hover:bg-base-200 transition-colors duration-200 flex items-center gap-3"
          >
            <.icon name="hero-bars-3" class="h-5 w-5 flex-shrink-0" />
            <span class="text-xl font-bold flex-1 text-left">EmberChat</span>
            <.icon name="hero-chevron-left" class="h-4 w-4 flex-shrink-0" />
          </button>
        <% else %>
          <div class="flex justify-center">
            <button
              phx-click="toggle_drawer"
              class="w-12 h-12 rounded-lg hover:bg-base-200 transition-colors duration-200 flex items-center justify-center"
            >
              <.icon name="hero-bars-3" class="h-5 w-5" />
            </button>
          </div>
        <% end %>
      </div>
      
    <!-- User Info -->
      <div class="px-2 py-2">
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body p-2">
            <%= if @drawer_open do %>
              <div class="flex items-center gap-3 flex-row">
                <div class="avatar avatar-placeholder">
                  <div class="bg-neutral text-primary-content rounded-full w-8">
                    <span class="text-base">
                      {String.first(@current_user.username) |> String.upcase()}
                    </span>
                  </div>
                </div>
                <div class="flex-1">
                  <p class="font-medium text-sm">{@current_user.username}</p>
                  <p class="text-xs text-base-content/60">Online</p>
                </div>
              </div>
            <% else %>
              <div class="flex justify-center">
                <div class="avatar avatar-placeholder">
                  <div class="bg-neutral text-primary-content rounded-full w-10">
                    <span class="text-sm">
                      {String.first(@current_user.username) |> String.upcase()}
                    </span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Navigation -->
      <div class="px-2 py-2">
        <.link
          navigate={~p"/search"}
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
        </.link>
      </div>

    <!-- Room List -->
      <div class="flex-1 overflow-y-auto px-2">
        <%= if @drawer_open do %>
          <div class="divider text-xs">ROOMS</div>
        <% end %>
        <.room_list rooms={@rooms} current_room={@current_room} drawer_open={@drawer_open} />
        <div class="mt-4">
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
      
    <!-- Sidebar Footer -->
      <div class="p-2">
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
end
