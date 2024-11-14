use std::fmt::Display;

use secrecy::{ExposeSecret, SecretBox, SecretString};
#[derive(serde::Deserialize)]
pub struct Settings {
    pub application: ApplicationSettings,
    pub database: DatabaseSettings,
}

#[derive(serde::Deserialize)]
pub struct DatabaseSettings {
    pub username: String,
    pub password: SecretString,
    pub port: u16,
    pub host: String,
    pub name: String,
}

#[derive(serde::Deserialize)]
pub struct ApplicationSettings {
    pub port: u16,
    pub host: String,
}

impl ApplicationSettings {
    pub fn address_str(&self) -> String {
        return format!("{}:{}", self.host, self.port);
    }
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

pub enum Environment {
    Local,
    Production,
}

impl Environment {
    pub fn as_str(&self) -> &'static str {
        match self {
            Environment::Local => "local",
            Environment::Production => "production",
        }
    }
}

impl TryFrom<String> for Environment {
    type Error = String;

    fn try_from(s: String) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "local" => Ok(Self::Local),
            "production" => Ok(Self::Production),
            other => Err(format!(
                "{} is not a supported environment. Use either `local` or `production`.",
                other
            )),
        }
    }
}

impl Display for Environment {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

pub fn get_configuration() -> Result<Settings, config::ConfigError> {
    let environment: Environment = std::env::var("APP_ENVIRONMENT")
        .unwrap_or_else(|_| "local".into())
        .try_into()
        .expect("failed to parse APP_ENVIRONMENT");
    let config = config::Config::builder()
        .add_source(config::File::with_name("configuration/base").required(true))
        .add_source(
            config::File::with_name(&format!("configuration/{environment}")).required(false),
        )
        .build()
        .unwrap();

    config.try_deserialize::<Settings>()
}
