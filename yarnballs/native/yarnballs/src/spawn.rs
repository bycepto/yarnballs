use crate::enemy;

pub trait Spawner {
    fn spawn(&self) -> enemy::Enemy;
    fn limit(&self) -> u32;
    fn interval(&self) -> u32;
}

#[derive(Default)]
struct Bouncers {
    limit: u32,
    interval: u32,
    min_vel: Option<f64>,
    max_vel: Option<f64>,
}

impl Spawner for Bouncers {
    fn spawn(&self) -> enemy::Enemy {
        enemy::Enemy::Bouncer(enemy::bouncer::spawn(self.min_vel, self.max_vel))
    }
    fn limit(&self) -> u32 {
        self.limit
    }
    fn interval(&self) -> u32 {
        self.interval
    }
}

#[derive(Default)]
struct Rocks {
    limit: u32,
    interval: u32,
    max_scale: Option<f64>,
    min_vel: Option<f64>,
    max_vel: Option<f64>,
}

impl Spawner for Rocks {
    fn spawn(&self) -> enemy::Enemy {
        enemy::Enemy::Rock(enemy::rock::spawn(
            self.max_scale,
            self.min_vel,
            self.max_vel,
        ))
    }
    fn limit(&self) -> u32 {
        self.limit
    }
    fn interval(&self) -> u32 {
        self.interval
    }
}

// Levels

pub mod spawners {
    use super::{Bouncers, Rocks, Spawner};

    pub fn a_few_bouncers() -> Vec<Box<dyn Spawner>> {
        vec![Box::new(Bouncers {
            limit: 5,
            interval: 1000,
            ..Default::default()
        })]
    }

    pub fn a_few_rocks() -> Vec<Box<dyn Spawner>> {
        vec![Box::new(Rocks {
            limit: 5,
            interval: 1000,
            ..Default::default()
        })]
    }

    pub fn a_few_bouncers_and_rocks() -> Vec<Box<dyn Spawner>> {
        let limit = 5;
        let interval = 1000;
        vec![
            Box::new(Bouncers {
                limit,
                interval,
                ..Default::default()
            }),
            Box::new(Rocks {
                limit,
                interval,
                ..Default::default()
            }),
        ]
    }

    pub fn rocks() -> Vec<Box<dyn Spawner>> {
        vec![Box::new(Rocks {
            limit: 20,
            interval: 500,
            ..Default::default()
        })]
    }

    pub fn bouncers_and_rocks() -> Vec<Box<dyn Spawner>> {
        let limit = 20;
        let interval = 500;
        vec![
            Box::new(Bouncers {
                limit,
                interval,
                ..Default::default()
            }),
            Box::new(Rocks {
                limit,
                interval,
                ..Default::default()
            }),
        ]
    }

    pub fn bigger_rocks() -> Vec<Box<dyn Spawner>> {
        let limit = 15;
        let interval = 500;
        vec![Box::new(Rocks {
            limit,
            interval,
            max_scale: Some(1.5),
            ..Default::default()
        })]
    }

    pub fn bouncers_and_bigger_rocks() -> Vec<Box<dyn Spawner>> {
        let limit = 15;
        let interval = 500;
        vec![
            Box::new(Bouncers {
                limit,
                interval,
                ..Default::default()
            }),
            Box::new(Rocks {
                limit,
                interval,
                max_scale: Some(1.5),
                ..Default::default()
            }),
        ]
    }

    pub fn faster_rocks() -> Vec<Box<dyn Spawner>> {
        let limit = 10;
        let interval = 500;
        vec![Box::new(Rocks {
            limit,
            interval,
            min_vel: Some(150.),
            max_vel: Some(200.),
            ..Default::default()
        })]
    }

    pub fn faster_rocks_and_bigger_rocks() -> Vec<Box<dyn Spawner>> {
        let limit = 20;
        let interval = 500;
        vec![
            Box::new(Rocks {
                limit,
                interval,
                min_vel: Some(150.),
                max_vel: Some(200.),
                ..Default::default()
            }),
            Box::new(Rocks {
                limit,
                interval,
                max_scale: Some(1.5),
                ..Default::default()
            }),
        ]
    }

    pub fn bouncers_faster_rocks_and_bigger_rocks() -> Vec<Box<dyn Spawner>> {
        let limit = 20;
        let interval = 500;
        vec![
            Box::new(Bouncers {
                limit,
                interval,
                ..Default::default()
            }),
            Box::new(Rocks {
                limit,
                interval,
                min_vel: Some(150.),
                max_vel: Some(200.),
                ..Default::default()
            }),
            Box::new(Rocks {
                limit,
                interval,
                max_scale: Some(1.5),
                ..Default::default()
            }),
        ]
    }

    pub fn madness() -> Vec<Box<dyn Spawner>> {
        let limit = 50;
        let interval = 250;
        vec![
            Box::new(Bouncers {
                limit,
                interval,
                min_vel: Some(100.),
                max_vel: Some(150.),
                ..Default::default()
            }),
            Box::new(Rocks {
                limit,
                interval,
                min_vel: Some(200.),
                max_vel: Some(250.),
                max_scale: Some(1.5),
                ..Default::default()
            }),
        ]
    }

    pub fn overkill() -> Vec<Box<dyn Spawner>> {
        let limit = 500;
        let interval = 50;
        vec![
            Box::new(Bouncers {
                limit,
                interval,
                min_vel: Some(100.),
                max_vel: Some(150.),
                ..Default::default()
            }),
            Box::new(Rocks {
                limit,
                interval,
                min_vel: Some(200.),
                max_vel: Some(250.),
                max_scale: Some(1.5),
                ..Default::default()
            }),
        ]
    }

    pub fn overbounce() -> Vec<Box<dyn Spawner>> {
        let limit = 500;
        let interval = 50;
        vec![Box::new(Bouncers {
            limit,
            interval,
            min_vel: Some(200.),
            max_vel: Some(250.),
            ..Default::default()
        })]
    }
}
