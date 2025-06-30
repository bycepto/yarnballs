use crate::{enemy, enemy::Enemy, missile, missile::Missile, ship, ship::Ship};
use std::collections::{hash_map::Values, HashMap};

fn distance(p1: (f64, f64), p2: (f64, f64)) -> f64 {
    let (x1, y1) = p1;
    let (x2, y2) = p2;

    ((x2 - x1).powi(2) + (y2 - y1).powi(2)).sqrt()
}

pub trait Circle {
    fn center(&self) -> (f64, f64);
    fn radius(&self) -> f64;
}

pub fn collided<T: Circle, U: Circle>(circle1: &T, circle2: &U) -> bool {
    let dist = distance(circle1.center(), circle2.center());

    dist <= circle1.radius() + circle2.radius()
}

struct Rectangle {
    min_x: i64,
    max_x: i64,
    min_y: i64,
    max_y: i64,
}

fn to_rect<T: Circle>(circle: &T) -> Rectangle {
    let (x, y) = circle.center();
    let r = circle.radius();

    Rectangle {
        min_x: (x - r).floor() as i64,
        max_x: (x + r).ceil() as i64,
        min_y: (y - r).floor() as i64,
        max_y: (y + r).ceil() as i64,
    }
}

#[derive(Default)]
pub struct Space<'a> {
    missiles: Vec<&'a Missile>,
    enemies: Vec<&'a Enemy>,
    ships: Vec<&'a Ship>,
}

impl<'a> Space<'a> {
    pub fn enemy_missile_collisions(&self) -> Vec<EnemyMissileCollision> {
        self.enemies
            .iter()
            .flat_map(|e| {
                self.missiles
                    .iter()
                    .filter(|m| collided(*e, **m))
                    .map(|m| (e.id(), m.id))
                    .collect::<Vec<EnemyMissileCollision>>()
            })
            .collect()
    }

    pub fn ship_enemy_collisions(&self) -> Vec<ShipEnemyCollision> {
        self.ships
            .iter()
            .flat_map(|s| {
                self.enemies
                    .iter()
                    .filter(|e| !s.is_dead() && collided(*s, **e))
                    // TODO: avoid cloning
                    .map(|e| (s.id.clone(), e.id()))
                    .collect::<Vec<ShipEnemyCollision>>()
            })
            .collect()
    }
}

pub struct SpatialHash<'a> {
    cell_size: u32,
    bodies: HashMap<(i64, i64), Space<'a>>,
}

pub fn new_spatial_hash<'a>() -> SpatialHash<'a> {
    SpatialHash {
        cell_size: 50,
        bodies: HashMap::new(),
    }
}

enum Body<'a> {
    Missile(&'a Missile),
    Enemy(&'a Enemy),
    Ship(&'a Ship),
}

impl<'a> SpatialHash<'a> {
    fn hash_dim(&self, x: i64) -> i64 {
        (x as f64 / self.cell_size as f64).floor() as i64
    }

    fn hash(&self, point: (i64, i64)) -> (i64, i64) {
        let (x, y) = point;
        (self.hash_dim(x), self.hash_dim(y))
    }

    pub fn insert_missile(&mut self, missile: &'a Missile) {
        self.insert(Body::Missile(missile));
    }

    pub fn insert_enemy(&mut self, enemy: &'a Enemy) {
        self.insert(Body::Enemy(enemy));
    }

    pub fn insert_ship(&mut self, ship: &'a Ship) {
        self.insert(Body::Ship(ship));
    }

    pub fn spaces(&self) -> Values<(i64, i64), Space<'a>> {
        self.bodies.values()
    }

    fn insert(&mut self, body: Body<'a>) {
        let b = match body {
            Body::Missile(m) => to_rect(m),
            Body::Enemy(e) => to_rect(e),
            Body::Ship(s) => to_rect(s),
        };
        let (min_x, max_x) = self.hash((b.min_x, b.max_x));
        let (min_y, max_y) = self.hash((b.min_y, b.max_y));

        (min_x..(max_x + 1))
            .flat_map(|x| {
                (min_y..(max_y + 1))
                    .map(|y| (x, y))
                    .collect::<Vec<(i64, i64)>>()
            })
            .for_each(|k| {
                let space = self.bodies.entry(k).or_default();
                match body {
                    Body::Missile(m) => (*space).missiles.push(m),
                    Body::Enemy(e) => (*space).enemies.push(e),
                    // TODO: avoid cloning?
                    Body::Ship(s) => (*space).ships.push(s),
                };
            })
    }
}

pub type ShipEnemyCollision = (ship::ID, enemy::ID);

pub type EnemyMissileCollision = (enemy::ID, missile::ID);
