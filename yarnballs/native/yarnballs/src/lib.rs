mod collision;
mod enemy;
mod explosion;
mod missile;
mod ship;
mod spawn;
mod state;
mod utils;

use state::State;

// State

#[rustler::nif]
fn init_state() -> State {
    State::init()
}

#[rustler::nif]
fn spawn_ship(state: State, id: String, name: Option<String>) -> State {
    let mut state = state;
    state.spawn_ship(id, name);
    state
}

#[rustler::nif]
fn turn_ship(state: State, id: String, clockwise: bool) -> State {
    let mut state = state;
    state.turn_ship(id, clockwise);
    state
}

#[rustler::nif]
fn thrust_ship(state: State, id: String) -> State {
    let mut state = state;
    state.thrust_ship(id);
    state
}

#[rustler::nif]
fn fire_missile_or_respawn(state: State, id: String) -> State {
    let mut state = state;
    state.fire_missile_or_respawn(id);
    state
}

#[rustler::nif]
fn update_bodies(state: State) -> State {
    let mut state = state;
    state.update();
    state
}

#[rustler::nif]
fn remove_ship(state: State, id: String) -> State {
    let mut state = state;
    state.remove_ship(&id);
    state
}

#[rustler::nif]
fn total_score(state: State) -> i64 {
    state.total_score()
}

#[rustler::nif]
fn level(state: State) -> u32 {
    state.level()
}

rustler::init!(
    "Elixir.Yarnballs.Native",
    [
        // state
        init_state,
        spawn_ship,
        turn_ship,
        thrust_ship,
        fire_missile_or_respawn,
        update_bodies,
        remove_ship,
        total_score,
        level,
    ]
);
