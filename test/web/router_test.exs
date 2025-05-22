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
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You must log in to access this page."
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

  test "GET /api/organizations/:organization_id/documents requires authentication", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/organizations/#{Ecto.UUID.generate()}/documents")

    # Should return 401 if not authenticated
    assert conn.status == 401
    assert json_response(conn, 401)["error"] == "Unauthorized"
  end

  describe "POST /v1/events" do
    test "returns 202 when valid event is created", %{conn: conn} do
      # Mock IPIntelligence service to return success
      Core.WebTracker.IPIntelligence.Mock
      |> expect(:get_ip_data, fn ip ->
        {:ok, %{
          ip_address: ip,
          city: "Test City",
          region: "Test Region",
          country_code: "US",
          is_threat: false,
          is_mobile: false
        }}
      end)
      |> expect(:get_company_info, fn "127.0.0.1" ->
        {:ok, %{domain: "example.com", company: %{name: "Example Inc."}}}
      end)

      event_data = %{
        visitorId: "visitor-1",
        eventType: "page_view",
        eventData: "{\"path\":\"/\",\"title\":\"Home\"}",
        tenant: "test-tenant",
        ip: "127.0.0.1",
        href: "https://getkanda.com/",
        hostname: "getkanda.com",
        pathname: "/",
        language: "en-US",
        cookiesEnabled: true,
        timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
        origin: "getkanda.com",
        referrer: "https://getkanda.com",
        userAgent: "test-agent"
      }

      conn =
        conn
        |> put_req_header("origin", "getkanda.com")
        |> put_req_header("referer", "https://getkanda.com")
        |> put_req_header("user-agent", "test-agent")
        |> post("/v1/events", event_data)

      assert conn.status == 202
      assert json_response(conn, 202)["accepted"] == true
      assert json_response(conn, 202)["session_id"] != nil
    end

    test "returns 400 when visitor_id is missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "getkanda.com")
        |> put_req_header("referer", "https://getkanda.com")
        |> put_req_header("user-agent", "test-agent")
        |> post("/v1/events", %{})

      assert conn.status == 400
      assert json_response(conn, 400)["error"] == "bad_request"
      assert json_response(conn, 400)["details"] == "missing visitor_id"
    end

    test "returns 403 when origin is not configured", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "malicious-site.com")
        |> put_req_header("referer", "https://malicious-site.com")
        |> put_req_header("user-agent", "test-agent")
        |> post("/v1/events", %{visitorId: "visitor-1"})

      assert conn.status == 403
      assert json_response(conn, 403)["error"] == "forbidden"
      assert json_response(conn, 403)["details"] == "origin not configured"
    end
  end
end

# NOTE: Ensure that Core.WebTracker.IPIntelligence.get_ip_data/1 uses the configured module (Application.compile_env/3) for the mock to work in tests..
