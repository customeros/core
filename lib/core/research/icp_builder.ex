defmodule Core.Research.IcpBuilder do
  alias Core.Research.Builder.ProfileWriter
  alias Core.Auth.Tenants

  def build_for_tenant(tenant_id) do
    with {:ok, tenant_record} <- Tenants.get_tenant_by_id(tenant_id),
         {:ok, _scraped_data} <-
           Core.Research.Crawler.start(tenant_record.domain),
         {:ok, icp} <- ProfileWriter.generate_icp(tenant_record.domain) do
      dbg(icp)

      profile = %{
        domain: tenant_record.domain,
        tenant_id: tenant_id,
        profile: icp.icp,
        qualifying_attributes: icp.qualifying_attributes
      }

      case Core.Research.IcpProfiles.create_profile(profile) do
        {:ok, profile} -> {:ok, profile}
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
