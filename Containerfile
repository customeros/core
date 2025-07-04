ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=26.2.5.12
ARG DEBIAN_VERSION=bookworm-20250428-slim
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM --platform=linux/arm64 ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y && \
  apt-get install -y build-essential git unzip curl && \
  apt-get clean && \
  rm -f /var/lib/apt/lists/*_*

# Install Bun
ENV BUN_INSTALL="/root/.bun"
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="${BUN_INSTALL}/bin:$PATH"

# Verify Bun installation for ARM64
RUN bun --version && echo "Platform: $(uname -m)"

# Set working directory to match your monorepo structure
WORKDIR /app

# Copy scripts directory for Bun
COPY scripts /app/scripts

# Build JS utilities with Bun
WORKDIR /app/scripts
RUN bun install
RUN bun build --compile convert_lexical_to_yjs.ts --output convert_lexical_to_yjs --bundle
RUN bun build --compile convert_md_to_lexical.ts --output convert_md_to_lexical --bundle

# Create priv/scripts directory and move compiled script
RUN mkdir -p /app/priv/scripts
RUN mv convert_lexical_to_yjs /app/priv/scripts/
RUN mv convert_md_to_lexical /app/priv/scripts/

# Set working directory to Elixir app directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Copy Elixir project files
COPY mix.exs mix.lock ./

# Get dependencies
RUN mix deps.get --only $MIX_ENV

# Copy config files
COPY config/config.exs config/${MIX_ENV}.exs config/

# Compile dependencies
RUN mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv

# overlays
RUN mkdir -p rel/overlays/bin

# Copy overlay files
COPY scripts/rel/server rel/overlays/bin/server
COPY scripts/rel/server.bat rel/overlays/bin/server.bat

# Make sure server script is executable
RUN if [ -f rel/overlays/bin/server ]; then chmod +x rel/overlays/bin/server; fi

# Install Node.js and npm for ARM64
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
  apt-get install -y nodejs && \
  npm install -g npm@latest 

# Verify Node.js installation
RUN node --version && npm --version && echo "Node architecture: $(node -e 'console.log(process.arch)')"

# Install frontend dependencies
COPY assets /app/assets
RUN npm install --prefix /app/assets --ignore-scripts

# Build and deploy frontend assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Copy runtime config
COPY config/runtime.exs config/

# Create the release
RUN mix release

#
# Runner Stage
#
FROM --platform=linux/arm64 ${RUNNER_IMAGE}

# Install runtime dependencies
RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Set working directory
WORKDIR "/app"
RUN chown nobody /app

# Set runner ENV
ENV MIX_ENV="prod"

# Copy the release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/core ./

# Copy the entrypoint script
COPY scripts/build/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose ports for web traffic and clustering
EXPOSE 4000
EXPOSE 4369
EXPOSE 9100-9155

# Switch to non-root user
USER nobody

# Set the entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
