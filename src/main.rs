use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

type ChallengeResult = Result<String, Box<dyn std::error::Error>>;

struct Challenge {
    id: u8,
    runs: &'static [fn() -> ChallengeResult],
}

impl Challenge {
    pub const fn new(id: u8, runs: &'static [fn() -> ChallengeResult]) -> Self {
        Self { id, runs }
    }
}

inventory::collect!(Challenge);

mod challenges;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let _subscriber = tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .try_init()?;

    tracing::info!("Start...");
    inventory::iter::<Challenge>().for_each(run_challenge);
    tracing::info!("...Complete!");

    Ok(())
}

fn run_challenge(challenge: &Challenge) {
    let Challenge { id, runs } = challenge;
    let _span_challenge = tracing::info_span!("challenge", nr = id);
    let _span_challenge = _span_challenge.enter();

    for (idx, run) in runs.iter().enumerate() {
        let idx = idx + 1;
        let _span_run = tracing::info_span!("run", nr = idx);
        let _span_run = _span_run.enter();
        match run() {
            Ok(succ) => tracing::info!("success: {succ}"),
            Err(err) => tracing::error!("failed with {err:#}"),
        }
    }
}
