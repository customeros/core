defmodule Core.Integrations.Providers.HubSpot.Webhook do
  @moduledoc """
  HubSpot webhook handling.

  This module handles incoming webhooks from HubSpot, including:
  - Webhook verification
  - Event processing
  - Data synchronization
  """

  alias Core.Integrations.Connection
  alias Core.Integrations.Connections
  alias Core.Integrations.Providers.HubSpot.Company

  @doc """
  Verifies a webhook request from HubSpot.

  ## Examples

      iex> verify_webhook(connection, "signature", "payload")
      {:ok, true}

      iex> verify_webhook(connection, "invalid", "payload")
      {:error, :invalid_signature}
  """
  def verify_webhook(%Connection{} = connection, signature, payload) do
    expected = generate_signature(payload, connection.access_token)
    if Plug.Crypto.secure_compare(signature, expected), do: {:ok, true}, else: {:error, :invalid_signature}
  end

  @doc """
  Processes a webhook event from HubSpot.

  ## Examples

      iex> process_event(connection, %{"subscriptionType" => "company.creation", "objectId" => "123"})
      {:ok, %{processed: true}}
  """
  def process_event(%Connection{} = connection, event) do
    with {:ok, _} <- Connections.update_status(connection, :active),
         {:ok, company} <- Company.get_company(connection, event["objectId"]),
         {:ok, _} <- sync_company(company) do
      {:ok, %{processed: true}}
    end
  end

  # Private functions

  defp generate_signature(payload, client_secret) do
    :crypto.mac(:hmac, :sha256, client_secret, payload)
    |> Base.encode64()
  end

  defp sync_company(company) do
    # In a real implementation, you would:
    # 1. Transform the HubSpot company data to your format
    # 2. Create or update the company in your system
    # 3. Handle any errors that occur
    {:ok, company}
  end
end
