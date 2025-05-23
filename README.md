# Working with CustomerOS

## First Install (OSX)

```bash
brew install elixir
brew install postgresql@17
curl -fsSL https://bun.sh/install | bash
exec /bin/zsh
bun install
```

## Setup

```bash
brew services start postgresql@17
createdb customeros
createuser -s postgres
export POSTGRES_PORT=5555
echo 'export POSTGRES_PORT=5555' >> ~/.zshrc
mix setup
```

## Upgrade

```bash
dropdb customeros
createdb customeros
mix deps.get
mix ecto.migrate
mix setup
```

## Database migrations

```base
mix ecto.gen.migration {migration name}
```

## Run

```bash
mix dev
```

### Interactive Mode

```bash
iex -S mix
```

## Test

```bash
mix test
```

Use the `--cover` flag to generate a test coverage report

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
