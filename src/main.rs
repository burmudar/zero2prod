use secrecy::ExposeSecret;
use sqlx::PgPool;
use std::net::TcpListener;
use zero2prod::{configuration::get_configuration, startup::run, telemetry};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // Setup telemetry
    let subscriber = telemetry::get_subscriber("zero2prod".into(), "info".into(), std::io::stdout);
    telemetry::init_subscriber(subscriber);

    let settings = get_configuration().expect("failed to load configuration.");
    let listener = TcpListener::bind(settings.application.address_str())?;
    let connection_pool = PgPool::connect_lazy(settings.database.connection_str().expose_secret())
        .expect("failed to connect to Postgres.");
    let server = run(listener, connection_pool);
    server?.await
}
