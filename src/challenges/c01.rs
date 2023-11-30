use tracing::instrument;

use crate::{Challenge, ChallengeResult};

inventory::submit! {
    Challenge::new(1, &[run_a, run_b])
}

#[instrument]
fn run_a() -> ChallengeResult {
    tracing::debug!("what");
    Ok("it works".into())
}

#[instrument]
fn run_b() -> ChallengeResult {
    Err("it doesn't".into())
}
