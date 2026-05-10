FROM node:22-bookworm AS frontend

WORKDIR /app/assets

RUN corepack enable pnpm
RUN corepack prepare pnpm@11.0.8 --activate

COPY assets/package.json assets/pnpm-lock.yaml assets/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY assets ./
ARG APP_HOST
ENV APP_HOST=${APP_HOST}
RUN pnpm build -- --deploy

FROM golang:1.24.2-bookworm AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY cmd ./cmd
COPY internal ./internal
COPY --from=frontend /app/cmd/server/static/assets ./cmd/server/static/assets

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/server ./cmd/server

FROM debian:bookworm-20250428-slim

RUN apt-get update -y && \
  apt-get install -y ca-certificates && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /out/server /app/server

ENV PORT=8080

CMD ["/app/server"]
