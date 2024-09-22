//! tests/health_check.rs
use std::net::TcpListener;

use sqlx::{Connection, Executor, PgConnection, PgPool};
use uuid::Uuid;
use zero2prod::configuration::{self, DatabaseSettings};

pub struct TestApp {
    pub address: String,
    pub db_pool: PgPool,
}

async fn spawn_app() -> TestApp {
    // port 0 is special OS wise - OS will scan and give us the first open port
    let listener = TcpListener::bind("127.0.0.1:0").expect("faield to bind to random port");
    let port = listener.local_addr().unwrap().port();

    let mut cfg = configuration::get_configuration().expect("failed to read configuration");
    cfg.database.name = Uuid::new_v4().to_string();
    let pool = configure_database(&cfg.database).await;

    let server = zero2prod::startup::run(listener, pool.clone()).expect("Failed to bind address");

    let _ = tokio::spawn(server);
    TestApp {
        address: format!("http://127.0.0.1:{}", port),
        db_pool: pool,
    }
}

pub async fn configure_database(config: &DatabaseSettings) -> PgPool {
    let conn_str = config.connection_str_without_name();
    PgConnection::connect(&conn_str)
        .await
        .expect("failed to connect to Postgres")
        .execute(format!(r#"CREATE DATABASE "{}";"#, config.name).as_str())
        .await
        .expect("failed to create database");
    // new db so we need to migrate it
    let pool = PgPool::connect(&config.connection_str())
        .await
        .expect("failed to create connection pool");
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("failed to run migrations on db");
    pool
}

#[tokio::test]
async fn health_check_works() {
    let app = spawn_app().await;

    let client = reqwest::Client::new();

    let response = client
        .get(format!("{}/health_check", app.address))
        .send()
        .await
        .expect("Faield to execute request");
    assert!(response.status().is_success());
    assert_eq!(Some(0), response.content_length());
}

#[tokio::test]
async fn subscribe_returns_200_for_valid_form_data() {
    let app = spawn_app().await;
    let client = reqwest::Client::new();

    let body = "name=le%20guin&email=ursu-la_le_guin%40gmail.com";
    let resp = client
        .post(&format!("{}/subscriptions", app.address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("failed to execute request");

    assert_eq!(200, resp.status().as_u16());

    let saved = sqlx::query!("SELECT email, name FROM subscriptions")
        .fetch_one(&app.db_pool)
        .await
        .expect("Failed to fetch saved subscription.");

    assert_eq!(saved.email, "ursu-la_le_guin@gmail.com");
    assert_eq!(saved.name, "le guin");
}

#[tokio::test]
async fn subscribe_returns_400_when_data_is_missing() {
    let app = spawn_app().await;
    let client = reqwest::Client::new();

    let test_cases = vec![
        ("name=le%20guin", "missing the email"),
        ("email=ursula_le_guin%40gmail.com", "missing the name"),
        ("", "missing both the name and email"),
    ];

    for (invalid_body, err_msg) in test_cases {
        let resp = client
            .post(&format!("{}/subscriptions", app.address))
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body(invalid_body)
            .send()
            .await
            .expect("failed to execute the request");

        assert_eq!(
            400,
            resp.status().as_u16(),
            "The API did not fail with 400 Bad Request when the payload was {}",
            err_msg
        )
    }
}
