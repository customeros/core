defmodule Core.Auth.PersonalEmailProviders.PersonalEmailProvider do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}
  schema "personal_email_providers" do
    field(:domain, :string)
    field(:inserted_at, :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: integer(),
          domain: String.t(),
          inserted_at: DateTime.t()
        }

  def changeset(personal_email_provider, attrs) do
    personal_email_provider
    |> cast(attrs, [:domain])
    |> validate_required([:domain])
    |> unique_constraint(:domain)
  end
end
