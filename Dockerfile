# See https://hexdocs.pm/phoenix/releases.html
ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.3.4.2
ARG DEBIAN_VERSION=bullseye-20210902-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as build

# install build dependencies -- no npm
# RUN apk add --no-cache build-base npm git python
#
RUN apt -y update && apt -y install git build-essential

# RUST
# https://github.com/rust-lang/docker-rust/blob/76e3311a6326bc93a1e96ad7ae06c05763b62b18/1.65.0/bullseye/slim/Dockerfile

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.65.0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gcc \
        libc6-dev \
        wget \
        ; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
        amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='5cc9ffd1026e82e7fb2eec2121ad71f4b0f044e88bca39207b3f6b769aaa799c' ;; \
        armhf) rustArch='armv7-unknown-linux-gnueabihf'; rustupSha256='48c5ecfd1409da93164af20cf4ac2c6f00688b15eb6ba65047f654060c844d85' ;; \
        arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='e189948e396d47254103a49c987e7fb0e5dd8e34b200aa4481ecc4b8e41fb929' ;; \
        i386) rustArch='i686-unknown-linux-gnu'; rustupSha256='0e0be29c560ad958ba52fcf06b3ea04435cb3cd674fbe11ce7d954093b9504fd' ;; \
        *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac; \
    url="https://static.rust-lang.org/rustup/archive/1.25.1/${rustArch}/rustup-init"; \
    wget "$url"; \
    echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
    rm rustup-init; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME; \
    rustup --version; \
    cargo --version; \
    rustc --version; \
    apt-get remove -y --auto-remove \
        wget \
        ; \
    rm -rf /var/lib/apt/lists/*;
# </RUST>

# prepare build dir
WORKDIR /opt/app

# install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# install mix dependencies
COPY ./server/mix.exs ./server/mix.lock ./
COPY ./server/config config
COPY ./yarnballs ../yarnballs

# install and compiled dependencies
RUN mix deps.get
RUN mix deps.compile

# compile and build release
COPY ./server/priv priv
COPY ./server/lib lib
RUN mix do compile, release

# prepare release image
FROM ${RUNNER_IMAGE} as app
RUN apt -y update && apt -y install openssl libncurses5-dev libncursesw5-dev

WORKDIR /opt/app

RUN chown nobody:nogroup /opt/app

USER nobody:nogroup

COPY --from=build --chown=nobody:nogroup /opt/app/_build/prod/rel/shmup ./
COPY ./server/scripts/entrypoint.sh entrypoint.sh

ENV HOME=/opt/app

ENTRYPOINT ./entrypoint.sh
