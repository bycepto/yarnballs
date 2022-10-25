use crate::enemy::ID;
use crate::{collision, explosion::Explosion, utils};
use rand::{seq::SliceRandom, thread_rng, Rng};
use rustler::NifStruct;

// Entity

#[derive(NifStruct, Clone)]
#[module = "Yarnballs.Enemy.Bouncer"]
pub struct Bouncer {
    id: ID,
    updated_at: i64,
    pub x: f64,
    pub y: f64,
    vel_x: f64,
    vel_y: f64,
}

impl Bouncer {
    pub fn id(&self) -> ID {
        self.id
    }

    pub fn update(&mut self) {
        let updated_at = utils::now_in_millis();
        let dt = updated_at - self.updated_at;

        self.x += self.vel_x * ((dt as f64) / 1000.0);
        self.y += self.vel_y * ((dt as f64) / 1000.0);
        self.updated_at = updated_at;
    }

    const OUT_OF_BOUNDS_PADDING: f64 = 100.;

    pub fn is_out_of_bounds(&self) -> bool {
        self.x < -Bouncer::OUT_OF_BOUNDS_PADDING
            || self.y < -Bouncer::OUT_OF_BOUNDS_PADDING
            || self.x > utils::WIDTH + Bouncer::OUT_OF_BOUNDS_PADDING
            || self.y > utils::HEIGHT + Bouncer::OUT_OF_BOUNDS_PADDING
    }

    pub fn explode(&self) -> Explosion {
        Explosion::spawn(self.x, self.y, collision::Circle::radius(self) * 2.)
    }
}

const DEFAULT_MIN_VEL: f64 = 50.;
const DEFAULT_MAX_VEL: f64 = 100.;

const ARC: f64 = 50.;
const PADDING: f64 = 50.;

fn spawn_horizontal() -> (f64, f64) {
    let mut rng = thread_rng();

    let x = *[-PADDING, utils::WIDTH + PADDING].choose(&mut rng).unwrap();
    let y = *[0.0, utils::HEIGHT].choose(&mut rng).unwrap();
    (x, y)
}

fn spawn_vertical() -> (f64, f64) {
    let mut rng = thread_rng();

    let x = *[0.0, utils::WIDTH].choose(&mut rng).unwrap();
    let y = *[-PADDING, utils::HEIGHT + PADDING]
        .choose(&mut rng)
        .unwrap();
    (x, y)
}

pub fn spawn(min_vel: Option<f64>, max_vel: Option<f64>) -> Bouncer {
    let min_vel = min_vel.unwrap_or(DEFAULT_MIN_VEL);
    let max_vel = max_vel.unwrap_or(DEFAULT_MAX_VEL);

    // spawn vertical or horizontal
    let mut rng = thread_rng();
    let b = *[true, false].choose(&mut rng).unwrap();
    let (spawn_x, spawn_y) = if b {
        spawn_horizontal()
    } else {
        spawn_vertical()
    };

    let center_x = utils::WIDTH / 2.0;
    let center_y = utils::HEIGHT / 2.0;

    // random arc
    let angle_adjustment = rng.gen_range(-ARC..ARC).to_radians();
    let angle = (center_y - spawn_y).atan2(center_x - spawn_x) + angle_adjustment;

    // random velocity
    let vel_x = rng.gen_range(min_vel..max_vel) * angle.cos();
    let vel_y = rng.gen_range(min_vel..max_vel) * angle.sin();

    Bouncer {
        id: utils::new_uuid_as_u64_pair(),
        updated_at: utils::now_in_millis(),
        x: spawn_x,
        y: spawn_y,
        vel_x,
        vel_y,
    }
}

impl collision::Circle for Bouncer {
    fn radius(&self) -> f64 {
        256. / 2. * 0.3
    }

    fn center(&self) -> (f64, f64) {
        (self.x + self.radius(), self.y + self.radius())
    }
}
