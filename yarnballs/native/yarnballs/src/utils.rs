// utilities and constants
use chrono::prelude::Utc;
use std::f64::consts::PI;
use uuid::Uuid;

pub const WIDTH: f64 = 640.;
pub const HEIGHT: f64 = 480.;

/*
Wrap entity around if the reach a position less then `0` or more than `limit`.

`offset` specifies at what point we should the entity wrap. If there is an
entity that is `x` pixels wide and the `offset` is set to `x / 2` - this will
make it so the entity will start wrapping when it is halfway across the
wrapping limit.
*/
// TODO: just make this wrap screen?
pub fn wrap_dim(value: f64, limit: i64, offset: f64) -> f64 {
    let with_mod = modulo((value + offset).round() as i64, limit);
    (with_mod - (offset.round() as i64)) as f64
}

fn modulo(a: i64, b: i64) -> i64 {
    ((a % b) + b) % b
}

pub fn now_in_millis() -> i64 {
    Utc::now().timestamp_millis()
}

pub fn new_uuid() -> String {
    Uuid::new_v4().to_string()
}

pub fn new_uuid_as_u64_pair() -> (u64, u64) {
    Uuid::new_v4().as_u64_pair()
}

pub fn repel_angel(x1: f64, y1: f64, x2: f64, y2: f64) -> f64 {
    let dy = y2 - y1;
    let dx = x2 - x1;

    dy.atan2(dx) + PI
}
