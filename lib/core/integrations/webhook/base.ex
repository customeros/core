defmodule Core.Integrations.Webhook.Base do
  @moduledoc """
  Behaviour module for webhook handling in integrations.

  This module defines the contract that all webhook handlers must implement.
  It ensures consistent webhook handling across different integration providers.

  ## Callbacks

  * `handle_webhook/2` - Handles incoming webhook data from the integration provider
  """

  @doc """
  Handles incoming webhook data from the integration provider.

  ## Parameters
  - `tenant_id` - The ID of the tenant receiving the webhook
  - `webhook_data` - The webhook payload from the provider

  ## Returns
  - `{:ok, result}` - Successful webhook handling
  - `{:error, reason}` - Failed webhook handling
  """
  @callback handle_webhook(tenant_id :: String.t(), webhook_data :: map()) ::
              {:ok, any()} | {:error, String.t()}
end
