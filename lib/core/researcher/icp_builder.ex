defmodule Core.Researcher.IcpBuilder do
  alias Core.Researcher.Builder.ProfileWriter
  alias Core.Auth.Tenants

  def build_for_tenant(tenant_id) do
    with {:ok, tenant_record} <- Tenants.get_tenant_by_id(tenant_id),
         {:ok, _scraped_data} <-
           Core.Researcher.Crawler.start_sync(tenant_record.domain),
         {:ok, icp} <- ProfileWriter.generate_icp(tenant_record.domain) do
      profile = %{
        domain: tenant_record.domain,
        tenant_id: tenant_id,
        profile: icp.icp,
        qualifying_attributes: icp.qualifying_attributes
      }

      case Core.Researcher.IcpProfiles.create_profile(profile) do
        {:ok, profile} -> {:ok, profile}
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
