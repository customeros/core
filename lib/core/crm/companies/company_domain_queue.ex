defmodule Core.Crm.Companies.CompanyDomainQueue do
  @moduledoc """
  Schema module for managing the queue of company domains to be processed.

  This schema tracks domains that need to be processed for company enrichment,
  including their insertion time and processing status. It's used to manage
  the asynchronous processing of company data enrichment.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "company_domain_queues" do
    field(:domain, :string)
    field(:inserted_at, :utc_datetime)
    field(:processed_at, :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: integer(),
          domain: String.t(),
          inserted_at: DateTime.t(),
          processed_at: DateTime.t()
        }

  def changeset(queue, attrs) do
    queue
    |> cast(attrs, [:domain])
    |> validate_required([:domain])
  end
end
