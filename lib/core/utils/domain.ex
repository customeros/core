defmodule Core.Utils.Domain do
  def to_https(input) when is_binary(input) and byte_size(input) > 0 do
    input = String.trim(input)

    # Define regex patterns
    domain_only_pattern = ~r/^[a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z]{2,}$/

    url_pattern =
      ~r/^(https?:\/\/)?([a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z]{2,})(:\d+)?(\/.*)?$/

    cond do
      # Check if it's already a URL with http/https
      Regex.match?(url_pattern, input) ->
        # Get the first capture from the regex
        captures = Regex.run(url_pattern, input)
        # The domain should be the third element (index 2) in the captures
        domain = Enum.at(captures, 2)
        {:ok, "https://#{domain}"}

      # Check if it's just a domain
      Regex.match?(domain_only_pattern, input) ->
        {:ok, "https://#{input}"}

      # Invalid format
      true ->
        {:error, "Invalid domain format"}
    end
  end

  def to_https("") do
    {:error, "Domain cannot be empty"}
  end

  def to_https(nil) do
    {:error, "Domain cannot be nil"}
  end

  def extract_base_domain(url_or_host)
      when is_binary(url_or_host) and byte_size(url_or_host) > 0 do
    with {:ok, host} <- extract_host(url_or_host),
         {:ok, base_domain} <- strip_www_prefix(host) do
      validate_domain(base_domain)
    end
  end

  defp extract_host(url_or_host) do
    if String.starts_with?(url_or_host, "http://") or
         String.starts_with?(url_or_host, "https://") do
      case URI.parse(url_or_host) do
        %URI{host: host} when is_binary(host) and host != "" ->
          {:ok, host}

        _ ->
          {:error, :could_not_determine_host}
      end
    else
      {:ok, url_or_host}
    end
  end

  defp strip_www_prefix(host) do
    {:ok, String.replace_prefix(host, "www.", "")}
  end

  defp validate_domain(domain) do
    if String.contains?(domain, ".") do
      {:ok, domain}
    else
      {:error, :invalid_base_domain_format_after_stripping}
    end
  end

  def clean_domain(domain) do
    domain
    |> String.replace_prefix("http://", "")
    |> String.replace_prefix("https://", "")
    |> String.trim("/")
    |> String.trim()
  end
end
