defmodule Core.Utils.Cron.CronLock do
  @moduledoc """
  Schema module for managing cron job locking.

  This schema represents a locking mechanism for cron jobs to prevent
  multiple instances of the same job from running simultaneously.
  It tracks which cron jobs are currently locked and when they were locked.
  """

  use Ecto.Schema

  @cron_names [
    :cron_company_domain_processor,
    :cron_company_enricher,
    :cron_session_closer
  ]

  @type cron_name :: unquote(Enum.reduce(@cron_names, &{:|, [], [&1, &2]}))

  @type t :: %__MODULE__{
          id: integer() | nil,
          cron_name: cron_name(),
          lock: String.t() | nil,
          locked_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "cron_locking" do
    field(:cron_name, Ecto.Enum, values: @cron_names)
    field(:lock, :string)
    field(:locked_at, :utc_datetime)

    timestamps()
  end

  @doc """
  Returns the list of valid cron names.
  """
  @spec valid_cron_names() :: [cron_name()]
  def valid_cron_names, do: @cron_names
end
