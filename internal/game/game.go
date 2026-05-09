package game

import (
	"math"
	"math/rand/v2"
	"slices"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"yarnballs/internal/auth"
)

const (
	defaultWorldWidth  = 640.0
	defaultWorldHeight = 480.0
	minWorldWidth      = 480.0
	minWorldHeight     = 320.0

	tickDuration = 16 * time.Millisecond

	maxHealth         = 100.0
	healthRecharge    = 0.005
	thrustDuration    = 50 * time.Millisecond
	fireRespawnDelay  = 1000 * time.Millisecond
	shipRadius        = 45.0
	shipAcceleration  = 20.0
	shipThrustFric    = 0.05
	shipTurnAccel     = 300.0
	shipTurnFric      = 0.95
	bouncerRadius     = 256.0 / 2.0 * 0.3
	rockBaseRadius    = 45.0
	missileRadius     = 5.0
	missileVelocity   = 500.0
	missileLifespan   = 1000 * time.Millisecond
	explosionLifespan = 1000 * time.Millisecond
)

type Game struct {
	mu    sync.Mutex
	state State
	now   func() time.Time
	rng   *rand.Rand
	ids   atomic.Uint64
}

type State struct {
	Width           float64    `json:"width"`
	Height          float64    `json:"height"`
	Missiles        MissileSet `json:"missiles"`
	Enemies         EnemySet   `json:"enemies"`
	Ships           ShipSet    `json:"ships"`
	Score           int        `json:"score"`
	Level           int        `json:"level"`
	StartLevelScore int        `json:"start_level_score"`
	NextLevelScore  *int       `json:"next_level_score"`
}

type ShipSet struct {
	Entities map[string]Ship `json:"entities"`
}

type Ship struct {
	ID          string     `json:"id"`
	Name        *string    `json:"name"`
	X           float64    `json:"x"`
	Y           float64    `json:"y"`
	VelX        float64    `json:"vel_x"`
	VelY        float64    `json:"vel_y"`
	Angle       float64    `json:"angle"`
	VelAngle    float64    `json:"vel_angle"`
	Thrusting   bool       `json:"thrusting"`
	Health      float64    `json:"health"`
	Score       int        `json:"-"`
	UpdatedAt   time.Time  `json:"-"`
	ThrustedAt  time.Time  `json:"-"`
	DestroyedAt *time.Time `json:"-"`
}

type MissileSet struct {
	Entities []Missile `json:"entities"`
}

type Missile struct {
	ID        string        `json:"-"`
	ShooterID string        `json:"-"`
	X         float64       `json:"x"`
	Y         float64       `json:"y"`
	VelX      float64       `json:"vel_x"`
	VelY      float64       `json:"vel_y"`
	Lifespan  time.Duration `json:"-"`
}

type EnemySet struct {
	Entities       []Enemy      `json:"entities"`
	Explosions     ExplosionSet `json:"explosions"`
	SpawnedCount   int          `json:"spawned_count"`
	DestroyedCount int          `json:"destroyed_count"`
	LastSpawnedAt  time.Time    `json:"-"`
}

type Enemy struct {
	ID       string  `json:"-"`
	Kind     string  `json:"kind"`
	X        float64 `json:"x"`
	Y        float64 `json:"y"`
	VelX     float64 `json:"vel_x"`
	VelY     float64 `json:"vel_y"`
	Scale    float64 `json:"scale,omitempty"`
	Radius   float64 `json:"-"`
	Damage   float64 `json:"-"`
	RepelVel float64 `json:"-"`
}

type ExplosionSet struct {
	Entities []Explosion `json:"entities"`
}

type Explosion struct {
	ID       string        `json:"id"`
	X        float64       `json:"x"`
	Y        float64       `json:"y"`
	Size     float64       `json:"size"`
	Lifespan time.Duration `json:"-"`
}

type levelConfig struct {
	level          int
	startScore     int
	nextLevelScore *int
	spawners       []spawner
}

type spawner struct {
	kind     string
	limit    int
	interval time.Duration
	minVel   float64
	maxVel   float64
	maxScale float64
}

func New() *Game {
	return &Game{
		state: initialState(),
		now:   time.Now,
		rng:   rand.New(rand.NewPCG(uint64(time.Now().UnixNano()), uint64(time.Now().UnixNano()>>1))),
	}
}

func TickDuration() time.Duration {
	return tickDuration
}

func (g *Game) AddPlayer(user auth.User) {
	g.mu.Lock()
	defer g.mu.Unlock()

	name := user.Name
	now := g.now()
	g.state.Ships.Entities[user.ID] = Ship{
		ID:         user.ID,
		Name:       &name,
		UpdatedAt:  now,
		ThrustedAt: now.Add(-thrustDuration),
		Health:     maxHealth,
	}
	g.updateLevelLocked()
}

func (g *Game) RemovePlayer(userID string) {
	g.mu.Lock()
	defer g.mu.Unlock()

	delete(g.state.Ships.Entities, userID)
	g.updateLevelLocked()
}

func (g *Game) TurnShip(userID string, clockwise bool) {
	g.mu.Lock()
	defer g.mu.Unlock()

	ship, ok := g.state.Ships.Entities[userID]
	if !ok || ship.isDead() {
		return
	}

	if clockwise {
		ship.VelAngle += shipTurnAccel
	} else {
		ship.VelAngle -= shipTurnAccel
	}
	g.state.Ships.Entities[userID] = ship
}

func (g *Game) ThrustShip(userID string) {
	g.mu.Lock()
	defer g.mu.Unlock()

	ship, ok := g.state.Ships.Entities[userID]
	if !ok || ship.isDead() {
		return
	}

	ship.ThrustedAt = g.now()
	ship.VelX += shipAcceleration * math.Cos(ship.Angle)
	ship.VelY += shipAcceleration * math.Sin(ship.Angle)
	ship.Thrusting = true
	g.state.Ships.Entities[userID] = ship
}

func (g *Game) FireMissile(userID string) {
	g.mu.Lock()
	defer g.mu.Unlock()

	ship, ok := g.state.Ships.Entities[userID]
	if !ok {
		return
	}

	if ship.isDead() {
		if ship.DestroyedAt != nil && g.now().Sub(*ship.DestroyedAt) >= fireRespawnDelay {
			now := g.now()
			ship.DestroyedAt = nil
			ship.Health = maxHealth
			ship.UpdatedAt = now
			ship.ThrustedAt = now.Add(-thrustDuration)
			g.state.Ships.Entities[userID] = ship
		}
		return
	}

	offset := shipRadius * ship.Angle
	x := math.Cos(offset) + ship.X + shipRadius
	y := math.Sin(offset) + ship.Y + shipRadius
	g.state.Missiles.Entities = append(g.state.Missiles.Entities, Missile{
		ID:        g.newID(),
		ShooterID: userID,
		X:         x,
		Y:         y,
		VelX:      missileVelocity * math.Cos(ship.Angle),
		VelY:      missileVelocity * math.Sin(ship.Angle),
		Lifespan:  missileLifespan,
	})
}

func (g *Game) Step() {
	g.mu.Lock()
	defer g.mu.Unlock()

	dt := tickDuration.Seconds()
	now := g.now()

	for id, ship := range g.state.Ships.Entities {
		ship.update(now, dt, g.state.Width, g.state.Height)
		g.state.Ships.Entities[id] = ship
	}

	for i := range g.state.Missiles.Entities {
		g.state.Missiles.Entities[i].update(dt)
	}
	g.state.Missiles.Entities = slices.DeleteFunc(g.state.Missiles.Entities, func(m Missile) bool {
		return m.Lifespan <= 0
	})

	for i := range g.state.Enemies.Entities {
		g.state.Enemies.Entities[i].update(dt)
	}
	g.state.Enemies.Entities = slices.DeleteFunc(g.state.Enemies.Entities, func(e Enemy) bool {
		return e.outOfBounds(g.state.Width, g.state.Height)
	})

	for i := range g.state.Enemies.Explosions.Entities {
		g.state.Enemies.Explosions.Entities[i].Lifespan -= tickDuration
	}
	g.state.Enemies.Explosions.Entities = slices.DeleteFunc(g.state.Enemies.Explosions.Entities, func(e Explosion) bool {
		return e.Lifespan <= 0
	})

	g.applyMissileEnemyCollisionsLocked()
	g.applyShipEnemyCollisionsLocked()
	g.spawnEnemiesLocked(now)
	g.updateLevelLocked()
}

func (g *Game) Snapshot() State {
	g.mu.Lock()
	defer g.mu.Unlock()

	return copyState(g.state)
}

func (g *Game) SetWorldSize(width float64, height float64) {
	g.mu.Lock()
	defer g.mu.Unlock()

	g.state.Width = math.Max(minWorldWidth, width)
	g.state.Height = math.Max(minWorldHeight, height)
}

func (g *Game) applyMissileEnemyCollisionsLocked() {
	if len(g.state.Missiles.Entities) == 0 || len(g.state.Enemies.Entities) == 0 {
		return
	}

	removeMissiles := map[string]struct{}{}
	removeEnemies := map[string]struct{}{}
	scoreByShooter := map[string]int{}
	newExplosions := []Explosion{}
	splitEnemies := []Enemy{}

	for _, enemy := range g.state.Enemies.Entities {
		for _, missile := range g.state.Missiles.Entities {
			if collided(enemy.center(), enemy.Radius, missile.center(), missileRadius) {
				removeMissiles[missile.ID] = struct{}{}
				if _, seen := removeEnemies[enemy.ID]; !seen {
					removeEnemies[enemy.ID] = struct{}{}
					scoreByShooter[missile.ShooterID]++
					newExplosions = append(newExplosions, Explosion{
						ID:       g.newID(),
						X:        enemy.X,
						Y:        enemy.Y,
						Size:     enemy.Radius * 2,
						Lifespan: explosionLifespan,
					})
					splitEnemies = append(splitEnemies, g.splitEnemy(enemy)...)
				}
			}
		}
	}

	if len(removeMissiles) == 0 {
		return
	}

	g.state.Missiles.Entities = slices.DeleteFunc(g.state.Missiles.Entities, func(m Missile) bool {
		_, ok := removeMissiles[m.ID]
		return ok
	})
	g.state.Enemies.Entities = slices.DeleteFunc(g.state.Enemies.Entities, func(e Enemy) bool {
		_, ok := removeEnemies[e.ID]
		return ok
	})
	g.state.Enemies.Entities = append(g.state.Enemies.Entities, splitEnemies...)
	g.state.Enemies.Explosions.Entities = append(g.state.Enemies.Explosions.Entities, newExplosions...)
	g.state.Enemies.DestroyedCount += len(removeEnemies)

	for shooterID, points := range scoreByShooter {
		ship := g.state.Ships.Entities[shooterID]
		ship.Score += points
		g.state.Ships.Entities[shooterID] = ship
	}
}

func (g *Game) applyShipEnemyCollisionsLocked() {
	if len(g.state.Ships.Entities) == 0 || len(g.state.Enemies.Entities) == 0 {
		return
	}

	for id, ship := range g.state.Ships.Entities {
		if ship.isDead() {
			continue
		}

		for _, enemy := range g.state.Enemies.Entities {
			if !collided(ship.center(), shipRadius, enemy.center(), enemy.Radius) {
				continue
			}

			angle := repelAngle(ship.X, ship.Y, enemy.X, enemy.Y)
			ship.VelX = enemy.RepelVel * math.Cos(angle)
			ship.VelY = enemy.RepelVel * math.Sin(angle)
			ship.Health -= enemy.Damage
			if ship.Health <= 0 {
				now := g.now()
				ship.Health = 0
				ship.DestroyedAt = &now
				if ship.Score >= 50 {
					ship.Score -= 50
				} else {
					ship.Score = 0
				}
			}
		}

		g.state.Ships.Entities[id] = ship
	}
}

func (g *Game) spawnEnemiesLocked(now time.Time) {
	cfg := currentLevel(g.totalScoreLocked())
	if len(cfg.spawners) == 0 {
		return
	}

	spawner := cfg.spawners[g.rng.IntN(len(cfg.spawners))]
	if len(g.state.Enemies.Entities) >= spawner.limit {
		return
	}
	if !g.state.Enemies.LastSpawnedAt.IsZero() && now.Sub(g.state.Enemies.LastSpawnedAt) <= spawner.interval {
		return
	}

	g.state.Enemies.Entities = append(g.state.Enemies.Entities, g.spawnEnemy(spawner))
	g.state.Enemies.SpawnedCount++
	g.state.Enemies.LastSpawnedAt = now
}

func (g *Game) spawnEnemy(sp spawner) Enemy {
	if sp.kind == "bouncer" {
		x, y := g.spawnEdgePosition()
		angle := g.spawnAngleToCenter(x, y)
		vel := g.rngRange(sp.minVel, sp.maxVel)
		return Enemy{
			ID:       g.newID(),
			Kind:     "bouncer",
			X:        x,
			Y:        y,
			VelX:     vel * math.Cos(angle),
			VelY:     vel * math.Sin(angle),
			Radius:   bouncerRadius,
			Damage:   0,
			RepelVel: 1000,
		}
	}

	x, y := g.spawnEdgePosition()
	angle := g.spawnAngleToCenter(x, y)
	vel := g.rngRange(sp.minVel, sp.maxVel)
	scaleMax := sp.maxScale
	if scaleMax == 0 {
		scaleMax = 0.75
	}
	scale := g.rngRange(0.30, scaleMax)
	return Enemy{
		ID:       g.newID(),
		Kind:     "rock",
		X:        x,
		Y:        y,
		VelX:     vel * math.Cos(angle),
		VelY:     vel * math.Sin(angle),
		Scale:    scale,
		Radius:   rockBaseRadius * scale,
		Damage:   5 * scale,
		RepelVel: 200,
	}
}

func (g *Game) splitEnemy(enemy Enemy) []Enemy {
	if enemy.Kind != "rock" || enemy.Scale <= 0.75 {
		return nil
	}

	angle := g.rngRange(1, 360) * math.Pi / 180
	scale := enemy.Scale / 2
	radius := enemy.Radius
	result := make([]Enemy, 0, 4)

	for _, deg := range []float64{0, 90, 180, 270} {
		theta := angle + deg*math.Pi/180
		vel := g.rngRange(50, 100)
		childScale := g.rngRange(0.30, scale)
		result = append(result, Enemy{
			ID:       g.newID(),
			Kind:     "rock",
			X:        enemy.X + radius,
			Y:        enemy.Y + radius,
			VelX:     vel * math.Cos(theta),
			VelY:     vel * math.Sin(theta),
			Scale:    childScale,
			Radius:   rockBaseRadius * childScale,
			Damage:   5 * childScale,
			RepelVel: 200,
		})
	}

	return result
}

func (g *Game) updateLevelLocked() {
	cfg := currentLevel(g.totalScoreLocked())
	g.state.Level = cfg.level
	g.state.StartLevelScore = cfg.startScore
	g.state.NextLevelScore = cfg.nextLevelScore
	g.state.Score = g.totalScoreLocked()
}

func (g *Game) totalScoreLocked() int {
	total := 0
	for _, ship := range g.state.Ships.Entities {
		total += ship.Score
	}
	return total
}

func (g *Game) spawnEdgePosition() (float64, float64) {
	const padding = 50.0
	if g.rng.IntN(2) == 0 {
		x := []float64{-padding, g.state.Width + padding}[g.rng.IntN(2)]
		y := []float64{0, g.state.Height}[g.rng.IntN(2)]
		return x, y
	}
	x := []float64{0, g.state.Width}[g.rng.IntN(2)]
	y := []float64{-padding, g.state.Height + padding}[g.rng.IntN(2)]
	return x, y
}

func (g *Game) spawnAngleToCenter(x float64, y float64) float64 {
	centerX := g.state.Width / 2
	centerY := g.state.Height / 2
	arc := g.rngRange(-50, 50) * math.Pi / 180
	return math.Atan2(centerY-y, centerX-x) + arc
}

func (g *Game) rngRange(min float64, max float64) float64 {
	if max <= min {
		return min
	}
	return min + g.rng.Float64()*(max-min)
}

func (g *Game) newID() string {
	return idString(g.ids.Add(1))
}

func initialState() State {
	return State{
		Width:    defaultWorldWidth,
		Height:   defaultWorldHeight,
		Missiles: MissileSet{Entities: []Missile{}},
		Enemies: EnemySet{
			Entities:   []Enemy{},
			Explosions: ExplosionSet{Entities: []Explosion{}},
		},
		Ships: ShipSet{Entities: map[string]Ship{}},
	}
}

func (s *Ship) update(now time.Time, dt float64, worldWidth float64, worldHeight float64) {
	s.X = wrapDim(s.X+s.VelX*dt, worldWidth, shipRadius)
	s.Y = wrapDim(s.Y+s.VelY*dt, worldHeight, shipRadius)
	s.Angle += (s.VelAngle * math.Pi / 180) * dt
	s.VelX *= 1 - shipThrustFric
	s.VelY *= 1 - shipThrustFric
	s.VelAngle *= 1 - shipTurnFric
	s.Thrusting = now.Sub(s.ThrustedAt) < thrustDuration

	if s.isDead() {
		return
	}
	if s.Health > 0 {
		s.Health = math.Min(maxHealth, s.Health+healthRecharge)
	}
	s.UpdatedAt = now
}

func (s Ship) isDead() bool {
	return s.DestroyedAt != nil
}

func (s Ship) center() [2]float64 {
	return [2]float64{s.X + shipRadius, s.Y + shipRadius}
}

func (m *Missile) update(dt float64) {
	m.X += m.VelX * dt
	m.Y += m.VelY * dt
	m.Lifespan -= tickDuration
}

func (m Missile) center() [2]float64 {
	return [2]float64{m.X + missileRadius, m.Y + missileRadius}
}

func (e Enemy) center() [2]float64 {
	return [2]float64{e.X + e.Radius, e.Y + e.Radius}
}

func (e Enemy) outOfBounds(worldWidth float64, worldHeight float64) bool {
	const padding = 100.0
	return e.X < -padding || e.Y < -padding || e.X > worldWidth+padding || e.Y > worldHeight+padding
}

func (e *Enemy) update(dt float64) {
	e.X += e.VelX * dt
	e.Y += e.VelY * dt
}

func copyState(src State) State {
	ships := make(map[string]Ship, len(src.Ships.Entities))
	for id, ship := range src.Ships.Entities {
		ships[id] = ship
	}

	missiles := slices.Clone(src.Missiles.Entities)
	if missiles == nil {
		missiles = []Missile{}
	}

	enemies := slices.Clone(src.Enemies.Entities)
	if enemies == nil {
		enemies = []Enemy{}
	}

	explosions := slices.Clone(src.Enemies.Explosions.Entities)
	if explosions == nil {
		explosions = []Explosion{}
	}

	return State{
		Width:           src.Width,
		Height:          src.Height,
		Missiles:        MissileSet{Entities: missiles},
		Enemies:         EnemySet{Entities: enemies, Explosions: ExplosionSet{Entities: explosions}, SpawnedCount: src.Enemies.SpawnedCount, DestroyedCount: src.Enemies.DestroyedCount, LastSpawnedAt: src.Enemies.LastSpawnedAt},
		Ships:           ShipSet{Entities: ships},
		Score:           src.Score,
		Level:           src.Level,
		StartLevelScore: src.StartLevelScore,
		NextLevelScore:  cloneIntPtr(src.NextLevelScore),
	}
}

func wrapDim(value float64, limit float64, offset float64) float64 {
	withMod := math.Mod(math.Round(value+offset), limit)
	if withMod < 0 {
		withMod += limit
	}
	return withMod - math.Round(offset)
}

func collided(aCenter [2]float64, aRadius float64, bCenter [2]float64, bRadius float64) bool {
	dx := bCenter[0] - aCenter[0]
	dy := bCenter[1] - aCenter[1]
	distance := math.Sqrt(dx*dx + dy*dy)
	return distance <= aRadius+bRadius
}

func repelAngle(x1 float64, y1 float64, x2 float64, y2 float64) float64 {
	return math.Atan2(y2-y1, x2-x1) + math.Pi
}

func cloneIntPtr(value *int) *int {
	if value == nil {
		return nil
	}
	cloned := *value
	return &cloned
}

func idString(id uint64) string {
	return strconv.FormatUint(id, 10)
}

func currentLevel(score int) levelConfig {
	withNext := func(level int, start int, next int, spawners []spawner) levelConfig {
		return levelConfig{level: level, startScore: start, nextLevelScore: &next, spawners: spawners}
	}

	switch {
	case score < 15:
		return withNext(0, 0, 15, []spawner{{kind: "bouncer", limit: 5, interval: time.Second, minVel: 50, maxVel: 100}})
	case score < 30:
		return withNext(1, 15, 30, []spawner{{kind: "rock", limit: 5, interval: time.Second, minVel: 50, maxVel: 100, maxScale: 0.75}})
	case score < 60:
		return withNext(2, 30, 60, []spawner{
			{kind: "bouncer", limit: 5, interval: time.Second, minVel: 50, maxVel: 100},
			{kind: "rock", limit: 5, interval: time.Second, minVel: 50, maxVel: 100, maxScale: 0.75},
		})
	case score < 90:
		return withNext(3, 60, 90, []spawner{{kind: "rock", limit: 20, interval: 500 * time.Millisecond, minVel: 50, maxVel: 100, maxScale: 0.75}})
	case score < 120:
		return withNext(4, 90, 120, []spawner{
			{kind: "bouncer", limit: 20, interval: 500 * time.Millisecond, minVel: 50, maxVel: 100},
			{kind: "rock", limit: 20, interval: 500 * time.Millisecond, minVel: 50, maxVel: 100, maxScale: 0.75},
		})
	case score < 200:
		return withNext(5, 120, 200, []spawner{{kind: "rock", limit: 15, interval: 500 * time.Millisecond, minVel: 50, maxVel: 100, maxScale: 1.5}})
	case score < 280:
		return withNext(6, 200, 280, []spawner{
			{kind: "bouncer", limit: 15, interval: 500 * time.Millisecond, minVel: 50, maxVel: 100},
			{kind: "rock", limit: 15, interval: 500 * time.Millisecond, minVel: 50, maxVel: 100, maxScale: 1.5},
		})
	case score < 330:
		return withNext(7, 280, 330, []spawner{{kind: "rock", limit: 10, interval: 500 * time.Millisecond, minVel: 150, maxVel: 200, maxScale: 0.75}})
	case score < 430:
		return withNext(8, 330, 430, []spawner{
			{kind: "rock", limit: 20, interval: 500 * time.Millisecond, minVel: 150, maxVel: 200, maxScale: 0.75},
			{kind: "rock", limit: 20, interval: 500 * time.Millisecond, minVel: 50, maxVel: 100, maxScale: 1.5},
		})
	case score < 1000:
		return withNext(9, 430, 1000, []spawner{
			{kind: "bouncer", limit: 20, interval: 500 * time.Millisecond, minVel: 50, maxVel: 100},
			{kind: "rock", limit: 20, interval: 500 * time.Millisecond, minVel: 150, maxVel: 200, maxScale: 0.75},
			{kind: "rock", limit: 20, interval: 500 * time.Millisecond, minVel: 50, maxVel: 100, maxScale: 1.5},
		})
	case score < 2000:
		return withNext(10, 1000, 2000, []spawner{
			{kind: "bouncer", limit: 50, interval: 250 * time.Millisecond, minVel: 100, maxVel: 150},
			{kind: "rock", limit: 50, interval: 250 * time.Millisecond, minVel: 200, maxVel: 250, maxScale: 1.5},
		})
	case score < 5000:
		return withNext(11, 2000, 5000, []spawner{
			{kind: "bouncer", limit: 500, interval: 50 * time.Millisecond, minVel: 100, maxVel: 150},
			{kind: "rock", limit: 500, interval: 50 * time.Millisecond, minVel: 200, maxVel: 250, maxScale: 1.5},
		})
	default:
		return levelConfig{level: 12, startScore: 5000, nextLevelScore: nil, spawners: []spawner{{kind: "bouncer", limit: 500, interval: 50 * time.Millisecond, minVel: 200, maxVel: 250}}}
	}
}
