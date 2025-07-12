# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup and Development
```bash
# Initial setup (get dependencies and setup database)
mix setup

# Start development server with hot reload
mix dev

# Interactive Elixir session
iex -S mix
```

### Database Management
```bash
# Setup database (create and migrate)
mix ecto.setup

# Run migrations
mix ecto.migrate

# Seed database
mix ecto.seed

# Reset database (development only)
mix ecto.reset

# Create new migration
mix ecto.gen.migration migration_name
```

### Testing and Quality Assurance
```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Format Elixir code
mix format

# Check code formatting
mix format --check-formatted

# Static code analysis
mix credo

# Type checking
mix dialyzer

# Run all quality checks (compile, format, credo, dialyzer)
mix check
```

### Frontend Development
```bash
# Setup frontend assets (install dependencies)
mix assets.setup

# Build frontend assets
mix assets.build

# Deploy assets for production
mix assets.deploy

# Frontend linting (from assets directory)
cd assets && npm run lint

# Fix frontend linting issues
cd assets && npm run lint:fix

# Generate Tailwind variants
cd assets && npm run codegen
```

### Production and Build
```bash
# Full production build
./scripts/runners/build-core.sh

# Full test suite including formatting checks
./scripts/runners/test.sh

# Clean unused dependencies
mix clean_deps
```

### Docker Operations
```bash
# Start PostgreSQL database
docker compose up -d postgres

# Stop all services
docker compose down

# Remove volumes (delete data)
docker compose down -v
```

## Architecture Overview

### Core Structure
This is an Elixir/Phoenix application with a React frontend, designed as a platform for qualified opportunity generation.

**Main Application Entry Points:**
- `lib/application.ex` - Main application supervisor and startup
- `lib/core.ex` - Core module and namespace
- `lib/web.ex` - Web interface macros and helpers

### Backend Architecture

**Key Domains:**
- `Core.Auth.*` - Authentication, users, tenants, API tokens
- `Core.Crm.*` - CRM functionality including companies, leads, contacts, documents
- `Core.WebTracker.*` - Web tracking, sessions, events, IP intelligence
- `Core.Researcher.*` - Research automation, web scraping, content processing
- `Core.Integrations.*` - External service integrations (HubSpot, Google Ads)
- `Core.Analytics.*` - Analytics jobs and lead generation metrics

**Key Infrastructure:**
- Phoenix web framework with Bandit adapter
- GraphQL API via Absinthe
- Real-time features via Phoenix Channels and PubSub
- PostgreSQL with Ecto ORM
- OpenTelemetry for observability
- Clustering support with libcluster

### Frontend Architecture

**Technology Stack:**
- React 18 with TypeScript
- Inertia.js for server-side routing
- Lexical rich text editor with real-time collaboration (Yjs)
- Tailwind CSS for styling
- Radix UI components

**Key Frontend Areas:**
- `assets/src/pages/Leads/` - Lead management interface
- `assets/src/components/Editor/` - Collaborative rich text editor
- `assets/src/components/` - Reusable UI components

### Real-time Collaboration
The application includes a sophisticated document collaboration system:
- Lexical editor for rich text editing
- Yjs for operational transformation and conflict resolution
- Phoenix Channels for real-time synchronization
- Document persistence with `Core.Crm.Documents.*`

### Environment Configuration
- **Database:** PostgreSQL on port 5555 (docker compose)
- **Web Server:** Phoenix on port 4000
- **Database Name:** `customeros`
- **Default Credentials:** postgres/password

### Code Quality Standards
- Elixir code uses 80-character line limits
- All public functions should have guards
- Unused variables prefixed with underscore
- Credo for static analysis with custom rules
- Dialyzer for type checking
- ESLint for frontend code

### Testing
- ExUnit for Elixir tests
- Mox for mocking in tests
- Test files in `test/` directory mirror `lib/` structure
- Test helpers in `test/support/`

### Key Patterns
- Context pattern for domain boundaries
- GenServers for stateful processes (enrichers, processors)
- Task.Supervisor for async work
- Phoenix Channels for real-time features
- Ecto changesets for data validation