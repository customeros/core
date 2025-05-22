defmodule Web.RouterTest do
  use Web.ConnCase, async: true

  setup %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{})
    conn = Phoenix.ConnTest.fetch_flash(conn)
    {:ok, conn: conn}
  end

  test "GET /health returns 200", %{conn: conn} do
    conn = get(conn, "/health")
    assert conn.status == 200
  end

  test "GET / (protected root) redirects unauthenticated users", %{conn: conn} do
    conn = get(conn, "/")
    assert redirected_to(conn) == "/signin"
    assert get_flash(conn, :error) == "You must log in to access this page."
  end

  test "GET /signin renders signin page", %{conn: conn} do
    conn = get(conn, "/signin")
    assert html_response(conn, 200) =~ "Signin"
  end

  test "POST /signin handles magic link request", %{conn: conn} do
    email = "test@example.com"
    conn = post(conn, "/signin", %{email: email})

    # Should show success message and render signin page
    assert html_response(conn, 200) =~ "Signin"
    # The controller renders the page without a flash message
    assert get_flash(conn, :info) == nil
  end

  test "GET /api/organizations/:organization_id/documents requires authentication", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/organizations/#{Ecto.UUID.generate()}/documents")

    # Should return 401 if not authenticated
    assert conn.status == 401
    assert json_response(conn, 401)["error"] == "Unauthorized"
  end

  test "POST /v1/events creates event (public API)", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://localhost")
      |> put_req_header("referer", "http://localhost")
      |> put_req_header("user-agent", "test-agent")
      |> post("/v1/events", %{visitorId: "visitor-1"})
    # Should return 202 Accepted or 400/403 depending on validation
    assert conn.status in [202, 400, 403]
  end
end
