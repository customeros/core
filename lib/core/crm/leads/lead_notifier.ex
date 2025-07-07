defmodule Core.Crm.Leads.LeadNotifier do
  @moduledoc """
  Notifies the frontend about lead changes.
  """

  alias Core.Crm.Leads.Lead

  @doc """
  Notifies the frontend about a lead being created.
  """
  @spec notify_lead_created(Lead.t()) :: :ok | {:error, :bad_input}
  def notify_lead_created(%Lead{} = lead) do
    icon_url =
      case Core.Crm.Companies.get_icon_url(lead.ref_id) do
        {:ok, icon_url} -> icon_url
        _ -> nil
      end

    Web.Endpoint.broadcast("events:#{lead.tenant_id}", "event", %{
      type: :lead_created,
      payload: %{
        id: lead.id,
        icon_url: icon_url,
        stage: lead.stage
      }
    })
  end

  def notify_lead_created(_) do
    {:error, :bad_input}
  end

  @doc """
  Notifies the frontend about a lead being updated.
  """
  @spec notify_lead_updated(Lead.t()) :: :ok | {:error, :bad_input}
  def notify_lead_updated(%Lead{} = lead) do
    Web.Endpoint.broadcast("events:#{lead.tenant_id}", "event", %{
      type: :lead_updated,
      payload: %{
        id: lead.id
      }
    })
  end

  def notify_lead_updated(_) do
    {:error, :bad_input}
  end
end
