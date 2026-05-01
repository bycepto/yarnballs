package realtime

import (
	"encoding/json"
	"testing"

	"yarnballs/internal/auth"
)

func TestProcessClientMessageJoinReturnsJoinAck(t *testing.T) {
	svc := auth.NewService("test-key")
	hub := NewHub(svc)
	client := &Client{
		user:   auth.User{ID: "u1", Name: "alice"},
		topics: map[string]struct{}{},
	}

	responses, err := hub.processClientMessage(client, inboundMessage{
		Type:  "join",
		Topic: gameTopic,
	})
	if err != nil {
		t.Fatalf("processClientMessage() error = %v", err)
	}
	if len(responses) != 1 {
		t.Fatalf("response count = %d, want 1", len(responses))
	}

	joinAck, ok := responses[0].(outboundJoinAck)
	if !ok {
		t.Fatalf("response type = %T, want outboundJoinAck", responses[0])
	}
	if joinAck.Type != "join_ack" {
		t.Fatalf("join ack type = %q, want join_ack", joinAck.Type)
	}
	if joinAck.Topic != gameTopic {
		t.Fatalf("join ack topic = %q, want %q", joinAck.Topic, gameTopic)
	}
	if _, ok := client.topics[gameTopic]; !ok {
		t.Fatalf("client topic was not recorded")
	}
}

func TestProcessClientMessageRejectsEventBeforeJoin(t *testing.T) {
	svc := auth.NewService("test-key")
	hub := NewHub(svc)
	client := &Client{
		user:   auth.User{ID: "u1", Name: "alice"},
		topics: map[string]struct{}{},
	}

	responses, err := hub.processClientMessage(client, inboundMessage{
		Type:  "event",
		Topic: gameTopic,
		Event: "fired_shot",
	})
	if err != nil {
		t.Fatalf("processClientMessage() error = %v", err)
	}
	if len(responses) != 1 {
		t.Fatalf("response count = %d, want 1", len(responses))
	}

	response, ok := responses[0].(outboundError)
	if !ok {
		t.Fatalf("response type = %T, want outboundError", responses[0])
	}
	if response.Error != "topic not joined" {
		t.Fatalf("error = %q, want %q", response.Error, "topic not joined")
	}
}

func TestProcessClientMessageTurnedShipMutatesGameState(t *testing.T) {
	svc := auth.NewService("test-key")
	hub := NewHub(svc)
	client := &Client{
		user:   auth.User{ID: "u1", Name: "alice"},
		topics: map[string]struct{}{gameTopic: {}},
	}
	hub.game.AddPlayer(client.user)

	payload, err := json.Marshal(map[string]bool{"clockwise": true})
	if err != nil {
		t.Fatalf("json.Marshal() error = %v", err)
	}

	if _, err := hub.processClientMessage(client, inboundMessage{
		Type:    "event",
		Topic:   gameTopic,
		Event:   "turned_ship",
		Payload: payload,
	}); err != nil {
		t.Fatalf("processClientMessage() error = %v", err)
	}

	state := hub.game.Snapshot()
	if state.Ships.Entities["u1"].VelAngle <= 0 {
		t.Fatalf("VelAngle = %f, want > 0", state.Ships.Entities["u1"].VelAngle)
	}
}

func TestProcessClientMessageUnknownTypeReturnsError(t *testing.T) {
	svc := auth.NewService("test-key")
	hub := NewHub(svc)
	client := &Client{
		user:   auth.User{ID: "u1", Name: "alice"},
		topics: map[string]struct{}{},
	}

	responses, err := hub.processClientMessage(client, inboundMessage{Type: "bogus"})
	if err != nil {
		t.Fatalf("processClientMessage() error = %v", err)
	}
	if len(responses) != 1 {
		t.Fatalf("response count = %d, want 1", len(responses))
	}
}

func TestProcessClientMessageDuplicateJoinIsIdempotent(t *testing.T) {
	svc := auth.NewService("test-key")
	hub := NewHub(svc)
	client := &Client{
		user:   auth.User{ID: "u1", Name: "alice"},
		topics: map[string]struct{}{},
	}

	if _, err := hub.processClientMessage(client, inboundMessage{
		Type:  "join",
		Topic: gameTopic,
	}); err != nil {
		t.Fatalf("first join error = %v", err)
	}

	responses, err := hub.processClientMessage(client, inboundMessage{
		Type:  "join",
		Topic: gameTopic,
	})
	if err != nil {
		t.Fatalf("second join error = %v", err)
	}
	if len(responses) != 1 {
		t.Fatalf("response count = %d, want 1", len(responses))
	}

	state := hub.game.Snapshot()
	if len(state.Ships.Entities) != 1 {
		t.Fatalf("ship count = %d, want 1", len(state.Ships.Entities))
	}
}

func TestRemoveOldSupersededClientDoesNotRemovePlayer(t *testing.T) {
	svc := auth.NewService("test-key")
	hub := NewHub(svc)

	oldClient := &Client{
		user:   auth.User{ID: "u1", Name: "alice"},
		topics: map[string]struct{}{gameTopic: {}},
	}
	newClient := &Client{
		user:   auth.User{ID: "u1", Name: "alice"},
		topics: map[string]struct{}{gameTopic: {}},
	}

	hub.addClient(oldClient)
	hub.game.AddPlayer(oldClient.user)
	hub.addClient(newClient)
	hub.removeClient(oldClient)

	state := hub.game.Snapshot()
	if _, ok := state.Ships.Entities["u1"]; !ok {
		t.Fatalf("player should remain after old client removal")
	}

	hub.removeClient(newClient)
	state = hub.game.Snapshot()
	if _, ok := state.Ships.Entities["u1"]; ok {
		t.Fatalf("player should be removed after active client removal")
	}
}
