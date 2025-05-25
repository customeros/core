defmodule Core.Utils.DomainExtractor do
  @moduledoc """
  Domain extraction utility
  """

  alias Core.Utils.DomainExtractor
  alias Core.Utils.Errors
  alias Core.Utils.DomainValidator

  @doc """
  Extracts the base domain from a url string.
  """
  @spec extract_base_domain(String.t()) ::
          {:ok, String.t()}
          | {:error,
             Core.Utils.Errors.url_error()
             | Core.Utils.Errors.domain_error()}
  def extract_base_domain(url_or_host)
      when is_binary(url_or_host) and byte_size(url_or_host) > 0 do
    with {:ok, host} <- extract_host(url_or_host) do
      base_domain = DomainExtractor.clean_domain(host)

      case DomainValidator.validate_domain(base_domain) do
        {:ok, normalized_domain} -> {:ok, normalized_domain}
        # This will be a domain_error()
        {:error, reason} -> {:error, reason}
      end
    else
      # This will be a url_error()
      {:error, reason} -> {:error, reason}
    end
  end

  def extract_base_domain(""), do: Errors.error(:url_not_provided)
  def extract_base_domain(nil), do: Errors.error(:url_not_provided)
  def extract_base_domain(_), do: Errors.error(:invalid_url)

  @doc """
  Extracts the domain from an email address
  """
  @spec extract_domain_from_email(String.t()) ::
          {:ok, String.t()} | {:error, Core.Utils.Errors.email_error()}
  def extract_domain_from_email(email)
      when is_binary(email) and byte_size(email) > 0 do
    case String.split(email, "@", parts: 2) do
      [_, domain] when byte_size(domain) > 0 ->
        DomainValidator.validate_domain(domain)

      _ ->
        Errors.error(:invalid_email)
    end
  end

  def extract_domain_from_email(""), do: Errors.error(:email_not_provided)
  def extract_domain_from_email(nil), do: Errors.error(:email_not_provided)
  def extract_domain_from_email(_), do: Errors.error(:invalid_email)

  defp extract_host(url_or_host) do
    # Try parsing as URL first (handles both with and without protocol)
    parsed =
      if String.contains?(url_or_host, "://") do
        URI.parse(url_or_host)
      else
        # Add a dummy protocol for parsing
        URI.parse("http://#{url_or_host}")
      end

    case parsed do
      %URI{host: host} when is_binary(host) and host != "" ->
        {:ok, host}

      _ ->
        Errors.error(:invalid_url)
    end
  end

  def clean_domain(domain) do
    domain
    |> String.replace_prefix("http://", "")
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("www.", "")
    |> String.trim("/")
    |> String.trim()
  end
end
