defmodule Web.RouterTest do
  use Web.ConnCase, async: true
  @endpoint Web.Endpoint

  import Mox

  setup :verify_on_exit!

  setup do
    Core.Repo.delete_all(Core.WebTracker.Sessions.Session)
    :ok
  end

  test "GET /health returns 200", %{conn: conn} do
    conn = get(conn, "/health")
    assert conn.status == 200
  end

  test "GET / (protected root) redirects unauthenticated users", %{conn: conn} do
    conn = get(conn, "/")
    assert redirected_to(conn) == "/signin"
  end

  test "GET /signin renders signin page", %{conn: conn} do
    conn = get(conn, "/signin")
    assert html_response(conn, 200) =~ "Signin"
  end

  test "POST /signin handles magic link request", %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{})
    conn = Phoenix.ConnTest.fetch_flash(conn)
    email = "test@example.com"
    conn = post(conn, "/signin", %{email: email})

    # Should redirect back to signin page with success message
    assert redirected_to(conn) == "/signin"
    conn = get(conn, "/signin")
    assert html_response(conn, 200) =~ "Signin"
    # The controller renders the page without a flash message
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == nil
  end
end
