#[derive(serde::Deserialize)]
pub struct Settings {
    pub database: DatabaseSettings,
    pub application_port: u16,
}

#[derive(serde::Deserialize)]
pub struct DatabaseSettings {
    pub username: String,
    pub password: String,
    pub port: u16,
    pub host: String,
    pub name: String,
}

impl DatabaseSettings {
    pub fn connection_str(&self) -> String {
        if self.port == 0 {
            format!(
                "postgres://{}:{}@{}/{}",
                self.username, self.password, self.host, self.name
            )
        } else {
            format!(
                "postgres://{}:{}@{}:{}/{}",
                self.username, self.password, self.host, self.port, self.name
            )
        }
    }

    pub fn connection_str_without_name(&self) -> String {
        if self.port == 0 {
            format!(
                "postgres://{}:{}@{}",
                self.username, self.password, self.host
            )
        } else {
            format!(
                "postgres://{}:{}@{}:{}",
                self.username, self.password, self.host, self.port
            )
        }
    }
}

pub fn get_configuration() -> Result<Settings, config::ConfigError> {
    // Initialise our configuration reader
    let config = config::Config::builder()
        .add_source(config::File::with_name("configuration"))
        .build()
        .unwrap();

    config.try_deserialize::<Settings>()
}
