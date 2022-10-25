use crate::enemy::ID;
use crate::{collision, explosion::Explosion, utils};
use rand::{seq::SliceRandom, thread_rng, Rng};
use rustler::NifStruct;

// Entity

#[derive(NifStruct, Clone)]
#[module = "Yarnballs.Enemy.Rock"]
pub struct Rock {
    id: ID,
    updated_at: i64,
    pub x: f64,
    pub y: f64,
    vel_x: f64,
    vel_y: f64,
    scale: f64,
}

const PADDING: f64 = 50.;
const ARC: f64 = 50.;
const DEFAULT_MIN_VEL: f64 = 50.;
const DEFAULT_MAX_VEL: f64 = 100.;
const DEFAULT_SCALE: f64 = 0.75;
const BASE_DAMAGE: f64 = 5.;

impl Rock {
    pub fn id(&self) -> ID {
        self.id
    }

    pub fn damage(&self) -> f64 {
        BASE_DAMAGE * self.scale
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
        self.x < -Rock::OUT_OF_BOUNDS_PADDING
            || self.y < -Rock::OUT_OF_BOUNDS_PADDING
            || self.x > utils::WIDTH + Rock::OUT_OF_BOUNDS_PADDING
            || self.y > utils::HEIGHT + Rock::OUT_OF_BOUNDS_PADDING
    }

    pub fn explode(&self) -> Explosion {
        Explosion::spawn(self.x, self.y, collision::Circle::radius(self) * 2.)
    }

    fn radius(&self) -> f64 {
        collision::Circle::radius(self)
    }

    pub fn split(&self) -> Vec<Self> {
        if self.scale <= DEFAULT_SCALE {
            Vec::new()
        } else {
            // get RNG
            let mut rng = thread_rng();

            // random angle
            let angle = rng.gen_range(1_f64..360_f64).to_radians();

            let radius = self.radius();

            [0_f64, 90_f64, 180_f64, 270_f64]
                .iter()
                .map(|degs| {
                    spawn_at(
                        self.x + radius,
                        self.y + radius,
                        angle + degs.to_radians(),
                        Some(self.scale / 2.),
                        None,
                        None,
                    )
                })
                .collect()
        }
    }
}

pub fn spawn(max_scale: Option<f64>, min_vel: Option<f64>, max_vel: Option<f64>) -> Rock {
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

    spawn_at(spawn_x, spawn_y, angle, max_scale, min_vel, max_vel)
}

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

fn spawn_at(
    x: f64,
    y: f64,
    angle: f64,
    max_scale: Option<f64>,
    min_vel: Option<f64>,
    max_vel: Option<f64>,
) -> Rock {
    let max_scale = max_scale.unwrap_or(DEFAULT_SCALE);
    let min_vel = min_vel.unwrap_or(DEFAULT_MIN_VEL);
    let max_vel = max_vel.unwrap_or(DEFAULT_MAX_VEL);

    // get RNG
    let mut rng = thread_rng();

    // random velocity
    let vel_x = rng.gen_range(min_vel..max_vel) * angle.cos();
    let vel_y = rng.gen_range(min_vel..max_vel) * angle.sin();

    // random scale
    let scale = rng.gen_range(30.0..(max_scale * 100.)) / 100.;

    Rock {
        id: utils::new_uuid_as_u64_pair(),
        updated_at: utils::now_in_millis(),
        x,
        y,
        vel_x,
        vel_y,
        scale,
    }
}

impl collision::Circle for Rock {
    fn radius(&self) -> f64 {
        45. * self.scale
    }

    fn center(&self) -> (f64, f64) {
        (self.x + self.radius(), self.y + self.radius())
    }
}
