# CustomerOS Core

CustomerOS Core is the central backend and frontend application for CustomerOS, a platform for qualified opportunity generation. It is a powerful, extensible, and observable system designed to be the heart of your customer operations.

## About the Project

CustomerOS Core is a sophisticated Elixir and Phoenix-based application with a modern React frontend. It is designed to be more than just a simple web application; it's a robust platform that can be extended and integrated with other services.

The backend is built with a focus on concurrency, fault tolerance, and observability, leveraging the full power of the BEAM. It communicates with other systems using a variety of protocols, including GraphQL, gRPC, and message queues (RabbitMQ/NATS).

The frontend is a single-page application built with React and Inertia.js, providing a rich and interactive user experience. It includes features like a rich text editor with real-time collaboration, powered by Lexical and Yjs.

## Key Features

- **GraphQL API:** A comprehensive GraphQL API for interacting with the system, powered by Absinthe.
- **Real-time Collaboration:** Collaborative rich text editing using Lexical and Yjs.
- **Message-driven Architecture:** Uses RabbitMQ (AMQP) and NATS (Jetstream) for asynchronous communication.
- **gRPC for Internal Services:** Efficient and strongly-typed communication with internal services using gRPC.
- **Observability:** Integrated with OpenTelemetry for metrics, tracing, and logging.
- **Phoenix LiveView:** For real-time features and interactive dashboards.
- **Modern Frontend:** A responsive and interactive frontend built with React, Inertia.js, and Tailwind CSS.

## Technology Stack

### Backend

- **Framework:** [Phoenix](https://www.phoenixframework.org/)
- **Language:** [Elixir](https://elixir-lang.org/)
- **Database:** [PostgreSQL](https://www.postgresql.org/) with [Ecto](https://hexdocs.pm/ecto/Ecto.html)
- **API:** [GraphQL](https://graphql.org/) with [Absinthe](http://absinthe-graphql.org/)
- **Messaging:** [RabbitMQ](https://www.rabbitmq.com/) and [NATS](https://nats.io/)
- **RPC:** [gRPC](https://grpc.io/)
- **Observability:** [OpenTelemetry](https://opentelemetry.io/)
- **HTTP Client:** [Finch](https://github.com/sneako/finch)

### Frontend

- **Framework:** [React](https://reactjs.org/)
- **Routing:** [Inertia.js](https://inertiajs.com/)
- **Styling:** [Tailwind CSS](https://tailwindcss.com/)
- **Rich Text Editor:** [Lexical](https://lexical.dev/)
- **Real-time Collaboration:** [Yjs](https://yjs.dev/)
- **Build Tool:** [esbuild](https://esbuild.github.io/)

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

## Troubleshooting

### PostgreSQL Connection Issues

If you encounter database connection issues:

1. Ensure PostgreSQL is running: `docker compose ps`
2. Check logs: `docker compose logs postgres`
3. Restart PostgreSQL: `docker compose restart postgres`
4. Ensure that you have set the PostgresSQL environment variables

### Asset Compilation Issues

If assets fail to compile:

1. Ensure Node.js is installed: `node --version`
2. Clear and reinstall: `rm -rf assets/node_modules && mix assets.setup`
3. Check for any npm errors in the logs

### Port Conflicts

If port 5555 (PostgreSQL) or 4000 (Phoenix) are in use:

1. Check what's using the port: `lsof -i :5555` or `lsof -i :4000`
2. Stop the conflicting service or modify the port in `compose.yml` or Phoenix config

