defmodule Web.FaviconController do
  use Web, :controller

  def serve(conn, %{"path" => path}) do
    file_path = Path.join(["priv", "static", "favicon", path])

    if File.exists?(file_path) do
      conn
      |> put_resp_content_type(get_content_type(path))
      |> send_file(200, file_path)
    else
      conn
      |> put_status(:not_found)
      |> text("Not found")
    end
  end

  defp get_content_type(path) do
    case Path.extname(path) do
      ".ico" -> "image/x-icon"
      ".png" -> "image/png"
      ".svg" -> "image/svg+xml"
      ".json" -> "application/json"
      _ -> "application/octet-stream"
    end
  end
end
