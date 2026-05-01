package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
)

func main() {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		log.Fatalf("generate signing key: %v", err)
	}

	fmt.Println(hex.EncodeToString(buf))
}
