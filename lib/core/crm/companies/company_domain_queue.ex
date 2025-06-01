defmodule Core.Crm.Companies.CompanyDomainQueue do
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
