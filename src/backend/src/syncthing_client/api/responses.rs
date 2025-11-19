use crate::syncthing_client::models::{FolderPayload, PeerPayload, SyncthingOverview};

/// Aggregated Syncthing data payload consumed by the UI.
pub struct SyncthingData {
    pub overview: SyncthingOverview,
    pub folders: Vec<FolderPayload>,
    pub peers: Vec<PeerPayload>,
}

/// Result from long-polling the Syncthing event stream.
pub struct EventWaitResult {
    pub last_event_id: u64,
    pub has_updates: bool,
}

