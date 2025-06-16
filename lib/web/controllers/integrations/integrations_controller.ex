defmodule Web.Controllers.Integrations.IntegrationsController do
  @moduledoc """
  Controller for managing integrations settings.

  This controller handles integration operations and returns JSON responses.
  """

  use Web, :controller
  alias Core.Integrations.Registry

  @doc """
  Returns a list of available integrations and their connection status.
  """
  def index(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id
    connections = Registry.list_connections(tenant_id)
    hubspot_config = Application.get_env(:core, :hubspot)

    # Check if there's an active HubSpot connection
    hubspot_connection =
      Enum.find(connections, fn conn ->
        conn.provider == :hubspot && conn.status == :active
      end)

    json(conn, %{
      integrations: [
        %{
          id: :hubspot,
          name: "HubSpot",
          connected: hubspot_connection != nil,
          external_system_id:
            if(hubspot_connection, do: hubspot_connection.external_system_id),
          scopes: hubspot_config[:scopes] || [],
          actions: %{
            connect: "/settings/integrations/hubspot/connect",
            disconnect: "/settings/integrations/hubspot/disconnect"
          }
        }
      ]
    })
  end
end
