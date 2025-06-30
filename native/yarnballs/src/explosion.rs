use crate::enemy::Enemy;
use crate::utils;
use rustler::NifStruct;

#[derive(NifStruct)]
#[module = "Yarnballs.Explosions"]
pub struct Explosions {
    entities: Vec<Explosion>,
}

impl Explosions {
    pub fn init() -> Self {
        Self {
            entities: Vec::new(),
        }
    }

    pub fn spawn(&mut self, enemy: &Enemy) {
        let explosion = enemy.explode();
        self.entities.push(explosion)
    }

    pub fn update(&mut self) {
        self.entities.retain(|e| e.lifespan > 0);
        self.entities.iter_mut().for_each(|e| e.update());
    }
}

#[derive(NifStruct)]
#[module = "Yarnballs.Explosion"]
pub struct Explosion {
    id: String,
    updated_at: i64,
    x: f64,
    y: f64,
    // the size of the thing that is exploding - used to determine scale.
    size: f64,
    lifespan: i64,
}

const LIFESPAN: i64 = 1000;

impl Explosion {
    pub fn spawn(x: f64, y: f64, size: f64) -> Self {
        Self {
            id: utils::new_uuid(),
            updated_at: utils::now_in_millis(),
            x,
            y,
            size,
            lifespan: LIFESPAN,
        }
    }

    pub fn update(&mut self) {
        let updated_at = utils::now_in_millis();
        let dt = updated_at - self.updated_at;

        self.lifespan -= dt;
        self.updated_at = updated_at;
    }
}
