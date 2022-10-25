pub mod bouncer;
pub mod rock;

use crate::collision;
use crate::explosion::{Explosion, Explosions};
use crate::spawn;
use crate::utils;
use rand::{seq::SliceRandom, thread_rng};
use rustler::{NifStruct, NifUntaggedEnum};
use std::collections::HashMap;

pub type ID = (u64, u64);

#[derive(NifStruct)]
#[module = "Yarnballs.Enemies"]
pub struct Enemies {
    spawned_count: i64,
    destroyed_count: i64,
    pub entities: HashMap<ID, Enemy>,
    explosions: Explosions,
    // TODO: ideally, this can be HashSet at some point: https://github.com/rusterlium/rustler/pull/408
    remove_ids: HashMap<ID, bool>,
    last_spawned_at: i64,
}

impl Enemies {
    pub fn init() -> Self {
        Self {
            spawned_count: 0,
            destroyed_count: 0,
            entities: HashMap::new(),
            explosions: Explosions::init(),
            remove_ids: HashMap::new(),
            last_spawned_at: 0,
        }
    }

    pub fn spawn(&mut self, spawners: Vec<Box<dyn spawn::Spawner>>) {
        let last_spawned_at = utils::now_in_millis();
        let dt = last_spawned_at - self.last_spawned_at;

        let mut rng = thread_rng();
        match spawners.choose(&mut rng) {
            None => (),
            Some(spawner) => {
                if self.count() >= spawner.limit() || (dt as u32) <= spawner.interval() {
                    return;
                }

                let enemy = spawner.spawn();
                self.entities.insert(enemy.id(), enemy);
                self.last_spawned_at = last_spawned_at;
            }
        }
    }

    pub fn count(&self) -> u32 {
        self.entities.len() as u32
    }

    pub fn entities(&self) -> Vec<&Enemy> {
        self.entities.values().collect()
    }

    pub fn remove(&mut self, ids: Vec<ID>) {
        for id in ids.into_iter() {
            self.remove_ids.insert(id, true);
        }
    }

    pub fn update(&mut self) {
        self.explosions.update();
        self.entities.retain(|_, e| !e.is_out_of_bounds());
        self.entities.values_mut().for_each(|e| e.update());

        let remove_ids = &self.remove_ids;
        let to_explode: Vec<Enemy> = self
            .entities
            .values()
            .filter(|e| remove_ids.contains_key(&e.id()))
            // TODO: can we avoid cloning here?
            .cloned()
            .collect();
        let rock_splits: Vec<Enemy> = to_explode
            .iter()
            .filter(|e| remove_ids.contains_key(&e.id()))
            .flat_map(|e| match e {
                Enemy::Bouncer(_) => Vec::new(),
                Enemy::Rock(rock) => rock.split().into_iter().map(|r| Enemy::Rock(r)).collect(),
            })
            .collect();
        self.entities
            .retain(|_, e| !remove_ids.contains_key(&e.id()));
        rock_splits.into_iter().for_each(|e| {
            self.entities.insert(e.id(), e);
        });
        to_explode
            .into_iter()
            .for_each(|e| self.explosions.spawn(&e));
        self.remove_ids.clear()
    }

    pub fn apply_missile_collisions(&mut self, emcs: &Vec<collision::EnemyMissileCollision>) {
        let ids = emcs.into_iter().map(|(e, _)| *e).collect();
        self.remove(ids);
    }
}

#[derive(NifUntaggedEnum, Clone)]
pub enum Enemy {
    Bouncer(bouncer::Bouncer),
    Rock(rock::Rock),
}

impl Enemy {
    pub fn id(&self) -> ID {
        match self {
            Self::Bouncer(bouncer) => bouncer.id(),
            Self::Rock(rock) => rock.id(),
        }
    }

    pub fn x(&self) -> f64 {
        match self {
            Self::Bouncer(bouncer) => bouncer.x,
            Self::Rock(rock) => rock.x,
        }
    }

    pub fn y(&self) -> f64 {
        match self {
            Self::Bouncer(bouncer) => bouncer.y,
            Self::Rock(rock) => rock.y,
        }
    }

    pub fn repel_vel(&self) -> f64 {
        match self {
            Self::Bouncer(_) => 1000.,
            Self::Rock(_) => 200.,
        }
    }

    pub fn damage(&self) -> f64 {
        match self {
            Self::Bouncer(_) => 0.,
            Self::Rock(rock) => rock.damage(),
        }
    }

    pub fn explode(&self) -> Explosion {
        match self {
            Self::Bouncer(bouncer) => bouncer.explode(),
            Self::Rock(rock) => rock.explode(),
        }
    }

    pub fn is_out_of_bounds(&self) -> bool {
        match self {
            Self::Bouncer(bouncer) => bouncer.is_out_of_bounds(),
            Self::Rock(rock) => rock.is_out_of_bounds(),
        }
    }

    pub fn update(&mut self) {
        match self {
            Self::Bouncer(bouncer) => bouncer.update(),
            Self::Rock(rock) => rock.update(),
        }
    }
}

impl collision::Circle for Enemy {
    fn radius(&self) -> f64 {
        match self {
            Self::Bouncer(bouncer) => bouncer.radius(),
            Self::Rock(rock) => rock.radius(),
        }
    }

    fn center(&self) -> (f64, f64) {
        match self {
            Self::Bouncer(bouncer) => bouncer.center(),
            Self::Rock(rock) => rock.center(),
        }
    }
}
