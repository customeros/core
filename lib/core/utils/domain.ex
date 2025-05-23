defmodule Core.Utils.Domain do
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

  def extract_domain_from_email(email) when is_binary(email) and byte_size(email) > 0 do
    case String.split(email, "@", parts: 2) do
      [_, domain] when byte_size(domain) > 0 ->
        validate_domain(domain)
      _ ->
        {:error, :invalid_email_format}
    end
  end
  def extract_domain_from_email(""), do: {:error, :invalid_email_format}
  def extract_domain_from_email(nil), do: {:error, :invalid_email_format}
end
