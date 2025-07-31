ARG ELIXIR_VERSION=1.15.7
ARG OTP_VERSION=26.1.2
ARG DEBIAN_VERSION=bullseye-20231009-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    curl \
    sqlite3 \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install Node.js for asset compilation
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only=prod
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy assets and compile them
COPY assets assets
COPY priv priv
RUN mix assets.deploy

# Compile the release
COPY lib lib
RUN mix compile

# Copy runtime configuration
COPY config/runtime.exs config/

# Compile the release
RUN mix release

# Start a new build stage for the runtime image
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y \
    libstdc++6 \
    openssl \
    libncurses5 \
    locales \
    sqlite3 \
    curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/emberchat ./

# Create directories for data persistence
RUN mkdir -p /app/data && chown nobody:root /app/data

USER nobody

# Set default environment variables
ENV PHX_SERVER=true
ENV PORT=4000
ENV DATABASE_PATH=/app/data/emberchat.db

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT}/ || exit 1

EXPOSE 4000

CMD ["/app/bin/server"]