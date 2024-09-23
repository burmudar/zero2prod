use tracing::{subscriber::set_global_default, Subscriber};
use tracing_bunyan_formatter::{BunyanFormattingLayer, JsonStorageLayer};
use tracing_log::LogTracer;
use tracing_subscriber::{prelude::*, EnvFilter, Registry};

/// Compose multiple layers into a `tracing`'s subscriber
/// # Implementation notes
///
/// We are using `impl Subscriber` as return type to avoid having to
/// spell out the actual type of the return subscriber, which is
/// indeed quite complex
/// We need to ecplicityly call out the returned subscriber is
/// `Send` and `Sync` to make it possible to pass it to `init_subscriber`
pub fn get_subscriber(name: String, env_filter: String) -> impl Subscriber + Send + Sync {
    let env_fitler =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(env_filter));
    let formatting_layer = BunyanFormattingLayer::new(name.into(), std::io::stdout);
    Registry::default()
        .with(env_fitler)
        .with(JsonStorageLayer)
        .with(formatting_layer)
}

/// Register a subscriber as global default to process span data.
///
/// It should only be called once!
pub fn init_subscriber(subscriber: impl Subscriber + Send + Sync) {
    // Redirect all `log`'s events to our subscriber
    LogTracer::init().expect("failed to set logger");
    set_global_default(subscriber).expect("failed to set subscriber");
}
