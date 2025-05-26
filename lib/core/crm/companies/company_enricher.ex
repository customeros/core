defmodule Core.Crm.Companies.CompanyEnricher do
  @moduledoc """
  GenServer responsible for periodically enriching company data.
  Runs every 15 minutes and processes companies that need enrichment for various fields:
  - Logo
  # - Industry
  # - Name
  # - Country
  """
  use GenServer
  require Logger

  alias Core.Crm.Companies.Enrich

  @default_interval_ms 15 * 60 * 1000
  @default_batch_size 20

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule the first check
    schedule_check(@default_interval_ms)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:enrich_companies, state) do
    companiesForLogoEnrichment = Enrich.fetch_companies_for_logo_enrichment(@default_batch_size)
    company_count = length(companiesForLogoEnrichment)

    # Enrich each company's logo
    Enum.each(companiesForLogoEnrichment, &enrich_company_logo/1)

    # Log the batch processing result
    if company_count > 0 do
      Logger.info("Processed #{company_count} companies for logo enrichment")
    end

    # Schedule the next check
    schedule_check(@default_interval_ms)

    {:noreply, state}
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :enrich_companies, interval_ms)
  end

  defp enrich_company_logo(company) do
    case Enrich.enrich_logo(company.id) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to start logo enrichment for company: #{company.id} (domain: #{company.primary_domain}), reason: #{inspect(reason)}")
    end
  end
end
