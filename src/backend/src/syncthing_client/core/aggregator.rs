use std::collections::{HashMap, HashSet};

use serde_json::Value;
use tracing::warn;

use crate::types::MonitorError;

use super::super::api::{
    CompletionQuery, ConnectionsResponse, DeviceConfig, EventsQuery, FolderConfig,
    FolderStatusQuery, RemoteCompletion, SyncthingConfig, SyncthingData, SyncthingEvent,
};
use super::super::helpers::{format_relative_time, is_file_event, RECENT_EVENTS_LIMIT};
use super::super::models::{
    FolderChange, FolderPayload, FolderPeerNeedSummary, PeerPayload, PeerProgress,
    SyncthingOverview,
};
use super::http::HttpClient;

/// Aggregates data from multiple Syncthing API endpoints into UI-ready payloads.
pub struct DataAggregator<'a> {
    http: &'a mut HttpClient,
}

impl<'a> DataAggregator<'a> {
    pub fn new(http: &'a mut HttpClient) -> Self {
        Self { http }
    }

    /// Composes the full payload required by the UI.
    /// Fetches system status, config, recent changes and peer metrics.
    pub async fn compose_payload(&mut self) -> Result<SyncthingData, MonitorError> {
        let status_value: Value = self.http.get_json("/rest/system/status").await?;
        let config: SyncthingConfig = self.http.get_json("/rest/config").await?;
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
            let status: Value = self.http.get_json_with_query("/rest/db/status", &query).await?;
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

    /// Collects the latest changed file per folder from recent events.
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
        let mut events: Vec<SyncthingEvent> = self
            .http
            .get_json_with_query("/rest/events", &query)
            .await?;
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

    /// Collects sync progress metrics for all peers across all folders.
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

    /// Builds peer payloads from device configuration and collected metrics.
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

    /// Queries the remote completion status for a specific folder and device.
    async fn query_remote_completion(
        &mut self,
        folder_id: &str,
        device_id: &str,
    ) -> Result<RemoteCompletion, MonitorError> {
        let query = CompletionQuery {
            folder: folder_id,
            device: device_id,
        };
        self.http
            .get_json_with_query("/rest/db/completion", &query)
            .await
    }

    /// Fetches the current connection status for all devices.
    async fn fetch_connections(&mut self) -> Result<ConnectionsResponse, MonitorError> {
        self.http.get_json("/rest/system/connections").await
    }
}

