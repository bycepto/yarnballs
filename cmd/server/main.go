package main

import (
	"embed"
	"flag"
	"log/slog"
	"os"

	"yarnballs/internal/server"
)

//go:embed static/*
var static embed.FS

func main() {
	var cfg server.Config

	flag.IntVar(&cfg.Port, "port", server.EnvInt("PORT", 8080), "server port")
	flag.StringVar(
		&cfg.StaticURL,
		"static-url",
		os.Getenv("STATIC_URL"),
		"frontend development server url; when set, static assets are not served by Go",
	)
	flag.StringVar(
		&cfg.TokenSigningKey,
		"token-signing-key",
		os.Getenv("TOKEN_SIGNING_KEY"),
		"signing key for temporary auth tokens",
	)
	flag.Parse()

	srv, err := server.New(cfg, static)
	if err != nil {
		slog.Error("failed to initialize server", "error", err.Error())
		os.Exit(1)
	}

	if err := srv.Run(); err != nil {
		slog.Error("server exited", "error", err.Error())
		os.Exit(1)
	}
}
