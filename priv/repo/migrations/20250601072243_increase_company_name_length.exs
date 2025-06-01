defmodule Core.Repo.Migrations.IncreaseCompanyNameLength do
  use Ecto.Migration

  def up do
    # Change the column type to varchar(1000)
    execute "ALTER TABLE companies ALTER COLUMN name TYPE varchar(1000)"
  end

  def down do
    # Revert back to varchar(255)
    execute "ALTER TABLE companies ALTER COLUMN name TYPE varchar(255)"
  end
end
