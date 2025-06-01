defmodule Web.RouterTest do
  use Web.ConnCase, async: true
  @endpoint Web.Endpoint

  # Import Mox for mocking
  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Setup to delete any existing sessions for the visitor
  setup do
    # Delete any existing sessions for the visitor
    Core.Repo.delete_all(Core.WebTracker.Schemas.WebSession)
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

    # Should show success message and render signin page
    assert html_response(conn, 200) =~ "Signin"
    # The controller renders the page without a flash message
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == nil
  end

  test "GET /api/organizations/:organization_id/documents requires authentication",
       %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/organizations/#{Ecto.UUID.generate()}/documents")

    # Should return 401 if not authenticated
    assert conn.status == 401
    assert json_response(conn, 401)["error"] == "Authentication required"
  end
end
