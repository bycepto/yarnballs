use crate::{collision, utils};
use crate::{enemy::Enemy, missile::Missile};
use rustler::NifStruct;
use std::collections::HashMap;

pub type ID = String;

// Collection

#[derive(NifStruct)]
#[module = "Yarnballs.PlayerShips"]
pub struct Ships {
    entities: HashMap<ID, Ship>,
}

impl Ships {
    pub fn init() -> Self {
        Self {
            entities: HashMap::new(),
        }
    }

    pub fn entities(&self) -> Vec<&Ship> {
        self.entities.values().collect()
    }

    pub fn total_score(&self) -> i64 {
        self.entities.values().map(|s| s.score).sum()
    }

    pub fn increase_score(&mut self, id: ID, points: i64) {
        self.entities.entry(id).and_modify(|e| e.score += points);
    }

    pub fn is_dead(&self, id: &ID) -> Option<bool> {
        self.entities.get(id).map(|e| e.is_dead())
    }

    pub fn spawn_missile(&self, id: &ID) -> Option<Missile> {
        self.entities.get(id).map(|e| e.spawn_missile())
    }

    pub fn spawn(&mut self, id: ID, name: Option<String>) {
        let ship = spawn(id.clone(), name);
        self.entities.insert(id.clone(), ship);
    }

    pub fn update(&mut self) {
        self.entities.retain(|_, s| !s.remove);
        self.entities.values_mut().for_each(|s| s.update())
    }

    pub fn respawn(&mut self, id: ID) {
        self.entities.entry(id).and_modify(|s| s.respawn());
    }

    pub fn turn(&mut self, id: ID, clockwise: bool) {
        self.entities.entry(id).and_modify(|s| s.turn(clockwise));
    }

    pub fn thrust(&mut self, id: ID) {
        self.entities.entry(id).and_modify(|s| s.thrust());
    }

    pub fn collide_with(&mut self, id: ID, enemy: &Enemy) {
        self.entities
            .entry(id)
            .and_modify(|s| s.collide_with(enemy));
    }

    pub fn remove(&mut self, id: &ID) {
        self.entities.remove(id);
    }
}

// Entity

#[derive(NifStruct, Clone)]
#[module = "Yarnballs.PlayerShip"]
pub struct Ship {
    pub id: ID,
    // TODO: must this be an option?
    name: Option<String>,
    updated_at: i64,
    x: f64,
    y: f64,
    vel_x: f64,
    vel_y: f64,
    angle: f64,
    vel_angle: f64,
    thrusted_at: f64,
    thrusting: bool,
    health: f64,
    score: i64,
    destroyed_at: Option<i64>,
    remove: bool,
}

const MAX_HEALTH: f64 = 100.;
const THRUST_DURATION: f64 = 50.;

pub fn spawn(id: ID, name: Option<String>) -> Ship {
    Ship {
        id,
        name,
        updated_at: utils::now_in_millis(),
        x: 0.,
        y: 0.,
        vel_x: 0.,
        vel_y: 0.,
        angle: 0.,
        vel_angle: 0.,
        thrusted_at: -THRUST_DURATION,
        thrusting: false,
        health: MAX_HEALTH,
        score: 0,
        destroyed_at: None,
        remove: false,
    }
}

impl Ship {
    const HEALTH_RECHARGE: f64 = 0.005;
    // 15 minute kick delay
    const KICK_DELAY: i64 = 1000 * 60 * 15;
    const THRUST_FRICTION: f64 = 0.05;
    const ACCELERATION: f64 = 20.;
    const TURN_ACCELERATION: f64 = 300.;
    const TURN_FRICTION: f64 = 0.95;

    fn spawn_missile(&self) -> Missile {
        let offset = self.radius() * self.angle;
        let x = offset.cos() + self.x + self.radius();
        let y = offset.sin() + self.y + self.radius();
        Missile::spawn(self.id.clone(), x, y, self.angle)
    }

    fn radius(&self) -> f64 {
        45.
    }

    fn turn(&mut self, clockwise: bool) {
        self.vel_angle += Self::TURN_ACCELERATION * if clockwise { 1. } else { -1. };
    }

    fn thrust(&mut self) {
        let vel_x = Self::ACCELERATION * self.angle.cos();
        let vel_y = Self::ACCELERATION * self.angle.sin();

        self.thrusted_at = utils::now_in_millis() as f64;
        self.vel_x += vel_x;
        self.vel_y += vel_y;
    }

    fn update(&mut self) {
        self.update_position();
        self.updated_health()
    }

    fn update_position(&mut self) {
        let updated_at = utils::now_in_millis();
        let dt = (updated_at - self.updated_at) as f64;
        let x = self.x + self.vel_x * (dt / 1000.);
        let y = self.y + self.vel_y * (dt / 1000.);

        self.updated_at = updated_at;
        self.x = utils::wrap_dim(x, utils::WIDTH as i64, self.radius());
        self.y = utils::wrap_dim(y, utils::HEIGHT as i64, self.radius());

        self.angle = self.angle + self.vel_angle.to_radians() * (dt / 1000.);

        self.vel_x = self.vel_x * (1. - Ship::THRUST_FRICTION);
        self.vel_y = self.vel_y * (1. - Ship::THRUST_FRICTION);
        self.vel_angle = self.vel_angle * (1. - Ship::TURN_FRICTION);
        self.thrusting = (updated_at as f64) - self.thrusted_at < THRUST_DURATION;
    }

    fn updated_health(&mut self) {
        let now = utils::now_in_millis();
        if self.is_dead() {
            let dt = now - self.updated_at;
            // TODO: move this to a higher level
            if dt > Ship::KICK_DELAY {
                self.remove = true;
            }
        } else if self.health <= 0. {
            self.destroyed_at = Some(now);
            self.score = (self.score - 50).max(0);
        } else {
            self.health = (self.health + Ship::HEALTH_RECHARGE).min(MAX_HEALTH);
        }
    }

    fn respawn(&mut self) {
        if self.is_dead() {
            self.destroyed_at = None;
            self.health = MAX_HEALTH;
        }
    }

    pub fn is_dead(&self) -> bool {
        self.destroyed_at.is_some()
    }

    pub fn collide_with(&mut self, enemy: &Enemy) {
        let new_angle = utils::repel_angel(self.x, self.y, enemy.x(), enemy.y());
        let repel_vel = enemy.repel_vel();

        self.vel_x = repel_vel * new_angle.cos();
        self.vel_y = repel_vel * new_angle.sin();
        self.health -= enemy.damage();
    }
}

impl collision::Circle for Ship {
    fn radius(&self) -> f64 {
        self.radius()
    }

    fn center(&self) -> (f64, f64) {
        (self.x + self.radius(), self.y + self.radius())
    }
}
