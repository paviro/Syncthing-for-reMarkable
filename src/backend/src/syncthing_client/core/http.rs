use reqwest::{Client, Url};
use serde::de::DeserializeOwned;
use serde::Serialize;

use crate::types::MonitorError;

/// Handles low-level HTTP communication with the Syncthing API.
#[derive(Clone)]
pub struct HttpClient {
    pub(super) api_key: String,
    pub(super) http: Client,
    pub(super) loopback_insecure_http: Client,
    pub(super) base_urls: Vec<String>,
    pub(super) current_idx: usize,
}

impl HttpClient {
    /// Performs a GET request and deserializes the JSON response.
    pub async fn get_json<T>(&mut self, path: &str) -> Result<T, MonitorError>
    where
        T: DeserializeOwned,
    {
        self.get_json_with_query(path, &()).await
    }

    /// Performs a GET request with query parameters and deserializes the JSON response.
    pub async fn get_json_with_query<T, Q>(
        &mut self,
        path: &str,
        query: &Q,
    ) -> Result<T, MonitorError>
    where
        T: DeserializeOwned,
        Q: Serialize + ?Sized,
    {
        let mut last_error = None;

        for index in self.candidate_indices() {
            let base = &self.base_urls[index];
            let url = request_url(base, path);
            let response = self
                .client_for_base_url(base)
                .get(url)
                .header("X-API-Key", &self.api_key)
                .query(query)
                .send()
                .await;

            match response {
                Ok(response) if response.status().is_success() => {
                    self.current_idx = index;
                    return response.json::<T>().await.map_err(MonitorError::Http);
                }
                Ok(response) => {
                    last_error = Some(MonitorError::Syncthing(format!(
                        "{} returned {} from {}",
                        path,
                        response.status(),
                        base
                    )));
                }
                Err(err) => last_error = Some(MonitorError::Http(err)),
            }
        }

        Err(last_error.unwrap_or_else(|| {
            MonitorError::Syncthing("No Syncthing API URLs configured".to_string())
        }))
    }

    /// Performs a PUT request with a JSON body.
    pub async fn put_json<T>(&mut self, path: &str, body: &T) -> Result<(), MonitorError>
    where
        T: Serialize,
    {
        let mut last_error = None;

        for index in self.candidate_indices() {
            let base = &self.base_urls[index];
            let url = request_url(base, path);
            let response = self
                .client_for_base_url(base)
                .put(url)
                .header("X-API-Key", &self.api_key)
                .header("Content-Type", "application/json")
                .json(body)
                .send()
                .await;

            match response {
                Ok(response) if response.status().is_success() => {
                    self.current_idx = index;
                    return Ok(());
                }
                Ok(response) => {
                    last_error = Some(MonitorError::Syncthing(format!(
                        "{} returned {} from {}",
                        path,
                        response.status(),
                        base
                    )));
                }
                Err(err) => last_error = Some(MonitorError::Http(err)),
            }
        }

        Err(last_error.unwrap_or_else(|| {
            MonitorError::Syncthing("No Syncthing API URLs configured".to_string())
        }))
    }

    /// Performs a POST request with an empty body.
    pub async fn post(&mut self, path: &str) -> Result<(), MonitorError> {
        let mut last_error = None;

        for index in self.candidate_indices() {
            let base = &self.base_urls[index];
            let url = request_url(base, path);
            let response = self
                .client_for_base_url(base)
                .post(url)
                .header("X-API-Key", &self.api_key)
                .send()
                .await;

            match response {
                Ok(response) if response.status().is_success() => {
                    self.current_idx = index;
                    return Ok(());
                }
                Ok(response) => {
                    last_error = Some(MonitorError::Syncthing(format!(
                        "{} returned {} from {}",
                        path,
                        response.status(),
                        base
                    )));
                }
                Err(err) => last_error = Some(MonitorError::Http(err)),
            }
        }

        Err(last_error.unwrap_or_else(|| {
            MonitorError::Syncthing("No Syncthing API URLs configured".to_string())
        }))
    }

    /// Creates a new HttpClient with the given configuration.
    pub fn new(
        api_key: String,
        http: Client,
        loopback_insecure_http: Client,
        base_urls: Vec<String>,
    ) -> Self {
        Self {
            api_key,
            http,
            loopback_insecure_http,
            base_urls,
            current_idx: 0,
        }
    }

    fn candidate_indices(&self) -> Vec<usize> {
        if self.base_urls.is_empty() {
            return Vec::new();
        }

        let start = self.current_idx.min(self.base_urls.len() - 1);
        (0..self.base_urls.len())
            .map(|offset| (start + offset) % self.base_urls.len())
            .collect()
    }

    fn client_for_base_url(&self, base_url: &str) -> &Client {
        if is_https_loopback_url(base_url) {
            &self.loopback_insecure_http
        } else {
            &self.http
        }
    }
}

fn request_url(base: &str, path: &str) -> String {
    format!(
        "{}/{}",
        base.trim_end_matches('/'),
        path.trim_start_matches('/')
    )
}

fn is_https_loopback_url(base_url: &str) -> bool {
    let Ok(url) = Url::parse(base_url) else {
        return false;
    };
    if url.scheme() != "https" {
        return false;
    }

    matches!(
        url.host_str(),
        Some("localhost") | Some("127.0.0.1") | Some("::1") | Some("[::1]")
    )
}

#[cfg(test)]
mod tests {
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::thread;
    use std::time::Duration;

    use serde_json::Value;

    use super::*;

    #[tokio::test]
    async fn get_json_falls_back_and_promotes_successful_endpoint() {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind test listener");
        let address = listener.local_addr().expect("read local addr");
        thread::spawn(move || {
            let (mut stream, _) = listener.accept().expect("accept request");
            let mut buffer = [0_u8; 1024];
            let _ = stream.read(&mut buffer);
            stream
                .write_all(
                    b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 11\r\n\r\n{\"ok\":true}",
                )
                .expect("write response");
        });

        let strict = Client::builder()
            .timeout(Duration::from_secs(1))
            .build()
            .expect("build strict client");
        let insecure = Client::builder()
            .timeout(Duration::from_secs(1))
            .danger_accept_invalid_certs(true)
            .build()
            .expect("build insecure client");
        let mut client = HttpClient::new(
            "key".to_string(),
            strict,
            insecure,
            vec![
                "http://127.0.0.1:9".to_string(),
                format!("http://{}", address),
            ],
        );

        let payload: Value = client.get_json("/rest/test").await.expect("fallback");

        assert_eq!(payload["ok"], true);
        assert_eq!(client.current_idx, 1);
    }

    #[test]
    fn invalid_certs_are_only_allowed_for_https_loopback_urls() {
        assert!(is_https_loopback_url("https://127.0.0.1:8384"));
        assert!(is_https_loopback_url("https://localhost:8384"));
        assert!(!is_https_loopback_url("http://127.0.0.1:8384"));
        assert!(!is_https_loopback_url("https://syncthing.example.com:8384"));
    }
}
