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

Artwork credits:

    Kim Lathrop (background, debris, ship, asteroids, missiles)
    Rob @ http://robsonbillponte666.deviantart.com (yarnballs)
