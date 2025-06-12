defmodule Core.Utils.DomainExtractor do
  @moduledoc """
  Domain extraction utility
  """
  import Core.Utils.Pipeline

  @err_empty_url {:error, "empty url"}
  @err_invalid_url {:error, "invalid url"}
  @err_invalid_domain {:error, "invalid domain"}

  @doc """
  Extracts the base domain from a url string.
  """
  def extract_base_domain(url_or_host)
      when is_binary(url_or_host) and byte_size(url_or_host) > 0 do
    url_or_host
    |> extract_host()
    |> ok(&Domainatrex.parse/1)
    |> ok(&build_base_domain/1)
  end

  def extract_base_domain(""), do: @err_empty_url
  def extract_base_domain(nil), do: @err_empty_url
  def extract_base_domain(_), do: @err_invalid_url

  @doc """
  Extracts the domain from an email address
  """
  def extract_domain_from_email(email)
      when is_binary(email) and byte_size(email) > 0 do
    case String.split(email, "@", parts: 2) do
      [_, domain] when byte_size(domain) > 0 ->
        domain
        |> Domainatrex.parse()
        |> ok(&build_base_domain/1)

      _ ->
        @err_invalid_domain
    end
  end

  def extract_domain_from_email(""), do: @err_empty_url
  def extract_domain_from_email(nil), do: @err_empty_url
  def extract_domain_from_email(_), do: @err_invalid_url

  def clean_domain(domain) do
    domain
    |> String.replace_prefix("http://", "")
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("www.", "")
    |> String.trim("/")
    |> String.trim()
  end

  # Private
  defp extract_host(url_or_host) do
    parsed =
      if String.contains?(url_or_host, "://") do
        URI.parse(url_or_host)
      else
        URI.parse("http://#{url_or_host}")
      end

    case parsed do
      %URI{host: host} when is_binary(host) and host != "" ->
        {:ok, host}

      _ ->
        @err_invalid_url
    end
  end

  defp build_base_domain(%{domain: domain, tld: tld}) do
    {:ok, "#{domain}.#{tld}"}
  end
end
