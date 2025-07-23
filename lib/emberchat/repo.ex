defmodule Emberchat.Repo do
  use Ecto.Repo,
    otp_app: :emberchat,
    adapter: Ecto.Adapters.SQLite3

  def load_extensions(conn) do
    # load the sqlite-vec extension 
    :esqlite3.exec(conn, "SELECT load_extensions('./sqlite-vec')")
  end
end
