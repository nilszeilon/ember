defmodule Emberchat.Repo do
  use Ecto.Repo,
    otp_app: :emberchat,
    adapter: Ecto.Adapters.SQLite3
end
