defmodule Core.Crm.Companies.CompanyEnricher do
  @moduledoc """
  GenServer responsible for periodically enriching company data.
  Runs every 15 minutes and processes companies that need enrichment for various fields:
  - Icon
  # - Industry
  # - Name
  # - Country
  """
  use GenServer
  require Logger
  require OpenTelemetry.Tracer

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
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_companies" do
      companiesForIconEnrichment = Enrich.fetch_companies_for_icon_enrichment(@default_batch_size)
      OpenTelemetry.Tracer.set_attributes([
        {"companies.found", length(companiesForIconEnrichment)},
        {"batch.size", @default_batch_size},
        {"enrichment.type", "icon"}
      ])

      # Enrich each company's icon
      Enum.each(companiesForIconEnrichment, &enrich_company_icon/1)

      # Schedule the next check
      schedule_check(@default_interval_ms)

      {:noreply, state}
    end
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :enrich_companies, interval_ms)
  end

  defp enrich_company_icon(company) do
    OpenTelemetry.Tracer.with_span "company_enricher.enrich_icon" do
      OpenTelemetry.Tracer.set_attributes([
        {"company.id", company.id},
        {"company.domain", company.primary_domain}
      ])

      case Enrich.enrich_icon(company.id) do
        :ok ->
          OpenTelemetry.Tracer.set_status(:ok)
          :ok

        {:error, reason} ->
          OpenTelemetry.Tracer.set_status(:error, "enrichment_failed")
          OpenTelemetry.Tracer.set_attributes([
            {"error.reason", inspect(reason)}
          ])
          Logger.error("Failed to start icon enrichment for company: #{company.id} (domain: #{company.primary_domain}), reason: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
