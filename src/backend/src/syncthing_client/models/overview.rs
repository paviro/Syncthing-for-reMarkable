use serde::Serialize;
use serde_json::Value;

/// Aggregated system status information from Syncthing.
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

