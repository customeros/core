defmodule Core.Utils.UrlFormatter do
  @moduledoc """
  Transforms domains to specified format
  """

  alias Core.Utils.Errors

  @doc """
  Returns an https version of the url provided
  """
  @spec to_https(String.t()) ::
          {:ok, String.t()} | {:error, Core.Utils.Errors.url_error()}
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

  def to_https(""), do: Errors.error(:url_not_provided)
  def to_https(nil), do: Errors.error(:url_not_provided)
  def to_https(_), do: Errors.error(:invalid_url)
end
