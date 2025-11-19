//! Shared deployment-related data structures.

use serde::{Deserialize, Serialize};
use tokio::sync::mpsc::Sender;

#[derive(Debug, Clone, Serialize, Default)]
pub struct InstallerStatus {
    pub binary_present: bool,
    pub service_installed: bool,
    pub in_progress: bool,
    pub progress_message: Option<String>,
    pub error: Option<String>,
    pub installer_disabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateCheckResult {
    pub current_version: String,
    pub latest_version: String,
    pub update_available: bool,
    pub download_url: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct UpdateStatus {
    pub in_progress: bool,
    pub progress_message: Option<String>,
    pub error: Option<String>,
    pub success: bool,
    pub pending_restart: bool,
    pub restart_seconds_remaining: Option<u32>,
}

#[derive(Debug, Clone)]
pub struct DownloadProgress {
    pub downloaded_bytes: u64,
    pub total_bytes: Option<u64>,
}

impl DownloadProgress {
    pub fn percent(&self) -> Option<u8> {
        self.total_bytes.map(|total| {
            if total == 0 {
                100
            } else {
                let percent = (self.downloaded_bytes.saturating_mul(100)) / total;
                percent.min(100) as u8
            }
        })
    }
}

pub type DownloadProgressSender = Sender<DownloadProgress>;

