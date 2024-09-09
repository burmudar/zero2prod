//! tests/health_check.rs

#[tokio::test]
async fn health_check_succeeds() {
    spawn_app().await.expect("Failed to spawn our app.");

    let client = reqwest::Client::new();

    let response = client
        .get("http://127.0.0.1:8000/health_check")
        .send()
        .await
        .expect("Faield to execute request");
    assert!(response.status().is_success());
    assert!(Some(0), response.content_length());
}

async fn spawn_app() -> std::io::Result<()> {
    zero2prod::run().await
}
