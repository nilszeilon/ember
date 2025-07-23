defmodule EmberchatWeb.PageController do
  use EmberchatWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
