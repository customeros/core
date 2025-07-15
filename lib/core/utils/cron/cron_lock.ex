defmodule Core.Utils.Cron.CronLock do
  @moduledoc """
  Schema module for managing cron job locking.

  This schema represents a locking mechanism for cron jobs to prevent
  multiple instances of the same job from running simultaneously.
  It tracks which cron jobs are currently locked, when they were locked,
  and when they were last executed.
  """

  use Ecto.Schema

  @cron_names [
    :cron_analytics_processor,
    :cron_better_contact_job_checker,
    :cron_brief_creator,
    :cron_company_domain_processor,
    :cron_company_enricher,
    :cron_company_scrapin_enricher,
    :cron_daily_lead_summary_sender,
    :cron_hubspot_company_sync,
    :cron_icp_fit_evaluator,
    :cron_lead_creator,
    :cron_magic_link_usage_checker,
    :cron_session_closer,
    :cron_stage_evaluator,
    :cron_target_persona_linkedin_processor,
    :cron_google_ads_campaign_fetcher
  ]

  @type cron_name :: unquote(Enum.reduce(@cron_names, &{:|, [], [&1, &2]}))

  @type t :: %__MODULE__{
          id: integer() | nil,
          cron_name: cron_name(),
          lock: String.t() | nil,
          locked_at: DateTime.t() | nil,
          last_execution_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "cron_locking" do
    field(:cron_name, Ecto.Enum, values: @cron_names)
    field(:lock, :string)
    field(:locked_at, :utc_datetime)
    field(:last_execution_at, :utc_datetime)

    timestamps()
  end

  @doc """
  Returns the list of valid cron names.
  """
  @spec valid_cron_names() :: [cron_name()]
  def valid_cron_names, do: @cron_names
end
