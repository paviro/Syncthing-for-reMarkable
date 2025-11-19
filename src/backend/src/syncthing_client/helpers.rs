use chrono::Utc;
use std::env;
use tokio::fs;

use crate::config::Config;
use crate::types::MonitorError;

pub const RECENT_EVENTS_LIMIT: u32 = 200;

pub fn is_file_event(event_type: &str) -> bool {
    matches!(
        event_type,
        "ItemFinished"
            | "ItemStarted"
            | "LocalIndexUpdated"
            | "RemoteIndexUpdated"
            | "ItemDownloaded"
            | "FolderSummary"
            | "FolderCompletion"
    )
}

pub fn format_relative_time(iso_time: &str) -> String {
    match chrono::DateTime::parse_from_rfc3339(iso_time) {
        Ok(parsed) => {
            let now = Utc::now();
            let duration = now.signed_duration_since(parsed.with_timezone(&Utc));
            if duration.num_seconds() < 60 {
                "just now".to_string()
            } else if duration.num_minutes() < 60 {
                format!("{} min ago", duration.num_minutes())
            } else if duration.num_hours() < 24 {
                format!("{} h ago", duration.num_hours())
            } else {
                format!("{} d ago", duration.num_days())
            }
        }
        Err(_) => iso_time.to_string(),
    }
}

pub async fn load_api_key(config: &Config) -> Result<String, MonitorError> {
    if let Ok(value) = env::var("SYNCTHING_API_KEY") {
        if !value.trim().is_empty() {
            return Ok(value);
        }
    }

    let config_xml_path = config.syncthing_config_xml_path();
    let contents = fs::read_to_string(&config_xml_path)
        .await
        .map_err(|err| MonitorError::Io(err))?;
    extract_api_key(&contents).ok_or(MonitorError::MissingApiKey)
}

fn extract_api_key(contents: &str) -> Option<String> {
    let start_tag = "<apikey>";
    let end_tag = "</apikey>";
    let start = contents.find(start_tag)? + start_tag.len();
    let rest = &contents[start..];
    let end = rest.find(end_tag)?;
    Some(rest[..end].trim().to_string())
}
