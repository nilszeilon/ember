defmodule Emberchat.Accounts.UserNotifier do
  import Swoosh.Email

  alias Emberchat.Mailer
  alias Emberchat.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, text_body, html_body) do
    from_email = Application.get_env(:emberchat, :from_email, {"Emberchat", "noreply@emberchat.org"})
    
    email =
      new()
      |> to(recipient)
      |> from(from_email)
      |> subject(subject)
      |> text_body(text_body)
      |> html_body(html_body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp email_template(title, content, button_text, button_url) do
    app_name = Application.get_env(:emberchat, :app_name, "Emberchat")
    app_domain = Application.get_env(:emberchat, :app_domain, "emberchat.org")
    
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{title}</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
          line-height: 1.6;
          color: #333;
          background-color: #f5f5f5;
          margin: 0;
          padding: 0;
        }
        .container {
          max-width: 600px;
          margin: 40px auto;
          background-color: #ffffff;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
          overflow: hidden;
        }
        .header {
          background-color: #dc2626;
          color: white;
          padding: 30px;
          text-align: center;
        }
        .header h1 {
          margin: 0;
          font-size: 28px;
          font-weight: normal;
        }
        .content {
          padding: 40px 30px;
        }
        .content p {
          margin: 0 0 20px;
        }
        .button {
          display: inline-block;
          padding: 14px 30px;
          background-color: #dc2626;
          color: white;
          text-decoration: none;
          border-radius: 6px;
          font-weight: 500;
          margin: 20px 0;
        }
        .button:hover {
          background-color: #b91c1c;
        }
        .footer {
          padding: 20px 30px;
          background-color: #f9fafb;
          text-align: center;
          font-size: 14px;
          color: #6b7280;
          border-top: 1px solid #e5e7eb;
        }
        .footer a {
          color: #dc2626;
          text-decoration: none;
        }
        .url-box {
          background-color: #f3f4f6;
          padding: 15px;
          border-radius: 4px;
          margin: 20px 0;
          word-break: break-all;
          font-family: monospace;
          font-size: 14px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>#{app_name}</h1>
        </div>
        <div class="content">
          #{content}
          #{if button_url do
            """
            <div style="text-align: center; margin: 30px 0;">
              <a href="#{button_url}" class="button">#{button_text}</a>
            </div>
            <p style="font-size: 14px; color: #6b7280; margin-top: 30px;">
              Or copy and paste this link into your browser:
            </p>
            <div class="url-box">#{button_url}</div>
            """
          else
            ""
          end}
        </div>
        <div class="footer">
          <p>© #{DateTime.utc_now().year} #{app_name}. All rights reserved.</p>
          <p><a href="https://#{app_domain}">#{app_domain}</a></p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    app_name = Application.get_env(:emberchat, :app_name, "Emberchat")
    
    subject = "Update your email address"
    
    text_body = """
    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    —
    The #{app_name} Team
    """
    
    html_body = email_template(
      "Update Email Address",
      """
      <p>Hi #{user.email},</p>
      <p>We received a request to update your email address. Click the button below to proceed:</p>
      """,
      "Update Email Address",
      url
    )
    
    deliver(user.email, subject, text_body, html_body)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    app_name = Application.get_env(:emberchat, :app_name, "Emberchat")
    
    subject = "Log in to #{app_name}"
    
    text_body = """
    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    —
    The #{app_name} Team
    """
    
    html_body = email_template(
      "Log In to Your Account",
      """
      <p>Hi #{user.email},</p>
      <p>Click the button below to securely log in to your #{app_name} account:</p>
      <p style="font-size: 14px; color: #6b7280; margin-top: 20px;">
        This link will expire in 60 minutes for your security.
      </p>
      """,
      "Log In Now",
      url
    )
    
    deliver(user.email, subject, text_body, html_body)
  end

  defp deliver_confirmation_instructions(user, url) do
    app_name = Application.get_env(:emberchat, :app_name, "Emberchat")
    
    subject = "Confirm your #{app_name} account"
    
    text_body = """
    Hi #{user.email},

    Welcome to #{app_name}! You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    —
    The #{app_name} Team
    """
    
    html_body = email_template(
      "Confirm Your Account",
      """
      <p>Hi #{user.email},</p>
      <p>Welcome to #{app_name}! We're excited to have you on board.</p>
      <p>To get started, please confirm your email address by clicking the button below:</p>
      """,
      "Confirm Email Address",
      url
    )
    
    deliver(user.email, subject, text_body, html_body)
  end
end