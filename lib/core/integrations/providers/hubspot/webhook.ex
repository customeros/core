defmodule Core.Integrations.Providers.HubSpot.Webhook do
  @moduledoc """
  HubSpot webhook handling.

  This module handles incoming webhooks from HubSpot, including:
  - Webhook verification
  - Event processing
  - Data synchronization
  """

  require OpenTelemetry.Tracer
  require Logger
  alias Core.Integrations.Connection
  alias Core.Integrations.Connections
  alias Core.Integrations.Providers.HubSpot.Companies

  @type t :: %__MODULE__{
          app_id: integer(),
          attempt_number: integer(),
          change_source: String.t(),
          event_id: integer(),
          object_id: integer(),
          object_type_id: String.t(),
          occurred_at: integer(),
          portal_id: integer(),
          property_name: String.t() | nil,
          property_value: String.t() | nil,
          source_id: String.t(),
          subscription_id: integer(),
          subscription_type: String.t()
        }

  defstruct [
    :app_id,
    :attempt_number,
    :change_source,
    :event_id,
    :object_id,
    :object_type_id,
    :occurred_at,
    :portal_id,
    :property_name,
    :property_value,
    :source_id,
    :subscription_id,
    :subscription_type
  ]

  def new(event_map) when is_map(event_map) do
    %__MODULE__{
      app_id: event_map["appId"],
      attempt_number: event_map["attemptNumber"],
      change_source: event_map["changeSource"],
      event_id: event_map["eventId"],
      object_id: event_map["objectId"],
      object_type_id: event_map["objectTypeId"],
      occurred_at: event_map["occurredAt"],
      portal_id: event_map["portalId"],
      property_name: event_map["propertyName"],
      property_value: event_map["propertyValue"],
      source_id: event_map["sourceId"],
      subscription_id: event_map["subscriptionId"],
      subscription_type: event_map["subscriptionType"]
    }
  end

  def company_event?(event) do
    company_property_change_event?(event) ||
      company_creation_event?(event) ||
      (object_property_change_event?(event) && company_object_event?(event))
  end

  def company_property_change_event?(%__MODULE__{
        subscription_type: subscription_type
      }) do
    subscription_type == "company.propertyChange"
  end

  def company_creation_event?(%__MODULE__{subscription_type: subscription_type}) do
    subscription_type == "company.creation"
  end

  def object_property_change_event?(%__MODULE__{
        subscription_type: subscription_type
      }) do
    subscription_type == "object.propertyChange"
  end

  def company_object_event?(%__MODULE__{object_type_id: object_type_id}) do
    object_type_id == "0-2"
  end

  @doc """
  Gets the object ID as a string for API calls.

  ## Examples

      iex> HubSpotEvent.object_id_string(%HubSpotEvent{object_id: 173686420716})
      "173686420716"
  """
  def object_id_string(%__MODULE__{object_id: object_id}) do
    to_string(object_id)
  end

  @doc """
  Gets the portal ID as a string for connection lookup.

  ## Examples

      iex> HubSpotEvent.portal_id_string(%HubSpotEvent{portal_id: 146363387})
      "146363387"
  """
  def portal_id_string(%__MODULE__{portal_id: portal_id}) do
    to_string(portal_id)
  end

  @doc """
  Fetches a company from HubSpot with additional properties.

  ## Examples

      iex> get_company_with_properties(connection, "123")
      {:ok, %{"id" => "123", "properties" => %{"name" => "Acme Inc", "domain" => "acme.com"}}}
  """
  def get_company_with_properties(%Connection{} = connection, company_id) do
    Companies.get_company_with_properties(
      connection,
      company_id,
      Companies.additional_properties()
    )
  end

  @doc """
  Verifies a webhook request from HubSpot.

  ## Examples

      iex> verify_webhook(connection, "signature", "payload")
      {:ok, true}

      iex> verify_webhook(connection, "invalid", "payload")
      {:error, :invalid_signature}
  """
  def verify_webhook(%Connection{} = connection, signature, payload) do
    expected_signature = generate_signature(payload, connection.access_token)

    if Plug.Crypto.secure_compare(signature, expected_signature),
      do: {:ok, true},
      else: {:error, :invalid_signature}
  end

  @doc """
  Processes a webhook event from HubSpot.

  ## Examples

      iex> process_event(connection, %HubSpotEvent{subscription_type: "company.propertyChange", object_id: 123})
      {:ok, %{processed: true}}
  """
  def process_event(%Connection{} = connection, %__MODULE__{} = event) do
    OpenTelemetry.Tracer.with_span "hubspot.webhook.process_event" do
      if company_event?(event) do
        with {:ok, company} <-
               get_company_with_properties(connection, object_id_string(event)),
             {:ok, crm_company} <-
               Companies.sync_company(company, connection.tenant_id) do
          {:ok, %{processed: true, crm_company: crm_company}}
        else
          {:error, reason} ->
            Logger.warning(
              "[HubSpot Webhook] Error syncing company: #{inspect(reason)}"
            )

            {:error, reason}
        end
      else
        Logger.info(
          "[HubSpot Webhook] Ignoring non-company event: #{event.subscription_type}"
        )

        {:ok, %{ignored: true, reason: "Non-company event"}}
      end
    end
  end

  @doc """
  Verifies HubSpot v3 webhook signature (HMAC SHA-256, base64).

  ## Parameters
    - client_secret: The HubSpot app client secret
    - signature: The signature from the 'x-hubspot-signature-v3' header
    - method: The HTTP method (e.g., "POST")
    - request_uri: The full request URL (e.g., "https://yourdomain.com/webhook")
    - raw_body: The raw request body
    - timestamp: The 'x-hubspot-request-timestamp' header

  ## Returns
    - true if the signature is valid, false otherwise
  """
  def verify_signature_v3(
        client_secret,
        signature,
        method,
        request_uri,
        raw_body,
        timestamp
      ) do
    base_string = "#{method}#{request_uri}#{raw_body}#{timestamp}"

    expected =
      :crypto.mac(:hmac, :sha256, client_secret, base_string)
      |> Base.encode64()

    Plug.Crypto.secure_compare(signature, expected)
  end

  @doc """
  Processes a webhook event by looking up the connection using the event's portalId.
  Returns {:ok, result} or {:error, reason}.
  """
  def process_event_from_webhook(event) when is_map(event) do
    event_struct = new(event)
    portal_id = portal_id_string(event_struct)

    case Connections.get_connection_by_provider_and_external_id(
           :hubspot,
           portal_id
         ) do
      {:ok, connection} -> process_event(connection, event_struct)
      {:error, :not_found} -> {:error, :connection_not_found}
    end
  end

  # Private functions

  defp generate_signature(payload, client_secret) do
    :crypto.mac(:hmac, :sha256, client_secret, payload)
    |> Base.encode64()
  end
end
