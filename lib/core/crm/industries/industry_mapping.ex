defmodule Core.Crm.Industries.IndustryMapping do
  @moduledoc """
  Schema module for industry mappings.

  This module defines a mapping between a source industry code (e.g. from an external source) and a target industry code (e.g. our internal code).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "industry_mappings" do
    field(:code_source, :string)
    field(:code_target, :string)
    field(:inserted_at, :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: integer() | nil,
          code_source: String.t(),
          code_target: String.t(),
          inserted_at: DateTime.t() | nil
        }

  def changeset(industry_mapping, attrs) do
    industry_mapping
    |> cast(attrs, [:code_source, :code_target])
    |> validate_required([:code_source, :code_target])
  end
end
