defmodule Core.Researcher.EmailValidator.Mailsherpa do
  @moduledoc """
  Client for Mailsherpa email validation API.
  """
  require Logger

  @type validation_result :: %{
          email: String.t(),
          valid: boolean(),
          deliverable: String.t(),
          catch_all: boolean(),
          disposable: boolean(),
          role_based: boolean(),
          free_provider: boolean(),
          mx_records: [String.t()] | nil,
          smtp_check: boolean() | nil,
          did_you_mean: String.t() | nil,
          clean_email: String.t() | nil,
          provider: String.t() | nil,
          secure_email_gateway: String.t() | nil,
          is_firewalled: boolean(),
          is_system_generated: boolean(),
          has_mx_record: boolean(),
          has_spf_record: boolean(),
          is_mailbox_full: boolean(),
          smtp_response_code: String.t() | nil,
          smtp_description: String.t() | nil
        }

  @type api_response :: %{
          success: boolean(),
          data: validation_result() | nil,
          message: String.t() | nil
        }

  @err_empty_email {:error, :empty_email}
  @err_invalid_email {:error, :invalid_email}

  @doc """
  Validates an email address using Mailsherpa
  """
  def validate_email(email) when is_binary(email) and byte_size(email) > 0 do
    Logger.metadata(module: __MODULE__, function: :validate_email, email: email)
    Logger.info("Starting email validation with MailSherpa")

    with {:ok, config} <- get_config(),
         {:ok, request} <- build_request(email),
         {:ok, raw_response} <- make_request(config, request),
         {:ok, response} <- parse_response(raw_response) do
      Logger.info("Email validation completed successfully")
      {:ok, response}
    else
      {:error, reason} ->
        Logger.error("Email validation failed", reason: reason)
        {:error, reason}
    end
  end

  def validate_email(""), do: @err_empty_email
  def validate_email(nil), do: @err_empty_email
  def validate_email(_), do: @err_invalid_email

  defp get_config do
    mailsherpa_config = Application.get_env(:core, :mailsherpa, [])
    api_url = Keyword.get(mailsherpa_config, :mailsherpa_api_url)
    api_key = Keyword.get(mailsherpa_config, :mailsherpa_api_key)

    case {api_url, api_key} do
      {nil, _} ->
        {:error, :missing_api_url}

      {_, nil} ->
        {:error, :missing_api_key}

      {"", _} ->
        {:error, :empty_api_url}

      {_, ""} ->
        {:error, :empty_api_key}

      {url, key} ->
        {:ok, %{api_url: url, api_key: key}}
    end
  end

  defp build_request(email) do
    request = %{email: email}

    case Jason.encode(request) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, {:json_encode_error, reason}}
    end
  end

  defp make_request(config, request_body) do
    url = "#{config.api_url}/validateEmail"

    headers = [
      {"x-Openline-API-KEY", config.api_key},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    Logger.debug("Making POST request to MailSherpa", url: url)

    case Finch.build(:post, url, headers, request_body)
         |> Finch.request(Core.Finch, receive_timeout: 30_000) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        Logger.debug("Received successful response from MailSherpa")

        {:ok, body}

      {:ok, %Finch.Response{status: status, body: body}} ->
        Logger.error("MailSherpa returned non-200 status",
          status: status,
          body: body
        )

        OpenTelemetry.Tracer.set_attributes([
          {"http.status_code", status},
          {"response.body", body}
        ])

        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("HTTP request to MailSherpa failed",
          reason: inspect(reason)
        )

        {:error, {:request_failed, reason}}
    end
  end

  defp parse_response(response_body) do
    case Jason.decode(response_body) do
      {:ok, %{"data" => nil}} ->
        Logger.warning("MailSherpa returned response with no data")
        {:error, :no_data_in_response}

      {:ok, %{"data" => data}} when is_map(data) ->
        syntax = Map.get(data, "syntax", %{})
        domain_data = Map.get(data, "domainData", %{})
        email_data = Map.get(data, "emailData", %{})

        validation_result = %{
          email: Map.get(data, "email"),
          valid_syntax: Map.get(syntax, "isValid", false),
          deliverable: Map.get(email_data, "deliverable"),
          catch_all: Map.get(domain_data, "isCatchAll", false),
          disposable: false,
          role_based: Map.get(email_data, "isRoleAccount", false),
          free_provider: Map.get(email_data, "isFreeAccount", false),
          mx_records: extract_mx_records(domain_data),
          smtp_check: Map.get(email_data, "smtpSuccess"),
          did_you_mean: Map.get(email_data, "alternateEmail"),
          clean_email: Map.get(syntax, "cleanEmail"),
          provider: Map.get(domain_data, "provider"),
          secure_email_gateway: Map.get(domain_data, "secureEmailGateway"),
          is_firewalled: Map.get(domain_data, "isFirewalled", false),
          is_system_generated: Map.get(domain_data, "isSystemGenerated", false),
          has_mx_record: Map.get(domain_data, "hasMXRecord", false),
          has_spf_record: Map.get(domain_data, "hasSPFRecord", false),
          is_mailbox_full: Map.get(email_data, "isMailboxFull", false),
          smtp_response_code: Map.get(email_data, "responseCode"),
          smtp_description: Map.get(email_data, "description")
        }

        {:ok, validation_result}

      {:ok, response} ->
        Logger.warning("Unexpected response format from MailSherpa",
          response: response
        )

        {:error, {:unexpected_response_format, response}}

      {:error, reason} ->
        Logger.error("Failed to parse MailSherpa response",
          reason: inspect(reason)
        )

        {:error, {:json_decode_error, reason}}
    end
  end

  defp extract_mx_records(%{"hasMXRecord" => true}), do: ["mx_record_exists"]
  defp extract_mx_records(_), do: nil
end
