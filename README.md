# 🚀🧶Yarnballs

An online multiplayer Asteroid clone inspired by the RiceRocks assignment from Introduction to Interactive Programming in Python on Coursera. [Play!](https://yarnballs.ggyo.xyz)

## Status

The backend rewrite is complete:

- frontend: Elm + canvas
- backend: Go

## Development

Install:

- Go 1.24+
- Node 22+
- `pnpm`
- Elm

Useful commands:

- `make dev` runs the Go backend plus the frontend asset dev server
- `make test-go` runs the Go test suite
- `make build` builds the frontend assets and the Go server binary
- `make prod-local` runs the production-style server-rendered build locally

The Go server serves embedded frontend assets in production. In development it
can point at a separate frontend asset host via `STATIC_URL`, following the
same split-server pattern as the `connections` app.

## Debug Overlay

A latency/debug overlay is available for inspecting websocket and client timing.

- In development, it appears automatically when running `make dev`
- In production, add `?debug=1` to the URL

The most useful metrics are:

- `rtt`: websocket round-trip time from browser ping to server pong
- `input->snapshot`: time from sending an input to receiving the next state snapshot
- `input->flush`: time from sending an input to flushing that snapshot into Elm
- `recv->flush`: browser-side wait from snapshot receipt to the RAF-gated Elm flush
- `recv->paint`: browser-side wait from snapshot receipt to the next paint after that flush
- `size`: raw websocket size of the most recent snapshot
- `coalesced`: number of older pending snapshots replaced by newer ones before Elm consumed them

Notes:

- `recv->flush` and `recv->paint` are frame-scheduling metrics and depend on monitor refresh rate
- the overlay is intended for relative comparison between local and deployed environments, not as an absolute SLA
- green/yellow/red thresholds are heuristic and meant to surface suspicious regressions quickly

Artwork credits:

    Kim Lathrop (background, debris, ship, asteroids, missiles)
    Rob @ http://robsonbillponte666.deviantart.com (yarnballs)
