package auth

import (
	"testing"
	"time"
)

func TestCreateAndVerifyToken(t *testing.T) {
	svc := NewService("test-key")
	now := time.Unix(1_700_000_000, 0)
	svc.now = func() time.Time { return now }

	token, err := svc.CreateToken("alice")
	if err != nil {
		t.Fatalf("CreateToken() error = %v", err)
	}

	user, err := svc.VerifyToken(token.Token)
	if err != nil {
		t.Fatalf("VerifyToken() error = %v", err)
	}

	if user.ID != token.User.ID {
		t.Fatalf("VerifyToken() user id = %q, want %q", user.ID, token.User.ID)
	}

	if user.Name != "alice" {
		t.Fatalf("VerifyToken() user name = %q, want alice", user.Name)
	}
}

func TestVerifyTokenRejectsExpiredToken(t *testing.T) {
	svc := NewService("test-key")
	now := time.Unix(1_700_000_000, 0)
	svc.now = func() time.Time { return now }

	token, err := svc.CreateToken("alice")
	if err != nil {
		t.Fatalf("CreateToken() error = %v", err)
	}

	svc.now = func() time.Time { return now.Add(tokenTTL + time.Second) }

	if _, err := svc.VerifyToken(token.Token); err != ErrUnauthenticated {
		t.Fatalf("VerifyToken() error = %v, want %v", err, ErrUnauthenticated)
	}
}

func TestCreateTokenRejectsBlankName(t *testing.T) {
	svc := NewService("test-key")

	if _, err := svc.CreateToken("   "); err != ErrInvalidName {
		t.Fatalf("CreateToken() error = %v, want %v", err, ErrInvalidName)
	}
}
