use secrecy::{ExposeSecret, SecretBox, SecretString};
#[derive(serde::Deserialize)]
pub struct Settings {
    pub database: DatabaseSettings,
    pub application_port: u16,
}

#[derive(serde::Deserialize)]
pub struct DatabaseSettings {
    pub username: String,
    pub password: SecretString,
    pub port: u16,
    pub host: String,
    pub name: String,
}

impl DatabaseSettings {
    pub fn connection_str(&self) -> SecretString {
        if self.port == 0 {
            let value = format!(
                "postgres://{}:{}@{}/{}",
                self.username,
                self.password.expose_secret(),
                self.host,
                self.name
            );
            SecretString::new(value.into())
        } else {
            let value = format!(
                "postgres://{}:{}@{}:{}/{}",
                self.username,
                self.password.expose_secret(),
                self.host,
                self.port,
                self.name
            );
            SecretBox::new(value.into())
        }
    }

    pub fn connection_str_without_name(&self) -> SecretString {
        if self.port == 0 {
            let value = format!(
                "postgres://{}:{}@{}",
                self.username,
                self.password.expose_secret(),
                self.host
            );
            SecretString::new(value.into())
        } else {
            let value = format!(
                "postgres://{}:{}@{}:{}",
                self.username,
                self.password.expose_secret(),
                self.host,
                self.port
            );
            SecretString::new(value.into())
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
