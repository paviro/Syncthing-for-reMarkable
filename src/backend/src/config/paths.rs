use std::path::PathBuf;
use tracing::{debug, warn};

use crate::types::MonitorError;

use super::Config;

impl Config {
    /// Get the full path to the Syncthing config XML file
    pub fn syncthing_config_xml_path(&self) -> String {
        let dir = self.syncthing_config_dir.trim_end_matches('/');
        format!("{}/config.xml", dir)
    }

    /// Get the root directory of the application
    pub fn app_root_dir() -> Result<PathBuf, MonitorError> {
        let config_path = get_config_path()?;
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

    /// Get the path to the Syncthing binary
    pub fn syncthing_binary_path(&self) -> Result<PathBuf, MonitorError> {
        Ok(Self::app_root_dir()?.join("syncthing"))
    }
}

/// Get the path to the config.json file
/// Looks for config.json in the app directory (parent of backend folder)
pub(super) fn get_config_path() -> Result<PathBuf, MonitorError> {
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

