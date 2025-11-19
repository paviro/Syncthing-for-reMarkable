use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::path::PathBuf;
use tokio::fs;
use tracing::{debug, info, warn};

use crate::types::MonitorError;

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

impl Config {
    /// Load configuration from config.json in the app directory
    /// Falls back to defaults if the file doesn't exist or can't be parsed
    pub async fn load() -> Self {
        match Self::try_load().await {
            Ok(config) => {
                info!(
                    service = %config.systemd_service_name,
                    dir = %config.syncthing_config_dir,
                    "Loaded configuration"
                );
                config
            }
            Err(err) => {
                warn!(error = ?err, "Failed to load config.json, using defaults");
                Self::default()
            }
        }
    }

    async fn try_load() -> Result<Self, MonitorError> {
        let config_path = Self::get_config_path()?;

        if !config_path.exists() {
            warn!(path = %config_path.display(), "Config file not found, using defaults");
            return Ok(Self::default());
        }

        let contents = fs::read_to_string(&config_path)
            .await
            .map_err(|err| MonitorError::Config(format!("Failed to read config file: {err}")))?;

        let value: Value = serde_json::from_str(&contents)
            .map_err(|err| MonitorError::Config(format!("Failed to parse config.json: {err}")))?;

        let disable_defined = value.get("disable_syncthing_installer").is_some();
        let mut config: Config = serde_json::from_value(value).map_err(|err| {
            MonitorError::Config(format!("Failed to deserialize config.json: {err}"))
        })?;

        if !disable_defined {
            config.disable_syncthing_installer = true;
        }

        Ok(config)
    }

    /// Get the path to the config.json file
    /// Looks for config.json in the app directory (parent of backend folder)
    fn get_config_path() -> Result<PathBuf, MonitorError> {
        // Try to get the executable path
        // Executable is at: app_root/backend/entry
        // Config should be at: app_root/config.json
        if let Ok(exe_path) = std::env::current_exe() {
            debug!(path = %exe_path.display(), "Executable path detected");

            if let Some(backend_dir) = exe_path.parent() {
                debug!(path = %backend_dir.display(), "Backend directory detected");

                // Go up one more level to get to app root
                if let Some(app_root) = backend_dir.parent() {
                    let config_path = app_root.join("config.json");
                    debug!(path = %config_path.display(), "Looking for config");
                    return Ok(config_path);
                }
            }
        }

        // Fallback: look in current directory
        warn!("Using fallback: looking for config.json in current directory");
        Ok(PathBuf::from("config.json"))
    }

    /// Get the full path to the Syncthing config XML file
    pub fn syncthing_config_xml_path(&self) -> String {
        let dir = self.syncthing_config_dir.trim_end_matches('/');
        format!("{}/config.xml", dir)
    }

    pub fn app_root_dir() -> Result<PathBuf, MonitorError> {
        let config_path = Self::get_config_path()?;
        match config_path.parent() {
            Some(parent) if !parent.as_os_str().is_empty() => Ok(parent.to_path_buf()),
            Some(_) => std::env::current_dir().map_err(|err| {
                MonitorError::Config(format!("Failed to determine app root: {err}"))
            }),
            None => Err(MonitorError::Config(
                "Unable to determine app root directory".to_string(),
            )),
        }
    }

    pub fn syncthing_binary_path(&self) -> Result<PathBuf, MonitorError> {
        Ok(Self::app_root_dir()?.join("syncthing"))
    }
}
