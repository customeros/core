defmodule Core.Researcher.ContactEnricher.BetterContact do
  @moduledoc """
  Client for the BetterContact API for contact enrichment.

  This module provides functions to start contact enrichment searches via the
  BetterContact API, fetch results, and parse email addresses and phone numbers.
  It supports different search types (email, phone, or both) and handles
  asynchronous job processing with result polling.
  """

  require Logger
  import Core.Utils.Pipeline

  alias Core.Researcher.ContactEnricher.Request
  alias Core.Researcher.ContactEnricher.BetterContactJobs

  @err_empty_api_key {:error, "better contact API key is empty"}
  @err_empty_api_path {:error, "better contact API path is empty"}
  @err_invalid_search_type {:error, "better contact search type is invalid"}
  @err_cannot_process {:error, "API call to better contact failed"}
  @err_unexpected_response {:error, "unexpected response from BetterContact"}
  @err_email_parse {:error, "cannot parse email from BetterContact response"}
  @err_phone_number_parse {:error,
                           "cannot parse phone number from BetterContact response"}

  @doc """
  Starts a BetterContact search.
  """
  def start_search(%Request{} = req) do
    case req.search_type do
      :email -> start_email_search(req)
      :phone -> start_phone_search(req)
      :email_and_phone -> start_email_and_phone_search(req)
      _ -> @err_invalid_search_type
    end
  end

  @doc """
  Fetches the results of a BetterContact search.
  Returns {:ok, email, phone}, {:ok, :processing}, or {:error, reason}
  If email or phone are not found, they will return the atom :not_found
  """
  def fetch_results(job_id) do
    job_id
    |> make_result_call()
    |> ok(&process_results/1)
  end

  defp start_email_search(%Request{} = req) do
    %{
      data: [build_request_data(req)],
      enrich_email_address: true,
      enrich_phone_number: false
    }
    |> make_post_call()
    |> ok(&parse_job_id/1)
    |> BetterContactJobs.create_job(req.contact_id)
  end

  defp start_phone_search(req) do
    %{
      data: [build_request_data(req)],
      enrich_email_address: false,
      enrich_phone_number: true
    }
    |> make_post_call()
    |> ok(&parse_job_id/1)
    |> BetterContactJobs.create_job(req.contact_id)
  end

  defp start_email_and_phone_search(req) do
    %{
      data: [build_request_data(req)],
      enrich_email_address: true,
      enrich_phone_number: true
    }
    |> make_post_call()
    |> ok(&parse_job_id/1)
    |> BetterContactJobs.create_job(req.contact_id)
  end

  defp build_request_data(%Request{} = req) do
    %{
      first_name: req.first_name,
      last_name: req.last_name,
      company: req.company_name,
      company_domain: req.company_domain,
      linkedin_url: req.linkedin_url
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp make_result_call(job_id) do
    with {:ok, config} <- get_config(),
         url = build_result_uri(config, job_id),
         headers = [{"Accept", "application/json"}],
         req = Finch.build(:get, url, headers),
         {:ok, %Finch.Response{status: status, body: body}}
         when status in 200..299 <- Finch.request(req, Core.Finch) do
      {:ok, body}
    else
      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{body}"}

      {:error, %Mint.TransportError{reason: reason}} ->
        {:error, "Network error: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_post_call(payload) do
    with {:ok, config} <- get_config(),
         url = build_post_uri(config),
         headers = [{"Content-Type", "application/json"}],
         req = Finch.build(:post, url, headers, Jason.encode!(payload)),
         {:ok, %Finch.Response{status: status, body: body}}
         when status in 200..299 <- Finch.request(req, Core.Finch) do
      {:ok, body}
    else
      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{body}"}

      {:error, %Mint.TransportError{reason: reason}} ->
        {:error, "Network error: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_results(response) when is_binary(response) do
    with {:ok, data} <- Jason.decode(response),
         true <- job_finished?(data),
         {:ok, email} <- parse_email_address(data),
         {:ok, phone_number} <- parse_phone_number(data) do
      {:ok, email, phone_number}
    else
      false -> {:ok, :processing}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_results(_), do: @err_unexpected_response

  defp job_finished?(data) do
    case data["status"] do
      "terminated" -> true
      _ -> false
    end
  end

  defp parse_email_address(data) do
    case get_in(data, ["data", Access.at(0), "contact_email_address"]) do
      email when is_binary(email) and email != "" -> {:ok, email}
      nil -> {:ok, :not_found}
      "" -> {:ok, :not_found}
      _ -> @err_email_parse
    end
  end

  defp parse_phone_number(data) do
    case get_in(data, ["data", Access.at(0), "contact_phone_number"]) do
      phone when is_binary(phone) and phone != "" ->
        case ExPhoneNumber.parse(phone, "") do
          {:ok, pn} ->
            {:ok, ExPhoneNumber.format(pn, :e164)}

          {:error, reason} ->
            {:error, reason}
        end

      nil ->
        {:ok, :not_found}

      "" ->
        {:ok, :not_found}

      _ ->
        @err_phone_number_parse
    end
  end

  defp parse_job_id(response) when is_binary(response) do
    response
    |> Jason.decode()
    |> ok(&extract_job_id/1)
  end

  defp parse_job_id(_), do: @err_unexpected_response

  defp extract_job_id(%{"id" => id}) when is_binary(id), do: id
  defp extract_job_id(%{"success" => false}), do: @err_cannot_process
  defp extract_job_id(_), do: @err_unexpected_response

  defp build_post_uri(config) do
    base_url = config[:api_path]
    api_key = config[:api_key]

    query_params = URI.encode_query(%{api_key: api_key})
    uri = "#{base_url}?#{query_params}"
    uri
  end

  defp build_result_uri(config, job_id) do
    base_url = config[:api_path]
    api_key = config[:api_key]

    query_params = URI.encode_query(%{api_key: api_key})
    uri = "#{base_url}/#{job_id}?#{query_params}"
    uri
  end

  defp get_config do
    Application.get_env(:core, :better_contact, [])
    |> validate_api_credentials()
  end

  defp validate_api_credentials(config) do
    api_key = config[:api_key]
    api_path = config[:api_url]

    cond do
      is_nil(api_key) or api_key == "" ->
        @err_empty_api_key

      is_nil(api_path) or api_path == "" ->
        @err_empty_api_path

      true ->
        {:ok, %{api_key: api_key, api_path: api_path}}
    end
  end
end
