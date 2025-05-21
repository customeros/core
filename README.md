# Working with CustomerOS

## First Install (OSX)

```bash
brew install elixir
brew install postgresql@14
brew install nats-server
curl -fsSL https://bun.sh/install | bash
exec /bin/zsh
bun install
```

## Setup

```bash
brew services start postgresql@14
createdb openline
createuser -s postgres
export POSTGRES_PORT=5432
echo 'export POSTGRES_PORT=5432' >> ~/.zshrc
brew services start nats-server
mix setup
```

## Run

```bash
mix dev
```

### Interactive Mode

```bash
iex -S mix
```

## Teardown

```bash
brew services stop postgresql@14
brew services stop nats-server
```

# Code Style Guide

- Don't ship code with warnings!
- All public functions have guards
- All unused variables are named with underscore prefix

## Standardized libs

- Http client -> Finch
