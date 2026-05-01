package server

import (
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"yarnballs/internal/auth"
	"yarnballs/internal/realtime"
)

type Config struct {
	Port            int
	StaticURL       string
	TokenSigningKey string
}

type Server struct {
	cfg      Config
	auth     *auth.Service
	hub      *realtime.Hub
	staticFS fs.FS
}

func New(cfg Config, static embed.FS) (*Server, error) {
	if cfg.Port == 0 {
		cfg.Port = 8080
	}

	staticFS, err := fs.Sub(static, "static")
	if err != nil {
		return nil, fmt.Errorf("load static filesystem: %w", err)
	}

	authService := auth.NewService(cfg.TokenSigningKey)

	return &Server{
		cfg:      cfg,
		auth:     authService,
		hub:      realtime.NewHub(authService),
		staticFS: staticFS,
	}, nil
}

func (s *Server) Run() error {
	addr := fmt.Sprintf(":%d", s.cfg.Port)
	slog.Info(
		"starting go backend",
		"port", s.cfg.Port,
		"static_url", s.cfg.StaticURL,
	)

	return http.ListenAndServe(addr, s.routes())
}

func (s *Server) routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", s.handleHealth)
	mux.HandleFunc("POST /api/tokens", s.handleCreateToken)
	mux.HandleFunc("GET /api/tokens", s.handleShowToken)
	mux.HandleFunc("GET /ws", s.handleWebSocket)

	if s.cfg.StaticURL == "" {
		fileServer := http.FileServer(http.FS(s.staticFS))
		mux.Handle("/assets/", fileServer)
		mux.Handle("/images/", fileServer)
		mux.Handle("/favicon.ico", fileServer)
		mux.Handle("/robots.txt", fileServer)
	}
	mux.HandleFunc("/", s.handleIndex)

	return withLogging(s.withCORS(mux))
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleCreateToken(w http.ResponseWriter, r *http.Request) {
	var payload struct {
		DisplayName string `json:"display_name"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid json"})
		return
	}

	token, err := s.auth.CreateToken(payload.DisplayName)
	if err != nil {
		if err == auth.ErrInvalidName {
			writeJSON(w, http.StatusUnprocessableEntity, map[string]any{
				"errors": map[string]any{
					"display_name": []string{"can't be blank"},
				},
			})
			return
		}

		slog.Error("failed to create token", "error", err.Error())
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "failed to create token"})
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{"data": token})
}

func (s *Server) handleShowToken(w http.ResponseWriter, r *http.Request) {
	token, err := bearerToken(r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	user, err := s.auth.VerifyToken(token)
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"data": auth.Token{
			Token: token,
			User:  user,
		},
	})
}

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	s.hub.HandleWebSocket(w, r)
}

func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" && s.cfg.StaticURL == "" {
		if _, err := fs.Stat(s.staticFS, strings.TrimPrefix(filepath.Clean(r.URL.Path), "/")); err == nil {
			http.FileServer(http.FS(s.staticFS)).ServeHTTP(w, r)
			return
		}
	}

	index, err := fs.ReadFile(s.staticFS, "index.template.html")
	if err != nil {
		http.Error(w, "missing index.template.html", http.StatusInternalServerError)
		return
	}

	indexHTML := string(index)
	indexHTML = strings.ReplaceAll(indexHTML, "__ASSET_BASE_URL__", strings.TrimRight(s.assetBaseURL(), "/"))

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(indexHTML))
}

func withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		slog.Info("http request", "method", r.Method, "path", r.URL.Path)
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	if err := json.NewEncoder(w).Encode(payload); err != nil {
		slog.Error("failed to write json response", "error", err.Error())
	}
}

func (s *Server) withCORS(next http.Handler) http.Handler {
	if s.cfg.StaticURL == "" {
		return next
	}

	allowedOrigin := strings.TrimRight(s.cfg.StaticURL, "/")

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := strings.TrimRight(r.Header.Get("Origin"), "/")
		if origin == allowedOrigin {
			w.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Accept, Authorization, Content-Type")
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Vary", "Origin")
		}

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func EnvInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		slog.Warn("invalid integer environment variable", "key", key, "value", value)
		return fallback
	}

	return parsed
}

func (s *Server) assetBaseURL() string {
	if s.cfg.StaticURL == "" {
		return ""
	}

	return s.cfg.StaticURL
}

func bearerToken(header string) (string, error) {
	const prefix = "Bearer "
	if !strings.HasPrefix(header, prefix) {
		return "", auth.ErrUnauthenticated
	}

	token := strings.TrimSpace(strings.TrimPrefix(header, prefix))
	if token == "" {
		return "", auth.ErrUnauthenticated
	}

	return token, nil
}
