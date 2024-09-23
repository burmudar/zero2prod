use sqlx::PgPool;
use std::net::TcpListener;
use tracing::subscriber::set_global_default;
use tracing_bunyan_formatter::{BunyanFormattingLayer, JsonStorageLayer};
use tracing_log::LogTracer;
use tracing_subscriber::{prelude::*, EnvFilter, Registry};
use zero2prod::{configuration::get_configuration, startup::run};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // Redirect all `log`'s events to our subscriber
    LogTracer::init().expect("failed to set logger");

    let env_fitler = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let formatting_layer = BunyanFormattingLayer::new("zero2prod".into(), std::io::stdout);
    let subscriber = Registry::default()
        .with(env_fitler)
        .with(JsonStorageLayer)
        .with(formatting_layer);
    set_global_default(subscriber).expect("failed to set subscriber");

    let settings = get_configuration().expect("failed to load configuration.");
    let address = format!("127.0.0.1:{}", settings.application_port);
    let listener = TcpListener::bind(address)?;
    let connection_pool = PgPool::connect(&settings.database.connection_str())
        .await
        .expect("failed to connect to Postgres.");
    let server = run(listener, connection_pool);
    server?.await
}
