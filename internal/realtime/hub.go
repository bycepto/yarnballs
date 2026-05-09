package realtime

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"

	"yarnballs/internal/auth"
	"yarnballs/internal/game"
)

const gameTopic = "yarnballs:x"

const broadcastInterval = 33 * time.Millisecond

type Hub struct {
	auth *auth.Service
	game *game.Game

	mu            sync.Mutex
	clients       map[*Client]struct{}
	clientsByUser map[string]*Client
	snapshotSeq   atomic.Uint64
}

type Client struct {
	conn   *websocket.Conn
	user   auth.User
	topics map[string]struct{}
}

type inboundMessage struct {
	Type     string          `json:"type"`
	Topic    string          `json:"topic,omitempty"`
	Event    string          `json:"event,omitempty"`
	Payload  json.RawMessage `json:"payload,omitempty"`
	SentAtMS int64           `json:"sent_at_ms,omitempty"`
}

type outboundJoinAck struct {
	Type   string   `json:"type"`
	Topic  string   `json:"topic"`
	Events []string `json:"events"`
}

type outboundEvent struct {
	Type    string      `json:"type"`
	Topic   string      `json:"topic"`
	Event   string      `json:"event"`
	Payload interface{} `json:"payload"`
}

type outboundError struct {
	Type  string `json:"type"`
	Error string `json:"error"`
}

type outboundPong struct {
	Type         string `json:"type"`
	EchoSentAtMS int64  `json:"echo_sent_at_ms,omitempty"`
	ServerTimeMS int64  `json:"server_time_ms"`
}

type snapshotPayload struct {
	State game.State   `json:"state"`
	Meta  snapshotMeta `json:"meta"`
}

type snapshotMeta struct {
	Sequence            uint64 `json:"sequence"`
	ServerTimeMS        int64  `json:"server_time_ms"`
	BroadcastIntervalMS int64  `json:"broadcast_interval_ms"`
	TickIntervalMS      int64  `json:"tick_interval_ms"`
	ClientCount         int    `json:"client_count"`
	PlayerCount         int    `json:"player_count"`
}

func NewHub(authService *auth.Service) *Hub {
	hub := &Hub{
		auth:          authService,
		game:          game.New(),
		clients:       map[*Client]struct{}{},
		clientsByUser: map[string]*Client{},
	}

	go hub.loop()

	return hub
}

func (h *Hub) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	user, err := h.auth.VerifyToken(token)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		InsecureSkipVerify: true,
	})
	if err != nil {
		slog.Error("failed to accept websocket", "error", err.Error())
		return
	}

	client := &Client{
		conn:   conn,
		user:   user,
		topics: map[string]struct{}{},
	}

	h.addClient(client)
	defer h.removeClient(client)
	defer conn.CloseNow()

	ctx := context.Background()
	for {
		var msg inboundMessage
		if err := wsjson.Read(ctx, conn, &msg); err != nil {
			return
		}

		responses, err := h.processClientMessage(client, msg)
		if err != nil {
			slog.Warn("failed to handle websocket message", "error", err.Error())
			return
		}
		if err := writeResponses(ctx, conn, responses); err != nil {
			slog.Warn("failed to write websocket response", "error", err.Error())
			return
		}
	}
}

func (h *Hub) processClientMessage(client *Client, msg inboundMessage) ([]interface{}, error) {
	switch msg.Type {
	case "ping":
		return []interface{}{outboundPong{
			Type:         "pong",
			EchoSentAtMS: msg.SentAtMS,
			ServerTimeMS: time.Now().UnixMilli(),
		}}, nil
	case "join":
		if msg.Topic != gameTopic {
			return []interface{}{outboundError{Type: "error", Error: "unknown topic"}}, nil
		}

		if _, joined := client.topics[msg.Topic]; joined {
			return []interface{}{outboundJoinAck{
				Type:   "join_ack",
				Topic:  msg.Topic,
				Events: []string{"requested_state"},
			}}, nil
		}

		client.topics[msg.Topic] = struct{}{}
		h.game.AddPlayer(client.user)
		responses := []interface{}{outboundJoinAck{
			Type:   "join_ack",
			Topic:  msg.Topic,
			Events: []string{"requested_state"},
		}}

		h.broadcastState()
		return responses, nil

	case "leave":
		delete(client.topics, msg.Topic)
		h.game.RemovePlayer(client.user.ID)
		h.broadcastState()
		return nil, nil

	case "event":
		if _, ok := client.topics[msg.Topic]; !ok {
			return []interface{}{outboundError{Type: "error", Error: "topic not joined"}}, nil
		}

		switch msg.Event {
		case "turned_ship":
			var payload struct {
				Clockwise bool `json:"clockwise"`
			}
			if err := json.Unmarshal(msg.Payload, &payload); err != nil {
				return nil, err
			}
			h.game.TurnShip(client.user.ID, payload.Clockwise)
		case "thrusted_ship":
			h.game.ThrustShip(client.user.ID)
		case "fired_shot":
			h.game.FireMissile(client.user.ID)
		case "resized_world":
			var payload struct {
				Width  float64 `json:"width"`
				Height float64 `json:"height"`
			}
			if err := json.Unmarshal(msg.Payload, &payload); err != nil {
				return nil, err
			}
			h.game.SetWorldSize(payload.Width, payload.Height)
			h.broadcastState()
		default:
			return []interface{}{outboundError{Type: "error", Error: "unknown event"}}, nil
		}

		return nil, nil
	default:
		return []interface{}{outboundError{Type: "error", Error: "unknown message type"}}, nil
	}
}

func (h *Hub) loop() {
	stepTicker := time.NewTicker(game.TickDuration())
	broadcastTicker := time.NewTicker(broadcastInterval)
	defer stepTicker.Stop()
	defer broadcastTicker.Stop()

	for {
		select {
		case <-stepTicker.C:
			h.game.Step()
		case <-broadcastTicker.C:
			h.broadcastState()
		}
	}
}

func (h *Hub) broadcastState() {
	h.broadcast(outboundEvent{
		Type:    "message",
		Topic:   gameTopic,
		Event:   "requested_state",
		Payload: h.newSnapshotPayload(),
	})
}

func (h *Hub) newSnapshotPayload() snapshotPayload {
	state := h.game.Snapshot()

	return snapshotPayload{
		State: state,
		Meta: snapshotMeta{
			Sequence:            h.snapshotSeq.Add(1),
			ServerTimeMS:        time.Now().UnixMilli(),
			BroadcastIntervalMS: broadcastInterval.Milliseconds(),
			TickIntervalMS:      game.TickDuration().Milliseconds(),
			ClientCount:         h.subscriberCount(gameTopic),
			PlayerCount:         len(state.Ships.Entities),
		},
	}
}

func (h *Hub) broadcast(msg outboundEvent) {
	h.mu.Lock()
	clients := make([]*Client, 0, len(h.clients))
	for client := range h.clients {
		if _, ok := client.topics[msg.Topic]; ok {
			clients = append(clients, client)
		}
	}
	h.mu.Unlock()

	for _, client := range clients {
		if err := wsjson.Write(context.Background(), client.conn, msg); err != nil {
			slog.Warn("failed to broadcast websocket message", "error", err.Error())
		}
	}
}

func (h *Hub) addClient(client *Client) {
	h.mu.Lock()
	replaced := h.clientsByUser[client.user.ID]
	h.clients[client] = struct{}{}
	h.clientsByUser[client.user.ID] = client
	if replaced != nil && replaced != client {
		delete(h.clients, replaced)
	}
	h.mu.Unlock()

	if replaced != nil && replaced != client && replaced.conn != nil {
		_ = replaced.conn.Close(websocket.StatusPolicyViolation, "superseded by newer connection")
	}
}

func (h *Hub) subscriberCount(topic string) int {
	h.mu.Lock()
	defer h.mu.Unlock()

	count := 0
	for client := range h.clients {
		if _, ok := client.topics[topic]; ok {
			count++
		}
	}
	return count
}

func (h *Hub) removeClient(client *Client) {
	h.mu.Lock()
	delete(h.clients, client)
	shouldRemovePlayer := false
	if active, ok := h.clientsByUser[client.user.ID]; ok && active == client {
		delete(h.clientsByUser, client.user.ID)
		shouldRemovePlayer = true
	}
	h.mu.Unlock()

	if shouldRemovePlayer {
		h.game.RemovePlayer(client.user.ID)
		h.broadcastState()
	}
}

func writeResponses(ctx context.Context, conn *websocket.Conn, responses []interface{}) error {
	for _, response := range responses {
		if response == nil {
			continue
		}
		if err := wsjson.Write(ctx, conn, response); err != nil {
			return err
		}
	}
	return nil
}

var errUnauthorized = errors.New("unauthorized")
