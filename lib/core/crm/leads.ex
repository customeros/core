defmodule Core.Crm.Leads do
  @moduledoc """
  The Leads context.
  """

  import Ecto.Query, warn: false
  require OpenTelemetry.Tracer
  require Logger
  alias Ecto.Repo
  alias Core.Repo
  alias Core.Crm.Leads.{Lead, LeadView, LeadContext}
  alias Core.Auth.Tenants
  alias Core.Crm.Companies
  alias Core.Crm.Companies.Company
  alias Core.Utils.Media.Images
  alias Core.Utils.Tracing
  alias Core.Crm.Leads.LeadNotifier

  @type order_by ::
          [desc: :inserted_at]
          | [asc: :inserted_at]
          | [desc: :stage]
          | [asc: :stage]
          | [desc: :name]
          | [asc: :name]
          | [desc: :industry]
          | [asc: :industry]
          | [desc: :country]
          | [asc: :country]

  # Public functions

  @doc """
  Get a lead by ref id and tenant id.

  Example:

  ```elixir
  {:ok, lead} = Leads.get_by_ref_id("tenant_id", "ref_id")
  {:error, :not_found} = Leads.get_by_ref_id("tenant_id", "ref_id")
  ```
  """
  @spec get_by_ref_id(tenant_id :: String.t(), ref_id :: String.t()) ::
          {:ok, Lead.t()} | {:error, :not_found}
  def get_by_ref_id(tenant_id, ref_id) do
    case Repo.get_by(Lead, tenant_id: tenant_id, ref_id: ref_id) do
      nil -> {:error, :not_found}
      %Lead{} = lead -> {:ok, lead}
    end
  end

  @doc """
  Get a lead by id.

  Example:

  ```elixir
  {:ok, lead} = Leads.get_by_id("lead_id")
  {:error, :not_found} = Leads.get_by_id("lead_id")
  ```
  """
  @spec get_by_id(String.t()) :: {:ok, Lead.t()} | {:error, :not_found}
  def get_by_id(id) do
    case Repo.get_by(Lead, id: id) do
      nil -> {:error, :not_found}
      %Lead{} = lead -> {:ok, lead}
    end
  end

  @doc """
  Get a lead by id and tenant id.

  Example:

  ```elixir
  {:ok, lead} = Leads.get_by_id("tenant_id", "lead_id")
  {:error, :not_found} = Leads.get_by_id("tenant_id", "lead_id")
  ```
  """
  @spec get_by_id(tenant_id :: String.t(), lead_id :: String.t()) ::
          {:ok, Lead.t()} | {:error, :not_found}
  def get_by_id(tenant_id, lead_id) do
    case Repo.get_by(Lead, tenant_id: tenant_id, id: lead_id) do
      nil -> {:error, :not_found}
      %Lead{} = lead -> {:ok, lead}
    end
  end

  @doc """
  Get the domain for a lead company.

  Returns the domain string if successful, or an error tuple if the lead is not a company or not found.
  """

  def get_domain_for_lead_company(tenant_id, lead_id) do
    %LeadContext{lead_id: lead_id, tenant_id: tenant_id}
    |> fetch_lead()
    |> validate_company_type()
    |> fetch_company()
    |> extract_company_domain()
  end

  @doc """
  Get a lead by company ref id.

  Example:

  ```elixir
  {:ok, lead} = Leads.get_lead_by_company_ref("tenant_id", "company_ref_id")
  {:error, :not_found} = Leads.get_lead_by_company_ref("tenant_id", "company_ref_id")
  ```
  """
  @spec get_lead_by_company_ref(
          tenant_id :: String.t(),
          company_ref_id :: String.t()
        ) ::
          {:ok, Lead.t()} | {:error, :not_found}
  def get_lead_by_company_ref(tenant_id, ref_id) do
    case Repo.get_by(Lead, tenant_id: tenant_id, ref_id: ref_id, type: :company) do
      %Lead{} = lead -> {:ok, lead}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Lists all leads for a tenant.

  Example:

  ```elixir
  {:ok, leads} = Leads.list_by_tenant_id("123")
  {:error, :not_found} = Leads.list_by_tenant_id("123")
  ```
  """
  @spec list_by_tenant_id(tenant_id :: String.t()) ::
          {:ok, [Lead.t()]} | {:error, :not_found}
  def list_by_tenant_id(tenant_id) do
    leads = from(l in Lead, where: l.tenant_id == ^tenant_id) |> Repo.all()

    case leads do
      [] -> {:error, :not_found}
      leads -> {:ok, leads}
    end
  end

  @doc """
  Get a LeadView for a tenant. LeadView is a joined view of a lead with the necessary data to render in the UI.

  Example:

  ```elixir
  %{data: [%LeadView{}, ...], stage_counts: %{target: 0, education: 1, ...}, max_count: 0} = Leads.list_view_by_tenant_id("123")
  %{data: [%LeadView{}, ...], stage_counts: %{target: 0, education: 1, ...}, max_count: 0} = Leads.list_view_by_tenant_id("123", [desc: :stage])
  %{data: [%LeadView{}, ...], stage_counts: %{target: 0, education: 1, ...}, max_count: 0} = Leads.list_view_by_tenant_id("123", [asc: :stage])
  %{data: [%LeadView{}, ...], stage_counts: %{target: 0, education: 1, ...}, max_count: 0} = Leads.list_view_by_tenant_id("123", [desc: :inserted_at])
  %{data: %{target: [%LeadView{}, ...], education: [%LeadView{}, ...]}, stage_counts: %{target: 0, education: 1, ...}, max_count: 0} = Leads.list_view_by_tenant_id("123", [asc: :inserted_at], :stage)
  %{data: [%LeadView{}, ...], stage_counts: %{target: 0, education: 1, ...}, max_count: 0} = Leads.list_view_by_tenant_id("123", [desc: :inserted_at], nil, [stage: :target])

  [] = Leads.list_view_by_tenant_id("unknown_tenant_id")
  ```
  """
  @spec list_view_by_tenant_id(
          tenant_id :: String.t(),
          order_by :: order_by(),
          group_by :: :stage | nil,
          filter_by :: :stage | nil
        ) ::
          %{
            data: [LeadView.t()],
            stage_counts: %{Lead.lead_stage() => integer()},
            max_count: integer()
          }
          | %{
              data: %{stage: [LeadView.t()]},
              stage_counts: %{Lead.lead_stage() => integer()},
              max_count: integer()
            }
  def list_view_by_tenant_id(
        tenant_id,
        order_by \\ [desc: :inserted_at],
        group_by \\ nil,
        filter_by \\ nil
      ) do
    OpenTelemetry.Tracer.with_span "core.crm.leads:list_view_by_tenant_id" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", tenant_id}
      ])

      query_leads_view()
      |> where([l], l.tenant_id == ^tenant_id)
      |> where([l], l.type == :company)
      |> where([l], l.stage not in [:pending])
      |> where([l], not is_nil(l.stage))
      |> where([l], not is_nil(l.icp_fit))
      |> where([l], l.icp_fit != :not_a_fit)
      |> order(order_by)
      |> Repo.all()
      |> then(fn
        [] ->
          %{data: [], stage_counts: get_stage_counts([]), max_count: 0}

        leads ->
          output = Enum.map(leads, &parse_lead_view/1)

          stage_counts =
            case group_by do
              :stage ->
                output
                |> Enum.group_by(& &1.stage)
                |> Enum.map(fn {stage, leads} -> {stage, Enum.count(leads)} end)
                |> Map.new()

              _ ->
                Enum.reduce(output, %{}, fn lead, acc ->
                  Map.update(acc, lead.stage, 1, &(&1 + 1))
                end)
            end

          filtered_output =
            case filter_by do
              [stage: stage] ->
                Enum.filter(
                  output,
                  &(&1.stage == String.to_existing_atom(stage))
                )

              _ ->
                output
            end

          data =
            case group_by do
              :stage ->
                Enum.group_by(filtered_output, & &1.stage)

              _ ->
                filtered_output
            end

          %{
            data: data,
            stage_counts: stage_counts,
            max_count: Enum.count(output)
          }
      end)
    end
  end

  @doc """
  Gets a lead view by id.

  Example:

  ```elixir
  {:ok, lead_view} = Leads.get_view_by_id("123")
  {:error, :not_found} = Leads.get_view_by_id("123")
  ```
  """
  @spec get_view_by_id(String.t()) :: {:ok, LeadView.t()} | {:error, :not_found}
  def get_view_by_id(id) do
    query_leads_view()
    |> where([l], l.id == ^id)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      lead_data ->
        {:ok, parse_lead_view(lead_data)}
    end
  end

  @doc """
  Get all leads that are ICP fits without a stage.

  Example:

  ```elixir
  {:ok, leads} = Leads.get_icp_fits_without_stage()
  {:error, :not_found} = Leads.get_icp_fits_without_stage()
  ```
  """
  @spec get_icp_fits_without_stage() :: {:ok, [Lead.t()]} | {:error, :not_found}
  def get_icp_fits_without_stage() do
    Lead
    |> where([l], l.icp_fit in [:strong, :moderate])
    |> where([l], l.stage in [:pending, :target])
    |> Repo.all()
    |> then(fn
      [] -> {:error, :not_found}
      leads -> {:ok, leads}
    end)
  end

  @doc """
  Get or create a lead.

  Example:

  ```elixir
  {:ok, lead} = Leads.get_or_create("tenant_name", %{ref_id: "ref_id", type: :company})
  {:ok, lead} = Leads.get_or_create("tenant_name", %{ref_id: "ref_id", type: :company}, &my_callback/1)
  {:error, :not_found} = Leads.get_or_create("tenant_name", %{ref_id: "ref_id", type: :company})
  {:error, :domain_matches_tenant} = Leads.get_or_create("tenant_name", %{ref_id: "ref_id", type: :company})
  ```
  """
  @spec get_or_create(
          tenant_name :: String.t(),
          attrs :: map(),
          callback :: (Lead.t() -> any()) | nil,
          opts :: keyword() | nil
        ) ::
          {:ok, Lead.t()} | {:error, :not_found | :domain_matches_tenant}
  def get_or_create(tenant_name, attrs, callback \\ nil, opts \\ []) do
    OpenTelemetry.Tracer.with_span "leads.get_or_create_with_tenant_name" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.tenant.name", tenant_name},
        {"param.lead.ref_id", attrs.ref_id},
        {"param.with_callback", !is_nil(callback)}
      ])

      case Tenants.get_tenant_by_name(tenant_name) do
        {:error, :not_found} ->
          Tracing.error(:not_found)
          {:error, :not_found}

        {:ok, tenant} ->
          case get_by_ref_id(tenant.id, attrs.ref_id) do
            {:error, :not_found} ->
              create_lead(tenant, attrs, callback, opts)

            {:ok, lead} ->
              {:ok, lead}
          end
      end
    end
  end

  def get_or_create_with_tenant_id(
        tenant_id,
        attrs,
        callback \\ nil,
        opts \\ []
      ) do
    OpenTelemetry.Tracer.with_span "leads.get_or_create_with_tenant_id" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.tenant.id", tenant_id},
        {"param.lead.ref_id", attrs.ref_id},
        {"param.with_callback", !is_nil(callback)}
      ])

      case Tenants.get_tenant_by_id(tenant_id) do
        {:error, :not_found} ->
          Tracing.error(:not_found)
          {:error, :not_found}

        {:ok, tenant} ->
          case get_by_ref_id(tenant.id, attrs.ref_id) do
            {:error, :not_found} ->
              create_lead(tenant, attrs, callback, opts)

            {:ok, lead} ->
              {:ok, lead}
          end
      end
    end
  end

  defp create_lead(tenant, attrs, callback, opts) do
    with {:ok, company} <- Companies.get_by_id(attrs.ref_id),
         false <- company.primary_domain == tenant.domain do
      case %Lead{}
           |> Lead.changeset(%{
             tenant_id: tenant.id,
             ref_id: attrs.ref_id,
             type: attrs.type,
             stage: Map.get(attrs, :stage, :pending),
             icp_fit: Map.get(attrs, :icp_fit),
             just_created: true
           })
           |> Repo.insert() do
        {:ok, lead} ->
          after_insert_start(lead, callback, opts)
          {:ok, lead}

        {:error, %Ecto.Changeset{errors: errors}} ->
          # Check if this is a unique constraint violation
          if has_unique_constraint_error?(errors) do
            # Lead already exists, fetch it
            case get_by_ref_id(tenant.id, attrs.ref_id) do
              {:ok, existing_lead} -> {:ok, existing_lead}
              {:error, reason} -> {:error, reason}
            end
          else
            {:error, :validation_failed}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :not_found} -> {:error, :not_found}
      true -> {:error, :domain_matches_tenant}
    end
  end

  @doc """
  Update a lead.

  Example:

  ```elixir
  {:ok, lead} = Leads.update_lead(lead, %{stage: :target})
  {:error, :not_found} = Leads.update_lead(lead, %{stage: :target})
  ```
  """
  @spec update_lead(Lead.t(), attrs :: map()) ::
          {:ok, Lead.t()} | {:error, :not_found}
  def update_lead(%Lead{} = lead, attrs) do
    lead
    |> Lead.changeset(attrs)
    |> Repo.update()
    |> tap(fn {:ok, result} -> LeadNotifier.notify_lead_updated(result) end)
  end

  @doc """
  Marks an attempt for a lead by updating the attempt timestamp and incrementing the attempts counter.

  Example:

  ```elixir
  {:ok, :ok} = Leads.mark_icp_fit_attempt("lead_id")
  {:error, :update_failed} = Leads.mark_icp_fit_attempt("lead_id")
  ```
  """
  @spec mark_icp_fit_attempt(lead_id :: String.t()) ::
          :ok | {:error, :update_failed}
  def mark_icp_fit_attempt(lead_id) do
    case Repo.update_all(
           from(l in Lead, where: l.id == ^lead_id),
           set: [icp_fit_evaluation_attempt_at: DateTime.utc_now()],
           inc: [icp_fit_evaluation_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(:update_failed)
        Logger.error("Failed to mark attempt for lead #{lead_id}")
        {:error, :update_failed}

      {_count, _} ->
        :ok
    end
  end

  def mark_brief_create_attempt(lead_id) do
    case Repo.update_all(
           from(l in Lead, where: l.id == ^lead_id),
           set: [brief_create_attempt_at: DateTime.utc_now()],
           inc: [brief_create_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(
          :update_failed,
          "Failed to mark attempt for lead #{lead_id}",
          lead_id: lead_id
        )

        {:error, :update_failed}

      {_count, _} ->
        :ok
    end
  end

  # Private functions

  defp after_insert_start(result, callback, opts) do
    Task.start(fn ->
      LeadNotifier.notify_lead_created(result)
    end)

    Core.Crm.Leads.NewLeadPipeline.start(
      result.id,
      result.tenant_id,
      callback,
      opts
    )
  end

  defp fetch_lead(%LeadContext{} = ctx) do
    case get_by_id(ctx.tenant_id, ctx.lead_id) do
      {:ok, lead} -> {:ok, %{ctx | lead: lead}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_company_type(
         {:ok, %LeadContext{lead: %{type: :company}} = ctx}
       ),
       do: {:ok, ctx}

  defp validate_company_type({:ok, _}), do: {:error, :not_a_company}
  defp validate_company_type({:error, reason}), do: {:error, reason}

  defp fetch_company({:ok, %LeadContext{lead: lead} = ctx}) do
    case Companies.get_by_id(lead.ref_id) do
      {:ok, company} -> {:ok, %{ctx | company: company}}
      {:error, :not_found} -> :stop
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_company({:error, reason}), do: {:error, reason}

  defp extract_company_domain({:ok, %LeadContext{company: company}}) do
    {:ok, company.primary_domain}
  end

  defp extract_company_domain({:error, reason}), do: {:error, reason}

  defp query_leads_view() do
    latest_doc =
      from rd in "refs_documents",
        group_by: rd.ref_id,
        select: %{
          ref_id: rd.ref_id,
          document_id: max(rd.document_id)
        }

    from(l in Lead,
      join: c in Company,
      on: c.id == l.ref_id,
      left_join: rd in subquery(latest_doc),
      on: rd.ref_id == l.id,
      select: %{
        id: l.id,
        ref_id: l.ref_id,
        icp_fit: l.icp_fit,
        type: l.type,
        stage: l.stage,
        name: c.name,
        industry: c.industry,
        domain: c.primary_domain,
        country: c.country_a2,
        icon_key: c.icon_key,
        document_id: rd.document_id,
        inserted_at: l.inserted_at
      }
    )
  end

  defp order(query, by) do
    case by do
      [desc: :inserted_at] ->
        order_by(query, [l], desc: l.inserted_at)

      [asc: :inserted_at] ->
        order_by(query, [l], asc: l.inserted_at)

      [desc: :stage] ->
        order_by(query, [l], desc: l.stage)

      [asc: :stage] ->
        order_by(query, [l], asc: l.stage)

      [asc: field] when field in [:name, :industry, :country] ->
        order_by_nullable_field(query, :asc, field)

      [desc: field] when field in [:name, :industry, :country] ->
        order_by_nullable_field(query, :desc, field)

      _ ->
        order_by(query, [l], desc: l.inserted_at)
    end
  end

  defp order_by_nullable_field(query, :asc, :name) do
    order_by(query, [l, c],
      asc:
        fragment(
          "CASE WHEN ? IS NULL OR ? = '' THEN 1 ELSE 0 END, ?",
          c.name,
          c.name,
          c.name
        )
    )
  end

  defp order_by_nullable_field(query, :desc, :name) do
    order_by(query, [l, c],
      desc:
        fragment(
          "CASE WHEN ? IS NULL OR ? = '' THEN 1 ELSE 0 END, ?",
          c.name,
          c.name,
          c.name
        )
    )
  end

  defp order_by_nullable_field(query, :asc, :industry) do
    order_by(query, [l, c],
      asc:
        fragment(
          "CASE WHEN ? IS NULL OR ? = '' THEN 1 ELSE 0 END, ?",
          c.industry,
          c.industry,
          c.industry
        )
    )
  end

  defp order_by_nullable_field(query, :desc, :industry) do
    order_by(query, [l, c],
      desc:
        fragment(
          "CASE WHEN ? IS NULL OR ? = '' THEN 1 ELSE 0 END, ?",
          c.industry,
          c.industry,
          c.industry
        )
    )
  end

  defp order_by_nullable_field(query, :asc, :country) do
    order_by(query, [l, c],
      asc:
        fragment(
          "CASE WHEN ? IS NULL OR ? = '' THEN 1 ELSE 0 END, ?",
          c.country_a2,
          c.country_a2,
          c.country_a2
        )
    )
  end

  defp order_by_nullable_field(query, :desc, :country) do
    order_by(query, [l, c],
      desc:
        fragment(
          "CASE WHEN ? IS NULL OR ? = '' THEN 1 ELSE 0 END, ?",
          c.country_a2,
          c.country_a2,
          c.country_a2
        )
    )
  end

  defp parse_lead_view(lead_view_data) when is_map(lead_view_data) do
    icon = Images.get_cdn_url(lead_view_data.icon_key)

    country_name =
      if lead_view_data.country do
        case Countriex.get_by(:alpha2, lead_view_data.country) do
          %{name: name} -> name
          _ -> nil
        end
      else
        nil
      end

    struct(
      LeadView,
      Map.merge(lead_view_data, %{
        icon: icon,
        country_name: country_name
      })
    )
  end

  defp parse_lead_view(lead_view) when is_struct(lead_view, LeadView) do
    lead_view
  end

  defp parse_lead_view(_), do: {:error, :invalid_lead_view}

  defp get_stage_counts(leads) do
    Enum.reduce(leads, %{}, fn lead, acc ->
      Map.update(acc, lead.stage, 1, &(&1 + 1))
    end)
  end

  defp has_unique_constraint_error?(errors) do
    Enum.any?(errors, fn
      {_, {"has already been taken", _}} -> true
      _ -> false
    end)
  end
end
