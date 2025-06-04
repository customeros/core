defmodule Core.Utils.UrlFormatter do
  @moduledoc """
  Transforms domains to specified format
  """
  @err_url_not_provided {:error, :url_not_provided}
  @err_invalid_url {:error, :invalid_url}

  @doc """
  Returns an https version of the url provided
  """
  def to_https(input) when is_binary(input) and byte_size(input) > 0 do
    input = String.trim(input)

    cond do
      # Already has https://
      String.starts_with?(input, "https://") ->
        {:ok, input}

      # Has http:// - convert to https://
      String.starts_with?(input, "http://") ->
        {:ok, String.replace_prefix(input, "http://", "https://")}

      # No protocol - add https://
      true ->
        {:ok, "https://#{input}"}
    end
  end

  def to_https({:ok, url}), do: to_https(url)
  def to_https(""), do: @err_url_not_provided
  def to_https(nil), do: @err_url_not_provided
  def to_https(_), do: @err_invalid_url

  @doc """
  Strips query parameters from a URL and returns both the base URL and the query parameters.

  ## Examples

      iex> Core.Utils.UrlFormatter.strip_query_params("https://example.com/path?foo=bar&baz=qux")
      {:ok, "https://example.com/path", %{"foo" => "bar", "baz" => "qux"}}
      
      iex> Core.Utils.UrlFormatter.strip_query_params("https://example.com/path")
      {:ok, "https://example.com/path", %{}}
      
      iex> Core.Utils.UrlFormatter.strip_query_params("")
      {:error, :url_not_provided}
  """
  def strip_query_params(url) when is_binary(url) and byte_size(url) > 0 do
    url = String.trim(url)

    case String.split(url, "?", parts: 2) do
      [base_url] ->
        # No query parameters
        {:ok, base_url, %{}}

      [base_url, query_string] ->
        # Parse query parameters
        query_params = parse_query_string(query_string)
        {:ok, base_url, query_params}
    end
  end

  def strip_query_params(""), do: @err_url_not_provided
  def strip_query_params(nil), do: @err_url_not_provided
  def strip_query_params(_), do: @err_invalid_url

  @doc """
  Returns only the base URL without query parameters.

  ## Examples

      iex> Core.Utils.UrlFormatter.get_base_url("https://example.com/path?foo=bar")
      {:ok, "https://example.com/path"}
  """
  def get_base_url(url) do
    case strip_query_params(url) do
      {:ok, base_url, _query_params} -> {:ok, base_url}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns only the query parameters as a map.

  ## Examples

      iex> Core.Utils.UrlFormatter.get_query_params("https://example.com/path?foo=bar&baz=qux")
      {:ok, %{"foo" => "bar", "baz" => "qux"}}
  """
  def get_query_params(url) do
    case strip_query_params(url) do
      {:ok, _base_url, query_params} -> {:ok, query_params}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper to parse query string into a map
  defp parse_query_string(query_string) do
    query_string
    |> String.split("&")
    |> Enum.reduce(%{}, fn param, acc ->
      case String.split(param, "=", parts: 2) do
        [key] ->
          # Parameter without value
          Map.put(acc, URI.decode_www_form(key), "")

        [key, value] ->
          # Parameter with value
          Map.put(acc, URI.decode_www_form(key), URI.decode_www_form(value))
      end
    end)
  end
end
