defmodule Mix.Tasks.Wkhtmltopdf.Install do
  @moduledoc """
  Mix task for installing wkhtmltopdf binary.

  This task ensures that wkhtmltopdf is installed and available in the system PATH.
  It downloads and launches the official wkhtmltopdf .pkg installer for macOS.

  ## Usage

      mix wkhtmltopdf.install

  ## Requirements

  - macOS
  """

  use Mix.Task

  @shortdoc "Installs wkhtmltopdf binary"
  @wkhtmltopdf_url "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-2/wkhtmltox-0.12.6-2.macos-cocoa.pkg"
  @pkg_filename "wkhtmltox-0.12.6-2.macos-cocoa.pkg"

  def run(_args) do
    Mix.shell().info("Checking wkhtmltopdf installation...")

    case System.cmd("which", ["wkhtmltopdf"]) do
      {_, 0} ->
        Mix.shell().info(
          "wkhtmltopdf is already installed and available in PATH"
        )

      _ ->
        Mix.shell().info("wkhtmltopdf not found. Downloading and installing...")

        # Create temp directory
        {:ok, temp_dir} = Temp.mkdir("wkhtmltopdf_install")
        pkg_path = Path.join(temp_dir, @pkg_filename)

        # Download the .pkg file
        Mix.shell().info("Downloading wkhtmltopdf installer...")

        case download_file(@wkhtmltopdf_url, pkg_path) do
          :ok ->
            Mix.shell().info("Download complete. Launching installer...")

            Mix.shell().info(
              "Please follow the installation wizard to complete the installation."
            )

            Mix.shell().info(
              "After installation is complete, run this command again to verify the installation."
            )

            launch_installer(pkg_path)

          {:error, reason} ->
            Mix.shell().error("Failed to download wkhtmltopdf: #{reason}")
            Mix.raise("wkhtmltopdf installation failed")
        end
    end
  end

  defp download_file(url, path) do
    case System.cmd("curl", ["-L", "-o", path, url], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> {:error, error}
    end
  end

  defp launch_installer(pkg_path) do
    case System.cmd("open", [pkg_path], stderr_to_stdout: true) do
      {_, 0} ->
        Mix.shell().info("Installer launched successfully")

        Mix.raise(
          "Please complete the installation in the GUI and run this command again to verify"
        )

      {error, _} ->
        Mix.shell().error("Failed to launch installer: #{error}")
        Mix.raise("wkhtmltopdf installation failed")
    end
  end
end
