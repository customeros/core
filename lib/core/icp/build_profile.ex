defmodule Core.Icp.BuildProfile do
  alias Core.Auth.Tenants
  alias Core.Scraper.Service
  alias Core.Scraper.Repository

  def start_for_tenant(tenant_id) do
    with {:ok, tenant_record} <- Tenants.get_tenant_by_id(tenant_id),
         {:reply, _result, _state} <-
           Service.crawl_website(tenant_record.domain),
         {:ok, _pages} <-
           Repository.get_business_pages_by_domain(
             tenant_record.domain,
             limit: 10
           ) do
      ## build ICP
      ## write to tenant table
      {:ok}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
