defmodule :"Elixir.Core.Repo.Migrations.Add-url-normalization-function" do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION extract_root_domain(input_url text)
    RETURNS text AS $$
    DECLARE
      hostname text;
      parts text[];
    BEGIN
      -- Strip protocol and path to isolate the hostname
      hostname := split_part(REGEXP_REPLACE(input_url, '^https?://', ''), '/', 1);

      -- Reverse and split on dot
      parts := string_to_array(reverse(hostname), '.');

      IF array_length(parts, 1) >= 2 THEN
        RETURN lower(reverse(parts[1]) || '.' || reverse(parts[2]));
      ELSE
        RETURN lower(hostname); -- fallback if malformed domain
      END IF;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """)
  end

  def down do
    execute("DROP FUNCTION IF EXISTS extract_root_domain(text);")
  end
end
