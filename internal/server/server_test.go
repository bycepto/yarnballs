package server

import (
	"net/http"
	"testing"

	"yarnballs/internal/auth"
)

func TestBearerToken(t *testing.T) {
	token, err := bearerToken("Bearer abc123")
	if err != nil {
		t.Fatalf("bearerToken() error = %v", err)
	}

	if token != "abc123" {
		t.Fatalf("bearerToken() = %q, want abc123", token)
	}
}

func TestBearerTokenRejectsInvalidHeader(t *testing.T) {
	if _, err := bearerToken("abc123"); err != auth.ErrUnauthenticated {
		t.Fatalf("bearerToken() error = %v, want %v", err, auth.ErrUnauthenticated)
	}
}

func TestAssetBaseURL(t *testing.T) {
	srv := &Server{cfg: Config{StaticURL: "http://localhost:3000/"}}
	if got := srv.assetBaseURL(); got != "http://localhost:3000/" {
		t.Fatalf("assetBaseURL() = %q, want %q", got, "http://localhost:3000/")
	}
}

func TestHealthRoutePatternCompiles(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(http.ResponseWriter, *http.Request) {})
}
