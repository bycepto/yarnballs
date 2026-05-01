package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

const tokenTTL = time.Hour

var (
	ErrUnauthenticated = errors.New("unauthenticated")
	ErrInvalidName     = errors.New("display name is required")
)

type Service struct {
	signingKey []byte
	now        func() time.Time
}

type User struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type Token struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

type tokenPayload struct {
	User User  `json:"user"`
	Exp  int64 `json:"exp"`
}

func NewService(signingKey string) *Service {
	if signingKey == "" {
		signingKey = "dev-insecure-signing-key"
	}

	return &Service{
		signingKey: []byte(signingKey),
		now:        time.Now,
	}
}

func (s *Service) CreateToken(displayName string) (Token, error) {
	displayName = strings.TrimSpace(displayName)
	if displayName == "" {
		return Token{}, ErrInvalidName
	}

	userID, err := randomID()
	if err != nil {
		return Token{}, fmt.Errorf("generate user id: %w", err)
	}

	user := User{
		ID:   userID,
		Name: displayName,
	}

	signedToken, err := s.sign(tokenPayload{
		User: user,
		Exp:  s.now().Add(tokenTTL).Unix(),
	})
	if err != nil {
		return Token{}, err
	}

	return Token{
		Token: signedToken,
		User:  user,
	}, nil
}

func (s *Service) VerifyToken(raw string) (User, error) {
	parts := strings.Split(raw, ".")
	if len(parts) != 2 {
		return User{}, ErrUnauthenticated
	}

	payloadEncoded := parts[0]
	signatureEncoded := parts[1]

	expectedSignature := s.signature(payloadEncoded)
	actualSignature, err := base64.RawURLEncoding.DecodeString(signatureEncoded)
	if err != nil || !hmac.Equal(actualSignature, expectedSignature) {
		return User{}, ErrUnauthenticated
	}

	payloadJSON, err := base64.RawURLEncoding.DecodeString(payloadEncoded)
	if err != nil {
		return User{}, ErrUnauthenticated
	}

	var payload tokenPayload
	if err := json.Unmarshal(payloadJSON, &payload); err != nil {
		return User{}, ErrUnauthenticated
	}

	if s.now().Unix() > payload.Exp {
		return User{}, ErrUnauthenticated
	}

	return payload.User, nil
}

func (s *Service) sign(payload tokenPayload) (string, error) {
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("encode token payload: %w", err)
	}

	payloadEncoded := base64.RawURLEncoding.EncodeToString(payloadJSON)
	signatureEncoded := base64.RawURLEncoding.EncodeToString(s.signature(payloadEncoded))

	return payloadEncoded + "." + signatureEncoded, nil
}

func (s *Service) signature(payload string) []byte {
	mac := hmac.New(sha256.New, s.signingKey)
	_, _ = mac.Write([]byte(payload))
	return mac.Sum(nil)
}

func randomID() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}

	return hex.EncodeToString(buf), nil
}
