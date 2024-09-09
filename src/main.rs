use std::net::TcpListener;
use zero2prod::run;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let lst = TcpListener::bind("http://127.0.0.1:0").expect("failed to bind to address");
    run(lst)?.await
}
