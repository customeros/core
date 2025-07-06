defmodule Core.Repo.Migrations.AddIcpUnknownToLeads do
  use Ecto.Migration

  def up do
    execute "ALTER TYPE icp_fit ADD VALUE IF NOT EXISTS 'unknown'"
  end
end
