defmodule Core.Repo.Migrations.ExtendCompaniesTableWithQuantitativeColumns do
  use Ecto.Migration

  def up do
    # Create the business_model enum type
    execute(
      "CREATE TYPE business_model AS ENUM ('B2B', 'B2C', 'B2B2C', 'Hybrid')"
    )

    alter table(:companies) do
      add(:technologies_used, {:array, :string}, default: [])
      add(:city, :string)
      add(:region, :string)
      add(:business_model, :business_model, null: true)
      add(:employee_count, :integer)

      add(:business_model_enrichment_attempts, :integer,
        default: 0,
        null: false
      )

      add(:business_model_enrich_attempt_at, :utc_datetime)
    end

    create(index(:companies, [:business_model]))
    create(index(:companies, [:employee_count]))
  end

  def down do
    # Drop indexes first
    drop(index(:companies, [:business_model]))
    drop(index(:companies, [:employee_count]))

    alter table(:companies) do
      remove(:technologies_used)
      remove(:city)
      remove(:region)
      remove(:business_model)
      remove(:employee_count)
      remove(:business_model_enrichment_attempts)
      remove(:business_model_enrich_attempt_at)
    end

    # Drop the business_model enum type
    execute("DROP TYPE business_model")
  end
end
