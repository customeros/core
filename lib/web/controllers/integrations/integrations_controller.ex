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
    # TODO test positive flow
    # TODO test negative flow
    dbg("integrations_controller.index ===============")
    tenant_id = conn.assigns.current_tenant.id
    dbg("tenant_id in integrations_controller.index ===============")
    connections = Registry.list_connections(tenant_id)
    hubspot_config = Application.get_env(:core, :hubspot)

    json(conn, %{
      integrations: [
        %{
          id: :hubspot,
          name: "HubSpot",
          connected: :hubspot in connections,
          scopes: hubspot_config[:scopes] || [],
          actions: %{
            connect: "/settings/integrations/hubspot/authorize",
            disconnect: "/settings/integrations/hubspot/disconnect"
          }
        }
      ]
    })
  end
end
