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
    tenant_id = conn.assigns.current_tenant.id
    connections = Registry.list_connections(tenant_id)

    json(conn, %{
      integrations: [
        %{
          id: :hubspot,
          name: "HubSpot",
          connected: :hubspot in connections,
          scopes: ["crm.objects.companies.read", "crm.schemas.companies.read", "oauth"],
          actions: %{
            connect: "/settings/integrations/hubspot/authorize",
            disconnect: "/settings/integrations/hubspot/disconnect"
          }
        }
      ]
    })
  end
end
