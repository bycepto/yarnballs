#!/usr/bin/env bash

set -euo pipefail

frontend_pid=""
backend_pid=""

cleanup() {
    local exit_code=0

    if [[ -n "${frontend_pid}" ]] && kill -0 "${frontend_pid}" 2>/dev/null; then
        kill "${frontend_pid}" 2>/dev/null || true
        wait "${frontend_pid}" 2>/dev/null || true
    fi

    if [[ -n "${backend_pid}" ]] && kill -0 "${backend_pid}" 2>/dev/null; then
        kill "${backend_pid}" 2>/dev/null || true
        wait "${backend_pid}" 2>/dev/null || true
    fi

    exit "${exit_code}"
}

trap cleanup INT TERM

env --chdir=assets pnpm dev &
frontend_pid=$!

env STATIC_URL=http://localhost:3000 go run ./cmd/server &
backend_pid=$!

wait -n "${frontend_pid}" "${backend_pid}"
cleanup
