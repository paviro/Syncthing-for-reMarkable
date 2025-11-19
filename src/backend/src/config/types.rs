use serde::{Deserialize, Serialize};

/// Configuration for the Syncthing monitor application
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    #[serde(default = "default_service_name")]
    pub systemd_service_name: String,

    #[serde(default = "default_config_dir")]
    pub syncthing_config_dir: String,

    #[serde(default)]
    pub disable_syncthing_installer: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            systemd_service_name: default_service_name(),
            syncthing_config_dir: default_config_dir(),
            disable_syncthing_installer: false,
        }
    }
}

fn default_service_name() -> String {
    "syncthing.service".to_string()
}

fn default_config_dir() -> String {
    "/home/root/.config/syncthing".to_string()
}

