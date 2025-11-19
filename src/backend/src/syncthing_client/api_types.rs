use serde::Deserialize;
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
pub struct SyncthingConfig {
    #[serde(default)]
    pub folders: Vec<FolderConfig>,
    #[serde(default)]
    pub devices: Vec<DeviceConfig>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct FolderConfig {
    pub id: String,
    #[serde(default)]
    pub label: Option<String>,
    #[serde(default)]
    pub path: Option<String>,
    #[serde(default)]
    pub paused: Option<bool>,
    #[serde(default)]
    pub devices: Vec<FolderDevice>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct FolderDevice {
    #[serde(rename = "deviceID")]
    pub device_id: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct DeviceConfig {
    #[serde(rename = "deviceID")]
    pub device_id: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub paused: Option<bool>,
}

#[derive(Debug, Deserialize, Default)]
pub struct ConnectionsResponse {
    #[serde(default)]
    pub connections: HashMap<String, ConnectionState>,
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct ConnectionState {
    #[serde(default)]
    pub connected: bool,
    #[serde(default)]
    pub paused: bool,
    #[serde(default, rename = "clientVersion")]
    pub client_version: Option<String>,
    #[serde(default)]
    pub address: Option<String>,
    #[serde(default, rename = "lastSeen")]
    pub last_seen: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct SyncthingEvent {
    pub id: u64,
    #[serde(rename = "type")]
    pub event_type: String,
    pub time: String,
    pub data: Value,
}

#[derive(Debug, Deserialize)]
pub struct RemoteCompletion {
    #[allow(dead_code)]
    pub completion: Option<f64>,
    #[serde(rename = "needBytes")]
    pub need_bytes: Option<u64>,
}

impl SyncthingEvent {
    pub fn folder_id(&self) -> Option<&str> {
        self.data.get("folder").and_then(|v| v.as_str())
    }

    pub fn file_name(&self) -> Option<String> {
        if let Some(item) = self.data.get("item").and_then(|v| v.as_str()) {
            return Some(item.to_string());
        }
        if let Some(file) = self.data.get("file").and_then(|v| v.as_str()) {
            return Some(file.to_string());
        }
        if let Some(items) = self.data.get("items").and_then(|v| v.as_array()) {
            for entry in items {
                if let Some(path) = entry
                    .get("path")
                    .or_else(|| entry.get("item"))
                    .or_else(|| entry.get("file"))
                    .and_then(|v| v.as_str())
                {
                    return Some(path.to_string());
                }
            }
        }
        if let Some(files) = self.data.get("files").and_then(|v| v.as_array()) {
            for entry in files {
                if let Some(path) = entry
                    .get("path")
                    .or_else(|| entry.get("item"))
                    .or_else(|| entry.get("file"))
                    .and_then(|v| v.as_str())
                {
                    return Some(path.to_string());
                }
            }
        }
        None
    }

    pub fn action(&self) -> Option<String> {
        if let Some(action) = self.data.get("action").and_then(|v| v.as_str()) {
            return Some(action.to_string());
        }
        if let Some(items) = self.data.get("items").and_then(|v| v.as_array()) {
            for entry in items {
                if let Some(action) = entry.get("action").and_then(|v| v.as_str()) {
                    return Some(action.to_string());
                }
            }
        }
        None
    }

    pub fn origin(&self) -> Option<String> {
        self.data
            .get("device")
            .or_else(|| self.data.get("peerID"))
            .or_else(|| self.data.get("id"))
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
    }
}

