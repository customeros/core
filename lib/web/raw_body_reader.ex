defmodule Web.RawBodyReader do
  @moduledoc """
  A Plug module that reads and stores raw request body data.

  This module provides a custom body reader that captures the raw request body
  and stores it in the connection assigns for later use. This is useful when
  you need to access the raw body data multiple times or for debugging purposes.

  ## Usage

  Add this to your endpoint configuration:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        body_reader: {Web.RawBodyReader, :read_body, []}

  ## Function

  - `read_body/2` - Reads the request body and stores it in `conn.assigns[:raw_body]`
  """
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end
end
