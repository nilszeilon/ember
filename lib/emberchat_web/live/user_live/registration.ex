defmodule EmberchatWeb.UserLive.Registration do
  use EmberchatWeb, :live_view

  alias Emberchat.Accounts
  alias Emberchat.Accounts.User

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            <%= if @anonymous_user do %>
              Complete your account
            <% else %>
              Register for an account
            <% end %>
            <:subtitle>
              <%= if @anonymous_user do %>
                Add your email to save your account and enable all features.
              <% else %>
                Already registered?
                <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                  Log in
                </.link>
                to your account now.
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            :if={!@anonymous_user}
            field={@form[:username]}
            type="username"
            label="Username"
            autocomplete="username"
            required
          />
          
          <div :if={@anonymous_user} class="mb-4">
            <p class="text-sm text-gray-600">Username: <strong><%= @converting_user.username %></strong></p>
          </div>

          <.button phx-disable-with={if @anonymous_user, do: "Completing account...", else: "Creating account..."} class="btn btn-primary w-full">
            <%= if @anonymous_user, do: "Complete account", else: "Create an account" %>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    # Allow anonymous users to convert to full accounts
    if Accounts.anonymous_user?(user) do
      changeset = Accounts.change_user_email(user)
      {:ok, 
       socket
       |> assign(anonymous_user: true, converting_user: user)
       |> assign_form(changeset),
       temporary_assigns: [form: nil]}
    else
      {:ok, redirect(socket, to: ~p"/")}
    end
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    {:ok, 
     socket
     |> assign(anonymous_user: false, converting_user: nil)
     |> assign_form(changeset), 
     temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    if socket.assigns.anonymous_user do
      # Converting anonymous user to full user
      case Accounts.convert_anonymous_to_full_user(socket.assigns.converting_user, user_params) do
        {:ok, user} ->
          {:ok, _} =
            Accounts.deliver_login_instructions(
              user,
              &url(~p"/users/log-in/#{&1}")
            )

          {:noreply,
           socket
           |> put_flash(
             :info,
             "Account completed! An email was sent to #{user.email} to confirm your account."
           )
           |> push_navigate(to: ~p"/")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    else
      # Regular registration
      case Accounts.register_user(user_params) do
        {:ok, user} ->
          {:ok, _} =
            Accounts.deliver_login_instructions(
              user,
              &url(~p"/users/log-in/#{&1}")
            )

          {:noreply,
           socket
           |> put_flash(
             :info,
             "An email was sent to #{user.email}, please access it to confirm your account."
           )
           |> push_navigate(to: ~p"/users/log-in")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = 
      if socket.assigns.anonymous_user do
        Accounts.change_user_email(socket.assigns.converting_user, user_params)
      else
        Accounts.change_user_registration(%User{}, user_params)
      end
    
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
