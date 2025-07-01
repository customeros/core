defmodule Core.Crm.Leads.LeadDomainQueue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lead_domain_queues" do
    field :tenant_id, :string
    field :domain, :string
    field :rank, :integer
    field :processed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(lead_domain_queue, attrs) do
    lead_domain_queue
    |> cast(attrs, [:tenant_id, :domain, :rank, :processed_at])
    |> validate_required([:tenant_id, :domain])
  end
end
