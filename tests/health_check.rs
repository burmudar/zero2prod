//! tests/health_check.rs
use std::net::TcpListener;

use sqlx::{Connection, PgConnection};
use zero2prod::configuration::get_configuration;

#[tokio::test]
async fn health_check_works() {
    let address = spawn_app();

    let client = reqwest::Client::new();

    let response = client
        .get(format!("{}/health_check", address))
        .send()
        .await
        .expect("Faield to execute request");
    assert!(response.status().is_success());
    assert_eq!(Some(0), response.content_length());
}

fn spawn_app() -> String {
    // port 0 is special OS wise - OS will scan and give us the first open port
    let listener = TcpListener::bind("127.0.0.1:0").expect("faield to bind to random port");
    let port = listener.local_addr().unwrap().port();
    let server = zero2prod::startup::run(listener).expect("Failed to bind address");

    let _ = tokio::spawn(server);
    format!("http://127.0.0.1:{}", port)
}

#[tokio::test]
async fn subscribe_returns_200_for_valid_form_data() {
    let app_address = spawn_app();
    let cfg = get_configuration().expect("failed to load configuration.");
    let conn_str = cfg.database.connection_str();

    let mut connection = PgConnection::connect(&conn_str)
        .await
        .expect("failed to connect to Postgres DB");

    let client = reqwest::Client::new();

    let body = "name=le%20guin&email=ursu-la_le_guin%40@gmail.com";
    let resp = client
        .post(&format!("{}/subscriptions", &app_address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("failed to execute request");

    assert_eq!(200, resp.status().as_u16());

    let saved = sqlx::query!("SELECT email, name FROM subscriptions")
        .fetch_one(&mut connection)
        .await
        .expect("Failed to fetch saved subscription.");

    assert_eq!(saved.email, "ursula_le_guin@gmail.com");
    assert_eq!(saved.name, "le guin");
}

#[tokio::test]
async fn subscribe_returns_400_when_data_is_missing() {
    let app_address = spawn_app();
    let client = reqwest::Client::new();

    let test_cases = vec![
        ("name=le%20guin", "missing the email"),
        ("email=ursula_le_guin%40gmail.com", "missing the name"),
        ("", "missing both the name and email"),
    ];

    for (invalid_body, err_msg) in test_cases {
        let resp = client
            .post(&format!("{}/subscriptions", &app_address))
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
