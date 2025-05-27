defmodule Mix.Tasks.Compile.Script do
  use Mix.Task

  @shortdoc "Compiles the TypeScript scripts using Bun"

  def run(_) do
    if running_in_elixirls?() do
      Mix.shell().info("Skipping TypeScript compilation in ElixirLS")
    end

    Mix.shell().info("Compiling TypeScript scripts with Bun...")

    # Define script and output paths
    script_dir = Path.expand("scripts")
    output_dir = Path.expand("priv/scripts")

    # List of scripts to compile
    scripts = [
      "convert_lexical_to_yjs.ts",
      "convert_md_to_lexical.ts"
    ]

    # Ensure priv/scripts exists
    File.mkdir_p!(output_dir)

    # Compile each script
    Enum.each(scripts, fn script_name ->
      script_path = Path.join(script_dir, script_name)

      output_path =
        Path.join(output_dir, String.replace(script_name, ".ts", ""))

      # Run the Bun build command and capture output
      command =
        "cd #{script_dir} && bun build #{script_path} --compile --outfile=#{output_path}"

      {output, exit_code} =
        System.cmd("sh", ["-c", command], stderr_to_stdout: true)

      # Print output for debugging
      Mix.shell().info(output)

      if exit_code == 0 do
        Mix.shell().info(
          "✅ Successfully compiled #{script_name} to #{output_path}"
        )
      else
        Mix.raise(
          "❌ Failed to compile #{script_name}.\n\nError output:\n#{output}"
        )
      end
    end)
  end

  defp running_in_elixirls? do
    System.get_env("ELIXIR_LS") == "true"
  end
end
