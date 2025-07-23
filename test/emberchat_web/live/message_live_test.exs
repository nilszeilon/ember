defmodule EmberchatWeb.MessageLiveTest do
  use EmberchatWeb.ConnCase

  import Phoenix.LiveViewTest
  import Emberchat.ChatFixtures

  @create_attrs %{content: "some content"}
  @update_attrs %{content: "some updated content"}
  @invalid_attrs %{content: nil}

  setup :register_and_log_in_user

  defp create_message(%{scope: scope}) do
    message = message_fixture(scope)

    %{message: message}
  end

  describe "Index" do
    setup [:create_message]

    test "lists all messages", %{conn: conn, message: message} do
      {:ok, _index_live, html} = live(conn, ~p"/messages")

      assert html =~ "Listing Messages"
      assert html =~ message.content
    end

    test "saves new message", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/messages")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Message")
               |> render_click()
               |> follow_redirect(conn, ~p"/messages/new")

      assert render(form_live) =~ "New Message"

      assert form_live
             |> form("#message-form", message: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#message-form", message: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/messages")

      html = render(index_live)
      assert html =~ "Message created successfully"
      assert html =~ "some content"
    end

    test "updates message in listing", %{conn: conn, message: message} do
      {:ok, index_live, _html} = live(conn, ~p"/messages")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#messages-#{message.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/messages/#{message}/edit")

      assert render(form_live) =~ "Edit Message"

      assert form_live
             |> form("#message-form", message: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#message-form", message: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/messages")

      html = render(index_live)
      assert html =~ "Message updated successfully"
      assert html =~ "some updated content"
    end

    test "deletes message in listing", %{conn: conn, message: message} do
      {:ok, index_live, _html} = live(conn, ~p"/messages")

      assert index_live |> element("#messages-#{message.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#messages-#{message.id}")
    end
  end

  describe "Show" do
    setup [:create_message]

    test "displays message", %{conn: conn, message: message} do
      {:ok, _show_live, html} = live(conn, ~p"/messages/#{message}")

      assert html =~ "Show Message"
      assert html =~ message.content
    end

    test "updates message and returns to show", %{conn: conn, message: message} do
      {:ok, show_live, _html} = live(conn, ~p"/messages/#{message}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/messages/#{message}/edit?return_to=show")

      assert render(form_live) =~ "Edit Message"

      assert form_live
             |> form("#message-form", message: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#message-form", message: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/messages/#{message}")

      html = render(show_live)
      assert html =~ "Message updated successfully"
      assert html =~ "some updated content"
    end
  end
end
