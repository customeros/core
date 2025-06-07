#!/usr/bin/env bash
set -euo pipefail

APP_PATH=$1

cd $APP_PATH

export MIX_ENV=prod
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

echo "==> Ensuring dependencies are installed..."

# Ensure Elixir tools are installed
mix local.hex --force
mix local.rebar --force

echo "==> Installing JS dependencies and building Bun scripts..."
cd scripts
bun install
bun build --compile convert_lexical_to_yjs.ts --output convert_lexical_to_yjs
bun build --compile convert_md_to_lexical.ts --output convert_md_to_lexical

mkdir -p ../priv/scripts
mv convert_lexical_to_yjs ../priv/scripts/
mv convert_md_to_lexical ../priv/scripts/
cd ..

echo "==> Compiling..."
mix deps.get --only $MIX_ENV
mkdir -p config

mix deps.compile
mix clean
mix compile

echo "==> Building release..."
mix release

echo "==> Build complete. Release output at: _build/prod/rel/core"
