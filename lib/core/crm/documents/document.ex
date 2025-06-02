defmodule Core.Crm.Documents.Document do
  @moduledoc """
  Defines the Document schema and related functions for document management.

  This module manages:
  * Document schema definition
  * Changeset validation
  * Document creation and updates
  * Account brief generation
  * Document metadata handling

  It provides the core schema and functions for managing documents
  in the system, including collaborative documents and account briefs.
  The module handles document validation, ID generation, and proper
  serialization of document data.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :body,
             :lexical_state,
             :tenant_id,
             :user_id,
             :icon,
             :color,
             :ref_id,
             :inserted_at,
             :updated_at
           ]}
  @primary_key {:id, :string, autogenerate: false}
  schema "documents" do
    field(:name, :string)
    field(:body, :string)
    field(:lexical_state, :string)
    field(:tenant_id, :string)
    field(:user_id, :string)
    field(:icon, :string)
    field(:color, :string)
    field(:ref_id, :string, virtual: true)

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :name,
      :body,
      :lexical_state,
      :tenant_id,
      :user_id,
      :icon,
      :color
    ])
    |> maybe_put_id()
    |> validate_required([:name, :tenant_id, :body, :user_id, :icon, :color])
  end

  def update_changeset(document, attrs) do
    document
    |> cast(attrs, [:id, :name, :icon, :color])
    |> validate_required([:id, :name, :icon, :color])
  end

  def new_account_brief(tenant_id, lead_id, body) do
    %{
      id: Core.Utils.IdGenerator.generate_id_16("doc"),
      tenant_id: tenant_id,
      user_id: "system",
      name: "Account Brief",
      body: body,
      icon: "check-01",
      color: "#1b1b1b",
      ref_id: lead_id
    }
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(
      changeset,
      :id,
      Core.Utils.IdGenerator.generate_id_16("doc")
    )
  end

  defp maybe_put_id(changeset), do: changeset
end
