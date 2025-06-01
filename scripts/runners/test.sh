#!/usr/bin/env bash

export MIX_ENV=test

echo "SECRET_KEY_BASE=$(mix phx.gen.secret)"

echo "==> Fetching and compiling Elixir dependencies..."
mix deps.get --only $MIX_ENV
mkdir -p config

mix deps.compile
mix compile

echo "==> Running tests..."
mix test --no-compile
mix format --check-formatted
