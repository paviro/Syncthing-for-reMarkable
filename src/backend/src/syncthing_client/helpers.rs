use chrono::Utc;
use std::env;
use tokio::fs;
use xml::reader::{EventReader, XmlEvent};

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
        .map_err(MonitorError::Io)?;
    extract_api_key(&contents)?.ok_or(MonitorError::MissingApiKey)
}

fn extract_api_key(contents: &str) -> Result<Option<String>, MonitorError> {
    let parser = EventReader::new(contents.as_bytes());
    let mut path: Vec<String> = Vec::new();

    for event in parser {
        match event.map_err(|err| MonitorError::Config(format!("Invalid Syncthing XML: {err}")))? {
            XmlEvent::StartElement { name, .. } => path.push(name.local_name),
            XmlEvent::EndElement { .. } => {
                path.pop();
            }
            XmlEvent::Characters(text) | XmlEvent::CData(text) if is_gui_api_key_path(&path) => {
                let trimmed = text.trim();
                if !trimmed.is_empty() {
                    return Ok(Some(trimmed.to_string()));
                }
            }
            _ => {}
        }
    }

    Ok(None)
}

fn is_gui_api_key_path(path: &[String]) -> bool {
    path.len() == 3 && path[0] == "configuration" && path[1] == "gui" && path[2] == "apikey"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_api_key_from_configuration_gui_path() {
        let xml = r#"
            <configuration>
                <folder>
                    <apikey>wrong</apikey>
                </folder>
                <gui>
                    <apikey> expected-key </apikey>
                </gui>
            </configuration>
        "#;

        assert_eq!(
            extract_api_key(xml).expect("parse xml"),
            Some("expected-key".to_string())
        );
    }

    #[test]
    fn ignores_api_key_outside_gui_config() {
        let xml = r#"
            <configuration>
                <apikey>wrong</apikey>
            </configuration>
        "#;

        assert_eq!(extract_api_key(xml).expect("parse xml"), None);
    }

    #[test]
    fn rejects_invalid_xml() {
        assert!(extract_api_key("<configuration><gui>").is_err());
    }
}
