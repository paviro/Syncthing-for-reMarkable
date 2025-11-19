use serde_json::Value;
use tokio::fs;
use tracing::{info, warn};

use crate::types::MonitorError;

use super::{paths, Config};

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
        let config_path = paths::get_config_path()?;

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
}

