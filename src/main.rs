use sqlx::{Connection, PgConnection};
use std::net::TcpListener;
use zero2prod::{configuration::get_configuration, startup::run};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let settings = get_configuration().expect("failed to load configuration.");
    let address = format!("127.0.0.1:{}", settings.application_port);
    let listener = TcpListener::bind(address)?;
    let connection = PgConnection::connect(&settings.database.connection_str())
        .await
        .expect("failed to connect to Postgres.");
    run(listener, connection)?.await
}
