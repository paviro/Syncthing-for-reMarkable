use serde::Serialize;

use crate::syncthing_client::api::{FolderConfig, RemoteCompletion};

/// Represents the sync state of a folder as seen from a peer's perspective.
#[derive(Debug, Serialize, Clone, Default)]
pub struct PeerFolderState {
    pub folder_id: String,
    pub folder_label: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub need_bytes: Option<u64>,
}

/// Complete peer information for UI display.
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

/// Tracks aggregated sync progress for a single peer across multiple folders.
#[derive(Default, Clone)]
pub struct PeerProgress {
    pub total_completion: f64,
    pub completion_samples: u32,
    pub total_need_bytes: u64,
    pub folders: Vec<PeerFolderState>,
}

impl PeerProgress {
    /// Records completion data for one folder shared with this peer.
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

    /// Calculates the average completion percentage across all folders.
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

    /// Returns the total outstanding bytes needed, if any.
    pub fn outstanding_need(&self) -> Option<u64> {
        if self.total_need_bytes > 0 {
            Some(self.total_need_bytes)
        } else {
            None
        }
    }
}

