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

# prepare build dir
WORKDIR /opt/app

# install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# install mix dependencies
COPY ./mix.exs ./mix.lock ./
COPY ./config config

# access private repos
ARG GITHUB_TOKEN
RUN git config --global url."https://$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"

# install and compiled dependencies
RUN mix deps.get
RUN mix deps.compile

# compile and build release
COPY ./priv priv
COPY ./lib lib
RUN mix do compile, release

# prepare release image
FROM ${RUNNER_IMAGE} as app
RUN apt -y update && apt -y install openssl libncurses5-dev libncursesw5-dev

WORKDIR /opt/app

RUN chown nobody:nogroup /opt/app

USER nobody:nogroup

COPY --from=build --chown=nobody:nogroup /opt/app/_build/prod/rel/ggyo ./
COPY ./scripts/entrypoint.sh entrypoint.sh

ENV HOME=/opt/app

ENTRYPOINT ./entrypoint.sh
