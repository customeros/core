defmodule Mix.Tasks.Imagemagick.Install do
  @moduledoc """
  Mix task for installing ImageMagick binary.

  This task ensures that ImageMagick is installed and available in the system PATH.
  It downloads and installs ImageMagick using the appropriate package manager for the OS.

  ## Usage

      mix imagemagick.install

  ## Requirements

  - macOS, Linux, or Windows
  """

  use Mix.Task

  @shortdoc "Installs ImageMagick binary"
  @imagemagick_version "7.1.1-28"

  def run(_args) do
    Mix.shell().info("Checking ImageMagick installation...")

    case System.cmd("which", ["convert"]) do
      {_, 0} ->
        case System.cmd("convert", ["-version"]) do
          {version, 0} ->
            Mix.shell().info(
              "✅ ImageMagick is already installed and available in PATH"
            )

            Mix.shell().info(
              "Version: #{version |> String.split("\n") |> List.first()}"
            )

          _ ->
            Mix.shell().error(
              "❌ ImageMagick is installed but not working properly"
            )

            print_installation_instructions()
        end

      _ ->
        Mix.shell().info("ImageMagick not found. Installing...")
        install_imagemagick()
    end
  end

  defp install_imagemagick do
    case :os.type() do
      {:unix, :darwin} ->
        install_on_macos()

      {:unix, :linux} ->
        install_on_linux()

      {:win32, _} ->
        install_on_windows()

      _ ->
        Mix.shell().error("❌ Unsupported operating system")
        print_installation_instructions()
    end
  end

  defp install_on_macos do
    Mix.shell().info("Installing ImageMagick on macOS...")

    case System.cmd("brew", ["install", "imagemagick"]) do
      {_, 0} ->
        Mix.shell().info("✅ ImageMagick installed successfully")
        verify_installation()

      {error, _} ->
        Mix.shell().error("❌ Failed to install ImageMagick: #{error}")
        print_installation_instructions()
    end
  end

  defp install_on_linux do
    Mix.shell().info("Installing ImageMagick on Linux...")

    # Try apt-get first (Debian/Ubuntu)
    case System.cmd("which", ["apt-get"]) do
      {_, 0} ->
        case System.cmd("sudo", ["apt-get", "update"]) do
          {_, 0} ->
            case System.cmd("sudo", ["apt-get", "install", "-y", "imagemagick"]) do
              {_, 0} ->
                Mix.shell().info("✅ ImageMagick installed successfully")
                verify_installation()

              {error, _} ->
                Mix.shell().error("❌ Failed to install ImageMagick: #{error}")
                print_installation_instructions()
            end

          {error, _} ->
            Mix.shell().error("❌ Failed to update package list: #{error}")
            print_installation_instructions()
        end

      _ ->
        # Try yum (CentOS/RHEL)
        case System.cmd("which", ["yum"]) do
          {_, 0} ->
            case System.cmd("sudo", ["yum", "install", "-y", "ImageMagick"]) do
              {_, 0} ->
                Mix.shell().info("✅ ImageMagick installed successfully")
                verify_installation()

              {error, _} ->
                Mix.shell().error("❌ Failed to install ImageMagick: #{error}")
                print_installation_instructions()
            end

          _ ->
            Mix.shell().error("❌ No supported package manager found")
            print_installation_instructions()
        end
    end
  end

  defp install_on_windows do
    Mix.shell().info("""
    Please install ImageMagick on Windows manually:

    1. Download the installer from https://imagemagick.org/script/download.php
    2. Run the installer and follow the instructions
    3. Make sure to check "Add application directory to your system path" during installation
    4. Restart your terminal after installation

    After installation, run this command again to verify the installation.
    """)
  end

  defp verify_installation do
    case System.cmd("convert", ["-version"]) do
      {version, 0} ->
        Mix.shell().info("✅ ImageMagick installation verified")

        Mix.shell().info(
          "Version: #{version |> String.split("\n") |> List.first()}"
        )

      _ ->
        Mix.shell().error("❌ ImageMagick installation verification failed")
        print_installation_instructions()
    end
  end

  defp print_installation_instructions do
    Mix.shell().info("""
    To install ImageMagick manually, follow these instructions:

    ## macOS
    Using Homebrew:
        brew install imagemagick

    ## Ubuntu/Debian
        sudo apt-get update
        sudo apt-get install imagemagick

    ## CentOS/RHEL
        sudo yum install ImageMagick

    ## Windows
    1. Download the installer from https://imagemagick.org/script/download.php
    2. Run the installer and follow the instructions
    3. Make sure to check "Add application directory to your system path" during installation

    After installation, restart your terminal and run this command again to verify the installation.
    """)
  end
end
