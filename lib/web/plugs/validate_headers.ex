defmodule Web.Plugs.ValidateHeaders do
  @moduledoc """
  A Plug that validates required headers for API requests.

  This plug ensures that all requests include the necessary tenant and user context
  by validating the presence of required headers. It supports both standard and
  legacy header formats:

  Required Headers:
  - `x-tenant` or `x-openline-tenant` - Identifies the tenant context
  - `x-username` or `x-openline-username` - Identifies the user context

  The plug will:
  - Check for required headers
  - Return 401 Unauthorized with appropriate error messages if headers are missing
  - Add validated context to the Absinthe GraphQL context
  - Support header format migration through fallback checks
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    tenant =
      case get_req_header(conn, "x-tenant") do
        [] -> get_req_header(conn, "x-openline-tenant") |> List.first()
        [value] -> value
      end

    username =
      case get_req_header(conn, "x-username") do
        [] -> get_req_header(conn, "x-openline-username") |> List.first()
        [value] -> value
      end

    # internal_api_key = get_req_header(conn, "x-openline-api-key") |> List.first()

    # api_token = System.get_env("API_TOKEN")

    # if internal_api_key && internal_api_key != api_token do
    #   conn
    #   |> put_resp_content_type("application/json")
    #   |> send_resp(
    #     401,
    #     Jason.encode!(%{error: "Unauthorized", message: "Invalid internal app token"})
    #   )
    #   |> halt()
    # else
    #   conn
    # end

    if !tenant do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        401,
        Jason.encode!(%{
          error: "Unauthorized",
          message: "missing tenant header"
        })
      )
      |> halt()
    end

    if !username do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        401,
        Jason.encode!(%{
          error: "Unauthorized",
          message: "missing username header"
        })
      )
      |> halt()
    end

    context = %{
      tenant: tenant,
      username: username
    }

    Absinthe.Plug.put_options(conn, context: context)
  end
end
