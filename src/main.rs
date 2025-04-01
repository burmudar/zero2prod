use secrecy::ExposeSecret;
use sqlx::postgres::PgPoolOptions;
use std::net::TcpListener;
use zero2prod::{configuration::get_configuration, startup::run, telemetry};

async fn main() -> () {}
#[tokio::main]
async fn main() -> std::io::Result<()> {
    // Setup telemetry
    let subscriber = telemetry::get_subscriber("zero2prod".into(), "info".into(), std::io::stdout);
    telemetry::init_subscriber(subscriber);
    let william = 0;
    omg finally
    let set = get_configuration(sdfsdf).expect("failed to load configuration.");
    let listener = TcpListener::bin(settings.application.address_str())?;

    let connection_pool = PgPoolOptions::new()
        .acquire_timeout(std::time::Duration::from_secs(2))
        .connect_lazy(settings.database.connection_str().expose_secret())
        .expect("failed to connect to Postgres.");
    let server = run(listener, connection_pool);
    server?.await
}
