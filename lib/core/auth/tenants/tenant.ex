defmodule Core.Auth.Tenants.Tenant do
  @moduledoc """
  Schema module representing a tenant in the authentication system.
  A tenant represents a workspace or organization in the system, with properties
  including name, primary_domain, domains array, and workspace details. Each tenant has a unique ID
  and is used to segregate data and users across different organizations.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :primary_domain,
             :domains,
             :workspace_name,
             :workspace_icon_key,
             :webtracker_status,
             :inserted_at,
             :updated_at
           ]}

  @primary_key {:id, :string, autogenerate: false}
  schema "tenants" do
    field(:name, :string)
    field(:primary_domain, :string)
    field(:domains, {:array, :string}, default: [])
    field(:workspace_name, :string)
    field(:workspace_icon_key, :string)
    field(:webtracker_status, Ecto.Enum, values: [:available, :not_available])
    field(:products, {:array, :string}, default: [])

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          primary_domain: String.t(),
          domains: [String.t()],
          workspace_name: String.t(),
          workspace_icon_key: String.t(),
          webtracker_status: Ecto.Enum.t(),
          products: [String.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  def changeset(%__MODULE__{} = tenant, attrs) do
    tenant
    |> cast(attrs, [
      :id,
      :name,
      :primary_domain,
      :domains,
      :workspace_name,
      :workspace_icon_key,
      :webtracker_status,
      :products
    ])
    |> maybe_put_id()
    |> validate_required([:id, :name, :primary_domain])
    |> validate_length(:name, max: 160)
    |> validate_length(:workspace_name, max: 160)
    |> validate_domains()
    |> unique_constraint(:name)
  end

  defp validate_domains(changeset) do
    domains = get_field(changeset, :domains, [])
    primary_domain = get_field(changeset, :primary_domain)

    changeset
    |> validate_change(:domains, fn :domains, domains ->
      if Enum.all?(domains, &is_binary/1) do
        []
      else
        [domains: "all domains must be strings"]
      end
    end)
    |> maybe_add_primary_to_domains(primary_domain, domains)
  end

  defp maybe_add_primary_to_domains(changeset, primary_domain, domains)
       when is_binary(primary_domain) do
    if primary_domain in domains do
      changeset
    else
      put_change(changeset, :domains, [primary_domain | domains])
    end
  end

  defp maybe_add_primary_to_domains(changeset, _primary_domain, _domains),
    do: changeset

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Core.Utils.IdGenerator.generate_id_16("tenant"))
  end

  defp maybe_put_id(changeset), do: changeset
end
