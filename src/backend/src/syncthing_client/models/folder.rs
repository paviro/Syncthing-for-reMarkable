use serde::Serialize;
use serde_json::Value;

use crate::syncthing_client::api::FolderConfig;

/// Represents the current state of a folder in a human-readable format.
#[derive(Debug, Serialize, Clone, Copy, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum FolderStateCode {
    Unknown,
    Paused,
    Error,
    WaitingToScan,
    WaitingToSync,
    Scanning,
    PreparingToSync,
    Syncing,
    PendingChanges,
    UpToDate,
}

impl Default for FolderStateCode {
    fn default() -> Self {
        FolderStateCode::Unknown
    }
}

/// Complete folder information for UI display.
#[derive(Debug, Serialize)]
pub struct FolderPayload {
    pub id: String,
    pub label: String,
    pub path: Option<String>,
    pub state: String,
    pub state_code: FolderStateCode,
    pub state_raw: Option<String>,
    pub paused: bool,
    pub global_bytes: Option<u64>,
    pub in_sync_bytes: Option<u64>,
    pub need_bytes: Option<u64>,
    pub completion: f64,
    pub last_changes: Vec<FolderChange>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub peers_need_summary: Option<FolderPeerNeedSummary>,
}

/// Represents a recent file change in a folder.
#[derive(Debug, Serialize, Clone, Default)]
pub struct FolderChange {
    pub name: String,
    pub action: String,
    pub when: String,
    pub origin: Option<String>,
}

/// Summary of how many peers need data from this folder.
#[derive(Debug, Serialize, Clone, Copy, Default)]
pub struct FolderPeerNeedSummary {
    pub peer_count: u32,
    pub need_bytes: u64,
}

/// Helper struct to construct human-readable state labels.
pub struct FolderStateInfo {
    pub label: String,
    pub code: FolderStateCode,
}

impl FolderStateInfo {
    pub fn new(label: impl Into<String>, code: FolderStateCode) -> Self {
        Self {
            label: label.into(),
            code,
        }
    }
}

impl FolderPayload {
    pub fn from_parts(
        folder: &FolderConfig,
        status: &Value,
        last_changes: Vec<FolderChange>,
        peers_need_summary: Option<FolderPeerNeedSummary>,
    ) -> Self {
        let global_bytes = status.get("globalBytes").and_then(|v| v.as_u64());
        let need_bytes = status.get("needBytes").and_then(|v| v.as_u64());
        let in_sync_bytes = status.get("inSyncBytes").and_then(|v| v.as_u64());
        let completion = compute_completion(global_bytes, need_bytes);
        let state_raw = status
            .get("state")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());
        let paused = folder.paused.unwrap_or(false);
        let state_info = humanize_folder_state(paused, state_raw.as_deref(), need_bytes);

        Self {
            id: folder.id.clone(),
            label: folder.label.clone().unwrap_or_else(|| folder.id.clone()),
            path: folder.path.clone(),
            state: state_info.label,
            state_code: state_info.code,
            state_raw,
            paused,
            global_bytes,
            in_sync_bytes,
            need_bytes,
            completion,
            last_changes,
            peers_need_summary,
        }
    }
}

/// Calculates folder completion percentage based on global and needed bytes.
fn compute_completion(global_bytes: Option<u64>, need_bytes: Option<u64>) -> f64 {
    match (global_bytes, need_bytes) {
        (Some(global), Some(need)) if global > 0 => {
            let complete = global.saturating_sub(need);
            ((complete as f64 / global as f64) * 100.0).clamp(0.0, 100.0)
        }
        (Some(global), None) if global > 0 => 100.0,
        _ => 0.0,
    }
}

/// Converts raw folder state into a human-readable label and code.
fn humanize_folder_state(
    paused: bool,
    state: Option<&str>,
    need_bytes: Option<u64>,
) -> FolderStateInfo {
    if paused {
        return FolderStateInfo::new("Paused", FolderStateCode::Paused);
    }

    if let Some(state_value) = state {
        let normalized = state_value.to_ascii_lowercase();
        if normalized.contains("waiting") && normalized.contains("scan") {
            return FolderStateInfo::new("Waiting to scan", FolderStateCode::WaitingToScan);
        }
        if normalized.contains("waiting") && normalized.contains("sync") {
            return FolderStateInfo::new("Waiting to sync", FolderStateCode::WaitingToSync);
        }
        if normalized.contains("preparing") && normalized.contains("sync") {
            return FolderStateInfo::new("Preparing to sync", FolderStateCode::PreparingToSync);
        }

        if state_value.eq_ignore_ascii_case("scanning") {
            return FolderStateInfo::new("Scanning", FolderStateCode::Scanning);
        }
        if state_value.eq_ignore_ascii_case("syncing") {
            return FolderStateInfo::new("Syncing", FolderStateCode::Syncing);
        }
        if state_value.eq_ignore_ascii_case("idle") {
            if need_bytes.unwrap_or(0) == 0 {
                return FolderStateInfo::new("Up to date", FolderStateCode::UpToDate);
            }
            return FolderStateInfo::new("Idle / pending changes", FolderStateCode::PendingChanges);
        }
        if state_value.eq_ignore_ascii_case("error") {
            return FolderStateInfo::new("Error", FolderStateCode::Error);
        }
    }

    if need_bytes.unwrap_or(0) == 0 {
        FolderStateInfo::new("Up to date", FolderStateCode::UpToDate)
    } else {
        FolderStateInfo::new("Unknown state", FolderStateCode::Unknown)
    }
}

