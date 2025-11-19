use serde::Serialize;
use serde_json::Value;

use super::api_types::{FolderConfig, RemoteCompletion};

#[derive(Debug, Serialize, Default)]
pub struct SyncthingOverview {
    pub available: bool,
    pub my_id: Option<String>,
    pub version: Option<String>,
    pub state: Option<String>,
    pub health: Option<String>,
    pub started_at: Option<String>,
    pub uptime_seconds: Option<f64>,
    pub sequence: Option<u64>,
    pub goroutine_count: Option<u64>,
    pub errors: Vec<String>,
}

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

#[derive(Debug, Serialize, Clone, Default)]
pub struct FolderChange {
    pub name: String,
    pub action: String,
    pub when: String,
    pub origin: Option<String>,
}

#[derive(Debug, Serialize, Clone, Copy, Default)]
pub struct FolderPeerNeedSummary {
    pub peer_count: u32,
    pub need_bytes: u64,
}

#[derive(Debug, Serialize, Clone, Default)]
pub struct PeerFolderState {
    pub folder_id: String,
    pub folder_label: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub need_bytes: Option<u64>,
}

#[derive(Debug, Serialize, Clone, Default)]
pub struct PeerPayload {
    pub id: String,
    pub name: String,
    pub connected: bool,
    pub paused: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub address: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub client_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_seen: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub need_bytes: Option<u64>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub folders: Vec<PeerFolderState>,
}

#[derive(Default, Clone)]
pub struct PeerProgress {
    pub total_completion: f64,
    pub completion_samples: u32,
    pub total_need_bytes: u64,
    pub folders: Vec<PeerFolderState>,
}

pub struct FolderStateInfo {
    pub label: String,
    pub code: FolderStateCode,
}

impl SyncthingOverview {
    pub fn from_value(value: &Value) -> Self {
        Self {
            available: true,
            my_id: value
                .get("myID")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string()),
            version: value
                .get("version")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string()),
            state: value
                .get("state")
                .or_else(|| value.get("status"))
                .and_then(|v| v.as_str())
                .map(|s| s.to_string()),
            health: value
                .get("health")
                .or_else(|| value.get("status"))
                .and_then(|v| v.as_str())
                .map(|s| s.to_string()),
            started_at: value
                .get("startTime")
                .or_else(|| value.get("startedAt"))
                .and_then(|v| v.as_str())
                .map(|s| s.to_string()),
            uptime_seconds: value.get("uptime").and_then(|v| v.as_f64()),
            sequence: value
                .get("sequence")
                .or_else(|| value.get("dbSequence"))
                .and_then(|v| v.as_u64()),
            goroutine_count: value.get("goroutineCount").and_then(|v| v.as_u64()),
            errors: Vec::new(),
        }
    }

    pub fn error(message: String) -> Self {
        Self {
            errors: vec![message],
            ..Default::default()
        }
    }
}

impl PeerProgress {
    pub fn record(&mut self, folder: &FolderConfig, completion: &RemoteCompletion) {
        if let Some(value) = completion.completion {
            self.total_completion += value;
            self.completion_samples = self.completion_samples.saturating_add(1);
        }
        if let Some(need) = completion.need_bytes {
            self.total_need_bytes = self.total_need_bytes.saturating_add(need);
        }
        self.folders.push(PeerFolderState {
            folder_id: folder.id.clone(),
            folder_label: folder.label.clone().unwrap_or_else(|| folder.id.clone()),
            completion: completion.completion,
            need_bytes: completion.need_bytes,
        });
    }

    pub fn avg_completion(&self) -> Option<f64> {
        if self.completion_samples == 0 {
            None
        } else {
            let mut average = self.total_completion / self.completion_samples as f64;
            if self.total_need_bytes > 0 && average > 99.99 {
                average = 99.99;
            }
            if average > 100.0 {
                average = 100.0;
            }
            Some(average)
        }
    }

    pub fn outstanding_need(&self) -> Option<u64> {
        if self.total_need_bytes > 0 {
            Some(self.total_need_bytes)
        } else {
            None
        }
    }
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

