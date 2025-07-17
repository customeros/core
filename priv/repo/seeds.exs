# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Core.Repo.insert!(%Core.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Execute SQL files using the repo directly
try do
  Core.Repo.query!("DELETE FROM contacts")
  Core.Repo.query!("DELETE FROM leads")
  Core.Repo.query!("DELETE FROM companies")
  Core.Repo.query!("DELETE FROM tenants")
  Core.Repo.query!("DELETE FROM target_personas")
  Core.Repo.query!(File.read!("priv/repo/seeds/tenants.sql"))
  Core.Repo.query!(File.read!("priv/repo/seeds/companies.sql"))
  Core.Repo.query!(File.read!("priv/repo/seeds/leads.sql"))
  Core.Repo.query!(File.read!("priv/repo/seeds/contacts.sql"))
  Core.Repo.query!(File.read!("priv/repo/seeds/target_personas.sql"))
rescue
  e ->
    IO.puts("Error: #{inspect(e)}")
end
