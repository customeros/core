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
Core.Repo.query!(File.read!("priv/repo/seeds/tenants.sql"))
Core.Repo.query!(File.read!("priv/repo/seeds/companies.sql"))
Core.Repo.query!(File.read!("priv/repo/seeds/leads.sql"))
Core.Repo.query!(File.read!("priv/repo/seeds/users.sql"))
