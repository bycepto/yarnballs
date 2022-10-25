use crate::collision;
use crate::spawn;
use crate::{enemy::Enemies, missile, missile::Missiles, ship::Ships};
use rustler::NifStruct;
use std::collections::HashSet;

#[derive(NifStruct)]
#[module = "Yarnballs.State"]
pub struct State {
    missiles: Missiles,
    enemies: Enemies,
    ships: Ships,
}

impl State {
    pub fn init() -> Self {
        Self {
            missiles: Missiles::init(),
            enemies: Enemies::init(),
            ships: Ships::init(),
        }
    }

    pub fn total_score(&self) -> i64 {
        self.ships.total_score()
    }

    pub fn spawn_ship(&mut self, id: String, name: Option<String>) {
        self.ships.spawn(id, name);
    }

    pub fn turn_ship(&mut self, id: String, clockwise: bool) {
        self.ships.turn(id, clockwise);
    }

    pub fn thrust_ship(&mut self, id: String) {
        self.ships.thrust(id);
    }

    pub fn remove_ship(&mut self, id: &String) {
        self.ships.remove(id);
    }

    pub fn fire_missile_or_respawn(&mut self, id: String) {
        match self.ships.is_dead(&id) {
            Some(false) => match self.ships.spawn_missile(&id) {
                Some(missile) => self.missiles.add(missile),
                None => (),
            },
            Some(true) => self.ships.respawn(id.clone()),
            None => (),
        }
    }

    pub fn level(&self) -> u32 {
        self.level_with_spawner().0
    }

    fn level_with_spawner(&self) -> (u32, Vec<Box<dyn spawn::Spawner>>) {
        match self.total_score() {
            x if x < 15 => (0, spawn::spawners::a_few_bouncers()),
            x if x < 30 => (1, spawn::spawners::a_few_rocks()),
            x if x < 60 => (2, spawn::spawners::a_few_bouncers_and_rocks()),
            x if x < 90 => (3, spawn::spawners::rocks()),
            x if x < 120 => (4, spawn::spawners::bouncers_and_rocks()),
            x if x < 200 => (5, spawn::spawners::bigger_rocks()),
            x if x < 280 => (6, spawn::spawners::bouncers_and_bigger_rocks()),
            x if x < 330 => (7, spawn::spawners::faster_rocks()),
            x if x < 430 => (8, spawn::spawners::faster_rocks_and_bigger_rocks()),
            x if x < 1000 => (9, spawn::spawners::bouncers_faster_rocks_and_bigger_rocks()),
            // TODO: these levels aren't supposed to be beatable
            x if x < 2000 => (10, spawn::spawners::madness()),
            // TODO: this level has noticeable lag
            x if x < 5000 => (11, spawn::spawners::overkill()),
            _ => (12, spawn::spawners::overbounce()),
        }
    }

    pub fn update(&mut self) {
        self.missiles.update();
        self.enemies.update();
        self.ships.update();

        self.update_collisions();
        self.spawn_enemies();
    }

    fn spawn_enemies(&mut self) {
        self.enemies.spawn(self.level_with_spawner().1);
    }

    pub fn update_collisions<'a>(&mut self) {
        // Initialize spatial hash with collidable entities
        let mut sh = collision::new_spatial_hash::<'a>();
        for m in &mut self.missiles.entities {
            sh.insert_missile(m);
        }
        for e in &mut self.enemies.entities() {
            sh.insert_enemy(e);
        }
        for e in &mut self.ships.entities() {
            sh.insert_ship(e);
        }

        // Apply enemy-missile and ship-enemy collisions
        let mut enemy_missile_collisions: HashSet<collision::EnemyMissileCollision> =
            HashSet::new();
        let mut ship_enemy_collisions: HashSet<collision::ShipEnemyCollision> = HashSet::new();
        sh.spaces().for_each(|s| {
            enemy_missile_collisions.extend(s.enemy_missile_collisions());
            ship_enemy_collisions.extend(s.ship_enemy_collisions());
        });
        self.apply_enemy_missile_collisions(
            enemy_missile_collisions.into_iter().collect::<Vec<_>>(),
        );
        self.apply_ship_enemy_collisions(ship_enemy_collisions.into_iter().collect::<Vec<_>>());
    }

    pub fn apply_enemy_missile_collisions(&mut self, emcs: Vec<collision::EnemyMissileCollision>) {
        // apply entity-specific collision effects
        self.missiles.apply_enemy_collisions(&emcs);
        self.enemies.apply_missile_collisions(&emcs);

        // increase scores
        let ids: Vec<missile::ID> = emcs.into_iter().map(|(_, m)| m).collect();
        self.missiles
            .shooter_counts(&ids)
            .into_iter()
            .for_each(|(id, pts)| self.ships.increase_score(id, pts));
    }

    pub fn apply_ship_enemy_collisions(&mut self, secs: Vec<collision::ShipEnemyCollision>) {
        secs.into_iter()
            .for_each(|(sid, eid)| match self.enemies.entities.get(&eid) {
                None => (),
                Some(enemy) => self.ships.collide_with(sid, enemy),
            });
    }
}
