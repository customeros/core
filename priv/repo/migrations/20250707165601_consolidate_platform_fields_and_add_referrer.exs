defmodule Core.Repo.Migrations.ConsolidatePlatformFieldsAndAddReferrer do
  use Ecto.Migration

  def up do
    alter table(:web_sessions) do
      add :platform, :string
      add :referrer, :text
    end

    execute """
    UPDATE web_sessions 
    SET platform = search_platform 
    WHERE search_platform IS NOT NULL
    """

    execute """
    UPDATE web_sessions 
    SET platform = social_platform 
    WHERE social_platform IS NOT NULL
    """

    alter table(:web_sessions) do
      remove :search_platform
      remove :social_platform
    end
  end

  def down do
    alter table(:web_sessions) do
      add :search_platform, :string
      add :social_platform, :string
    end

    alter table(:web_sessions) do
      remove :platform
      remove :referrer
    end
  end
end
