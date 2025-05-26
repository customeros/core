# CustomerOS Core

A Phoenix-based application for customer relationship management and business intelligence.

## Prerequisites

Before setting up the project, ensure you have the following installed:

- **Elixir** (>= 1.18)
- **Node.js** (for asset compilation)
- **Docker & Docker Compose** (for PostgreSQL)

## First Install (macOS)

```bash
# Install Elixir
brew install elixir

# Install Node.js (if not already installed)
brew install node

# Verify installations
elixir --version
node --version
```

## Setup

### 1. Start PostgreSQL with Docker Compose

```bash
# Start PostgreSQL in the background
docker compose up -d postgres

# Verify PostgreSQL is running
docker compose ps
```

### 2. Setup the Application

```bash
# Install dependencies and setup database
mix setup

# This command runs:
# - mix deps.get (install Elixir dependencies)
# - mix ecto.setup (create database and run migrations)
```

The `mix setup` command will automatically:

- Install Elixir dependencies
- Create the database
- Run all migrations

## Development

### Run the Application

```bash
mix dev
```

The `mix dev` command automatically:

- Compiles the application
- Starts the Phoenix server
- Sets up and builds assets (installs npm dependencies, compiles CSS/JS)
- Starts live reload for development

The application will be available at `http://localhost:4000`

### Interactive Mode

For debugging and interactive development:

```bash
iex -S mix
```

## Database Operations

### Migrations

Create a new migration:

```bash
mix ecto.gen.migration {migration_name}
```

Run migrations:

```bash
mix ecto.migrate
```

Reset database (development only):

```bash
mix ecto.reset
```

## Testing

```bash
# Run all tests
mix test

# Run tests with coverage report
mix test --cover
```

## Environment Configuration

The application uses the following default configuration:

- **Database**: PostgreSQL on port 5555 (via Docker Compose)
- **Web Server**: Phoenix on port 4000
- **Database Name**: `customeros`
- **Database User**: `postgres`
- **Database Password**: `password`

Environment variables can be configured in your shell or `.env` file as needed.

## Upgrading/Resetting

If you need to reset your development environment:

```bash
# Stop and remove containers
docker compose down

# Remove database volume (optional, removes all data)
docker compose down -v

# Start fresh
docker compose up -d postgres
mix ecto.reset
```

## Teardown

To stop all services:

```bash
# Stop PostgreSQL
docker compose down

# Optional: Remove volumes to free up space
docker compose down -v
```

## Code Style Guide

- Don't ship code with warnings!
- All public functions should have guards
- All unused variables are named with underscore prefix

## Standardized Libraries

- **HTTP client**: Finch
- **Database**: Ecto with PostgreSQL
- **Web framework**: Phoenix
- **Frontend**: React with Inertia.js
- **CSS**: Tailwind CSS

## Troubleshooting

### PostgreSQL Connection Issues

If you encounter database connection issues:

1. Ensure PostgreSQL is running: `docker compose ps`
2. Check logs: `docker compose logs postgres`
3. Restart PostgreSQL: `docker compose restart postgres`

### Asset Compilation Issues

If assets fail to compile:

1. Ensure Node.js is installed: `node --version`
2. Clear and reinstall: `rm -rf assets/node_modules && mix assets.setup`
3. Check for any npm errors in the logs

### Port Conflicts

If port 5555 (PostgreSQL) or 4000 (Phoenix) are in use:

1. Check what's using the port: `lsof -i :5555` or `lsof -i :4000`
2. Stop the conflicting service or modify the port in `compose.yml` or Phoenix config
