use std::collections::{HashMap, HashSet};
use std::env;
use std::time::Duration;

use reqwest::Client;
use serde::de::DeserializeOwned;
use serde::Serialize;
use serde_json::Value;
use tracing::warn;

use crate::config::Config;
use crate::types::MonitorError;

use super::api_types::{
    ConnectionsResponse, DeviceConfig, FolderConfig, RemoteCompletion, SyncthingConfig,
    SyncthingEvent,
};
use super::helpers::{
    format_relative_time, is_file_event, load_api_key, RECENT_EVENTS_LIMIT,
};
use super::model::{
    FolderChange, FolderPayload, FolderPeerNeedSummary, PeerPayload, PeerProgress, SyncthingOverview,
};
use super::queries::{CompletionQuery, EventStreamQuery, EventsQuery, FolderStatusQuery};

#[derive(Clone)]
pub struct SyncthingClient {
    api_key: String,
    http: Client,
    base_urls: Vec<String>,
    current_idx: usize,
}

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

impl SyncthingClient {
    /// Discover a Syncthing instance using config/env and prepare an HTTP client.
    pub async fn discover(config: &Config) -> Result<Self, MonitorError> {
        let api_key = load_api_key(config).await?;
        let mut base_urls = Vec::new();
        if let Ok(custom) = env::var("SYNCTHING_API_URL") {
            let trimmed = custom.trim();
            if !trimmed.is_empty() {
                push_unique_url(&mut base_urls, trimmed.to_string());
            }
        }
        push_unique_url(&mut base_urls, "https://127.0.0.1:8384".to_string());
        push_unique_url(&mut base_urls, "http://127.0.0.1:8384".to_string());
        if base_urls.is_empty() {
            base_urls.push("http://127.0.0.1:8384".to_string());
        }

        let http = Client::builder()
            .timeout(Duration::from_secs(8))
            .danger_accept_invalid_certs(true)
            .build()
            .map_err(MonitorError::Http)?;

        Ok(Self {
            api_key,
            http,
            base_urls,
            current_idx: 0,
        })
    }

    /// Compose the full payload required by the UI.
    /// - Fetches system status, config, recent changes and peer metrics
    /// - Builds folder and peer payloads ready for rendering
    pub async fn compose_payload(&mut self) -> Result<SyncthingData, MonitorError> {
        let status_value: Value = self.get_json("/rest/system/status").await?;
        let config: SyncthingConfig = self.get_json("/rest/config").await?;
        let folder_ids: HashSet<String> = config.folders.iter().map(|f| f.id.clone()).collect();
        let latest_changes = self.latest_folder_changes(&folder_ids).await?;
        let mut folders = Vec::new();

        let connections = match self.fetch_connections().await {
            Ok(data) => data,
            Err(err) => {
                warn!(error = ?err, "Failed to fetch peer connections");
                ConnectionsResponse::default()
            }
        };

        let overview = SyncthingOverview::from_value(&status_value);
        let my_id = overview.my_id.clone();

        let (folder_peer_summaries, peer_progress) = self
            .collect_peer_metrics(&config.folders, my_id.as_deref())
            .await;

        for folder in &config.folders {
            let query = FolderStatusQuery {
                folder: folder.id.as_str(),
            };
            let status: Value = self.get_json_with_query("/rest/db/status", &query).await?;
            // Keep UI contract: a Vec, but only ever include the latest (0..1)
            let last_changes = latest_changes
                .get(&folder.id)
                .cloned()
                .into_iter()
                .collect::<Vec<_>>();
            let peer_need_summary = folder_peer_summaries.get(&folder.id).copied();
            folders.push(FolderPayload::from_parts(
                folder,
                &status,
                last_changes,
                peer_need_summary,
            ));
        }

        let peers = self.compose_peers(
            &config.devices,
            my_id.as_deref(),
            &peer_progress,
            &connections,
        );

        Ok(SyncthingData {
            overview,
            folders,
            peers,
        })
    }

    pub async fn wait_for_updates(
        &mut self,
        since: u64,
        timeout: Duration,
    ) -> Result<EventWaitResult, MonitorError> {
        let timeout_secs = timeout.as_secs().clamp(1, 300);
        let query = EventStreamQuery {
            since,
            limit: 1,
            timeout: timeout_secs,
            events: None,
        };
        let events: Vec<SyncthingEvent> = self.get_json_with_query("/rest/events", &query).await?;

        let mut last_event_id = since;
        for event in &events {
            if event.id > last_event_id {
                last_event_id = event.id;
            }
        }

        Ok(EventWaitResult {
            last_event_id,
            has_updates: !events.is_empty(),
        })
    }

    /// Collect the latest changed file per folder (if any), considering only file-related events.
    async fn latest_folder_changes(
        &mut self,
        allowed: &HashSet<String>,
    ) -> Result<HashMap<String, FolderChange>, MonitorError> {
        if allowed.is_empty() {
            return Ok(HashMap::new());
        }

        let query = EventsQuery {
            since: 0,
            limit: RECENT_EVENTS_LIMIT,
        };
        let mut events: Vec<SyncthingEvent> =
            self.get_json_with_query("/rest/events", &query).await?;
        events.sort_by(|a, b| b.id.cmp(&a.id));

        let mut changes: HashMap<String, FolderChange> = HashMap::new();
        for event in events {
            if !is_file_event(&event.event_type) {
                continue;
            }
            let Some(folder_id) = event.folder_id() else {
                continue;
            };
            if !allowed.contains(folder_id) {
                continue;
            }
            // If we already recorded the latest change for this folder, skip
            if changes.contains_key(folder_id) {
                continue;
            }
            if let Some(file_name) = event.file_name() {
                changes.insert(
                    folder_id.to_string(),
                    FolderChange {
                        name: file_name,
                        action: event.action().unwrap_or_else(|| event.event_type.clone()),
                        when: format_relative_time(&event.time),
                        origin: event.origin(),
                    },
                );
            }
        }

        Ok(changes)
    }

    async fn collect_peer_metrics(
        &mut self,
        folders: &[FolderConfig],
        my_id: Option<&str>,
    ) -> (
        HashMap<String, FolderPeerNeedSummary>,
        HashMap<String, PeerProgress>,
    ) {
        let mut folder_summaries: HashMap<String, FolderPeerNeedSummary> = HashMap::new();
        let mut peer_progress: HashMap<String, PeerProgress> = HashMap::new();

        for folder in folders {
            if folder.devices.is_empty() {
                continue;
            }

            for device in &folder.devices {
                if device.device_id.is_empty() {
                    continue;
                }
                if my_id
                    .map(|local| local == device.device_id.as_str())
                    .unwrap_or(false)
                {
                    continue;
                }

                match self
                    .query_remote_completion(folder.id.as_str(), device.device_id.as_str())
                    .await
                {
                    Ok(remote_completion) => {
                        let need = remote_completion.need_bytes.unwrap_or(0);
                        if need > 0 {
                            let entry = folder_summaries
                                .entry(folder.id.clone())
                                .or_insert_with(FolderPeerNeedSummary::default);
                            entry.peer_count = entry.peer_count.saturating_add(1);
                            entry.need_bytes = entry.need_bytes.saturating_add(need);
                        }

                        peer_progress
                            .entry(device.device_id.clone())
                            .or_insert_with(PeerProgress::default)
                            .record(folder, &remote_completion);
                    }
                    Err(err) => {
                        warn!(
                            folder = %folder.id,
                            device = %device.device_id,
                            error = ?err,
                            "Failed to query remote completion"
                        );
                    }
                }
            }
        }

        (folder_summaries, peer_progress)
    }

    fn compose_peers(
        &self,
        devices: &[DeviceConfig],
        my_id: Option<&str>,
        peer_progress: &HashMap<String, PeerProgress>,
        connections: &ConnectionsResponse,
    ) -> Vec<PeerPayload> {
        let mut peers = Vec::new();
        for device in devices {
            if device.device_id.is_empty() {
                continue;
            }
            if my_id
                .map(|local| local == device.device_id.as_str())
                .unwrap_or(false)
            {
                continue;
            }

            let connection = connections.connections.get(&device.device_id);
            let progress = peer_progress.get(&device.device_id);
            let paused =
                device.paused.unwrap_or(false) || connection.map(|c| c.paused).unwrap_or(false);

            peers.push(PeerPayload {
                id: device.device_id.clone(),
                name: device
                    .name
                    .clone()
                    .unwrap_or_else(|| device.device_id.clone()),
                connected: connection.map(|c| c.connected).unwrap_or(false),
                paused,
                address: connection.and_then(|c| c.address.clone()),
                client_version: connection.and_then(|c| c.client_version.clone()),
                last_seen: connection.and_then(|c| c.last_seen.clone()),
                completion: progress.and_then(|p| p.avg_completion()),
                need_bytes: progress.and_then(|p| p.outstanding_need()),
                folders: progress.map(|p| p.folders.clone()).unwrap_or_default(),
            });
        }

        peers.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
        peers
    }

    async fn query_remote_completion(
        &mut self,
        folder_id: &str,
        device_id: &str,
    ) -> Result<RemoteCompletion, MonitorError> {
        let query = CompletionQuery {
            folder: folder_id,
            device: device_id,
        };
        self.get_json_with_query("/rest/db/completion", &query)
            .await
    }

    async fn fetch_connections(&mut self) -> Result<ConnectionsResponse, MonitorError> {
        self.get_json("/rest/system/connections").await
    }

    async fn get_json<T>(&mut self, path: &str) -> Result<T, MonitorError>
    where
        T: DeserializeOwned,
    {
        self.get_json_with_query(path, &()).await
    }

    async fn get_json_with_query<T, Q>(&mut self, path: &str, query: &Q) -> Result<T, MonitorError>
    where
        T: DeserializeOwned,
        Q: Serialize + ?Sized,
    {
        let base = &self.base_urls[self.current_idx.min(self.base_urls.len().saturating_sub(1))];
        let url = format!(
            "{}/{}",
            base.trim_end_matches('/'),
            path.trim_start_matches('/')
        );
        let response = self
            .http
            .get(url)
            .header("X-API-Key", &self.api_key)
            .query(query)
            .send()
            .await
            .map_err(MonitorError::Http)?;

        if !response.status().is_success() {
            return Err(MonitorError::Syncthing(format!(
                "{} returned {}",
                path,
                response.status()
            )));
        }

        response.json::<T>().await.map_err(MonitorError::Http)
    }

    /// Fetch GUI address from Syncthing config.
    pub async fn get_gui_address(&mut self) -> Result<String, MonitorError> {
        let config: Value = self.get_json("/rest/config").await?;
        let address = config
            .get("gui")
            .and_then(|gui| gui.get("address"))
            .and_then(|addr| addr.as_str())
            .ok_or_else(|| {
                MonitorError::Syncthing("GUI address not found in config".to_string())
            })?;
        Ok(address.to_string())
    }

    /// Update GUI address in Syncthing config.
    pub async fn set_gui_address(&mut self, new_address: &str) -> Result<(), MonitorError> {
        // Get current config
        let mut config: Value = self.get_json("/rest/config").await?;

        // Update the GUI address
        if let Some(gui) = config.get_mut("gui") {
            if let Some(gui_obj) = gui.as_object_mut() {
                gui_obj.insert(
                    "address".to_string(),
                    Value::String(new_address.to_string()),
                );
            }
        }

        // Send the updated config back
        let base = &self.base_urls[self.current_idx.min(self.base_urls.len().saturating_sub(1))];
        let url = format!("{}/rest/config", base.trim_end_matches('/'));

        let response = self
            .http
            .put(url)
            .header("X-API-Key", &self.api_key)
            .header("Content-Type", "application/json")
            .json(&config)
            .send()
            .await
            .map_err(MonitorError::Http)?;

        if !response.status().is_success() {
            return Err(MonitorError::Syncthing(format!(
                "Failed to update GUI address: {}",
                response.status()
            )));
        }

        Ok(())
    }
}

fn push_unique_url(list: &mut Vec<String>, candidate: String) {
    if !list.iter().any(|existing| existing == &candidate) {
        list.push(candidate);
    }
}
