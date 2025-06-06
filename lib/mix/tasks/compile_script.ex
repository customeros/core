defmodule Mix.Tasks.Compile.Script do
  @moduledoc """
  Mix task for compiling TypeScript scripts using Bun.

  This task manages the compilation of TypeScript scripts into executable JavaScript
  files. It handles:

  - Compilation of TypeScript files using Bun
  - Support for multiple script files
  - Output directory management
  - Build process monitoring
  - Error handling and reporting
  - ElixirLS integration

  The task compiles scripts from the scripts/ directory into the priv/scripts/
  directory, making them available for use in the application.
  """

  use Mix.Task

  @shortdoc "Compiles the TypeScript scripts using Bun"

  def run(_) do
    if running_in_elixirls?() do
      Mix.shell().info("Skipping TypeScript compilation in ElixirLS")
    end

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

      if exit_code == 0 do
        Mix.shell().info(
          "Successfully compiled #{script_name} to #{output_path}"
        )
      else
        Mix.raise(
          "Failed to compile #{script_name}.\n\nError output:\n#{output}"
        )
      end
    end)
  end

  defp running_in_elixirls? do
    System.get_env("ELIXIR_LS") == "true"
  end
end
