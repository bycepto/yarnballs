package game

import (
	"math/rand/v2"
	"testing"
	"time"

	"yarnballs/internal/auth"
)

func newTestGame() *Game {
	g := New()
	base := time.Unix(1_700_000_000, 0)
	current := base
	g.now = func() time.Time { return current }
	g.rng = rand.New(rand.NewPCG(1, 2))
	return g
}

func TestAddPlayerAndSnapshot(t *testing.T) {
	g := newTestGame()
	g.AddPlayer(auth.User{ID: "u1", Name: "alice"})

	state := g.Snapshot()
	ship, ok := state.Ships.Entities["u1"]
	if !ok {
		t.Fatalf("player not added")
	}
	if ship.Name == nil || *ship.Name != "alice" {
		t.Fatalf("unexpected ship name: %#v", ship.Name)
	}
	if state.Level != 0 {
		t.Fatalf("level = %d, want 0", state.Level)
	}
}

func TestMissileEnemyCollisionAddsScoreAndExplosion(t *testing.T) {
	g := newTestGame()
	g.AddPlayer(auth.User{ID: "u1", Name: "alice"})

	g.mu.Lock()
	g.state.Ships.Entities["u1"] = Ship{ID: "u1", Health: maxHealth}
	g.state.Missiles.Entities = []Missile{{ID: "m1", ShooterID: "u1", X: 43.4, Y: 43.4}}
	g.state.Enemies.Entities = []Enemy{{ID: "e1", Kind: "bouncer", X: 10, Y: 10, Radius: bouncerRadius, RepelVel: 1000}}
	g.mu.Unlock()

	g.Step()

	state := g.Snapshot()
	if len(state.Missiles.Entities) != 0 {
		t.Fatalf("missile was not removed")
	}
	for _, enemy := range state.Enemies.Entities {
		if enemy.ID == "e1" {
			t.Fatalf("collided enemy was not removed")
		}
	}
	if len(state.Enemies.Explosions.Entities) != 1 {
		t.Fatalf("explosion count = %d, want 1", len(state.Enemies.Explosions.Entities))
	}
	if state.Enemies.DestroyedCount != 1 {
		t.Fatalf("destroyed count = %d, want 1", state.Enemies.DestroyedCount)
	}
	if state.Score != 1 {
		t.Fatalf("score = %d, want 1", state.Score)
	}
}

func TestFireMissileRespawnsDestroyedShip(t *testing.T) {
	g := newTestGame()
	g.AddPlayer(auth.User{ID: "u1", Name: "alice"})

	now := time.Unix(1_700_000_000, 0)
	g.now = func() time.Time { return now }

	g.mu.Lock()
	destroyed := now.Add(-2 * fireRespawnDelay)
	ship := g.state.Ships.Entities["u1"]
	ship.Health = 0
	ship.DestroyedAt = &destroyed
	g.state.Ships.Entities["u1"] = ship
	g.mu.Unlock()

	g.FireMissile("u1")

	state := g.Snapshot()
	ship = state.Ships.Entities["u1"]
	if ship.Health != maxHealth {
		t.Fatalf("health = %f, want %f", ship.Health, maxHealth)
	}
	if ship.DestroyedAt != nil {
		t.Fatalf("ship was not respawned")
	}
}

func TestMissilePersistsUntilOutOfBounds(t *testing.T) {
	g := newTestGame()

	g.mu.Lock()
	g.state.Width = 1000
	g.state.Height = 1000
	g.state.Missiles.Entities = []Missile{{ID: "m1", X: 100, Y: 100, VelX: missileVelocity, VelY: 0}}
	g.mu.Unlock()

	for range 100 {
		g.Step()
	}

	state := g.Snapshot()
	if len(state.Missiles.Entities) != 1 {
		t.Fatalf("missile count = %d, want 1", len(state.Missiles.Entities))
	}

	for range 100 {
		g.Step()
	}

	state = g.Snapshot()
	if len(state.Missiles.Entities) != 0 {
		t.Fatalf("missile count = %d, want 0", len(state.Missiles.Entities))
	}
}

func TestLevelProgression(t *testing.T) {
	g := newTestGame()
	g.AddPlayer(auth.User{ID: "u1", Name: "alice"})

	g.mu.Lock()
	ship := g.state.Ships.Entities["u1"]
	ship.Score = 220
	g.state.Ships.Entities["u1"] = ship
	g.updateLevelLocked()
	g.mu.Unlock()

	state := g.Snapshot()
	if state.Level != 6 {
		t.Fatalf("level = %d, want 6", state.Level)
	}
	if state.NextLevelScore == nil || *state.NextLevelScore != 280 {
		t.Fatalf("next level score = %#v, want 280", state.NextLevelScore)
	}
}
