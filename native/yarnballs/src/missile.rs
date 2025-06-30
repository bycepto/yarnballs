use crate::{collision, ship, utils};
use rustler::NifStruct;
use std::collections::{HashMap, HashSet};

pub type ID = (u64, u64);

// Collection

#[derive(NifStruct)]
#[module = "Yarnballs.Missiles"]
pub struct Missiles {
    pub entities: Vec<Missile>,
    // TODO: ideally, this can be HashSet at some point: https://github.com/rusterlium/rustler/pull/408
    remove_ids: HashMap<ID, bool>,
}

impl Missiles {
    pub fn init() -> Self {
        Self {
            entities: Vec::new(),
            remove_ids: HashMap::new(),
        }
    }

    pub fn add(&mut self, missile: Missile) {
        self.entities.push(missile);
    }

    pub fn remove(&mut self, ids: Vec<ID>) {
        for id in ids.into_iter() {
            self.remove_ids.insert(id, true);
        }
    }

    pub fn update(&mut self) {
        let remove_ids = &self.remove_ids;
        self.entities
            .retain(|e| e.lifespan > 0 && !remove_ids.contains_key(&e.id));
        self.entities.iter_mut().for_each(|e| e.update());
        self.remove_ids.clear()
    }

    pub fn apply_enemy_collisions(&mut self, emcs: &Vec<collision::EnemyMissileCollision>) {
        let ids = emcs.iter().map(|(_, m)| *m).collect();
        self.remove(ids);
    }

    pub fn shooter_counts(&self, ids: &Vec<ID>) -> HashMap<ship::ID, i64> {
        let set: HashSet<&ID> = ids.into_iter().collect();
        self.entities
            .iter()
            .filter(|m| set.contains(&m.id))
            .fold(HashMap::new(), {
                |mut map, m| {
                    // TODO: avoid clone?
                    map.entry(m.shooter_id.clone())
                        .and_modify(|c| *c += 1)
                        .or_insert(1);
                    map
                }
            })
    }
}

// Entity

#[derive(NifStruct, Clone)]
#[module = "Yarnballs.Missile"]
pub struct Missile {
    pub id: ID,
    shooter_id: String,
    updated_at: i64,
    x: f64,
    y: f64,
    vel_x: f64,
    vel_y: f64,
    lifespan: i64,
}

const LIFESPAN: i64 = 1000;
const VEL: f64 = 500.;

impl Missile {
    // TODO: consider passing a map?
    pub fn spawn(shooter_id: String, x: f64, y: f64, angle: f64) -> Self {
        let vel_x = VEL * angle.cos();
        let vel_y = VEL * angle.sin();

        Self {
            id: utils::new_uuid_as_u64_pair(),
            shooter_id,
            updated_at: utils::now_in_millis(),
            x,
            y,
            vel_x,
            vel_y,
            lifespan: LIFESPAN,
        }
    }

    fn update(&mut self) {
        let updated_at = utils::now_in_millis();
        let dt = updated_at - self.updated_at;

        self.x = self.x + self.vel_x * ((dt as f64) / 1000.0);
        self.y = self.y + self.vel_y * ((dt as f64) / 1000.0);
        self.lifespan = self.lifespan - dt;
        self.updated_at = updated_at;
    }
}

impl collision::Circle for Missile {
    fn radius(&self) -> f64 {
        5.
    }

    fn center(&self) -> (f64, f64) {
        (self.x + self.radius(), self.y + self.radius())
    }
}
