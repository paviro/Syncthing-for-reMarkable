use appload_client::BackendReplier;
use tracing::error;

use crate::deployment::SyncthingUpdateStatus;
use crate::syncthing_client::SyncthingClient;

use super::super::protocol::{MSG_SYNCTHING_UPDATE_CHECK_RESULT, MSG_SYNCTHING_UPDATE_STATUS};
use super::super::Backend;

impl Backend {
    pub async fn handle_syncthing_update_check(&mut self, functionality: &BackendReplier<Self>) {
        if self.syncthing_update_in_progress {
            self.send_error(functionality, "Syncthing update already in progress");
            return;
        }

        self.syncthing_update_in_progress = true;
        self.syncthing_update_progress_message = Some("Checking Syncthing updates...".to_string());
        self.syncthing_update_error = None;
        self.syncthing_update_started = false;
        self.send_syncthing_update_status(functionality).await;

        let result = match SyncthingClient::discover(&self.config).await {
            Ok(mut client) => client.check_upgrade().await,
            Err(err) => Err(err),
        };

        match result {
            Ok(check) => {
                self.syncthing_update_check_result = Some(check.clone());
                self.syncthing_update_in_progress = false;
                self.syncthing_update_progress_message = None;

                if let Ok(payload) = serde_json::to_string(&check) {
                    if let Err(err) =
                        functionality.send_message(MSG_SYNCTHING_UPDATE_CHECK_RESULT, &payload)
                    {
                        error!(error = ?err, "Failed to send Syncthing update check result");
                    }
                }
                self.send_syncthing_update_status(functionality).await;
            }
            Err(err) => {
                self.syncthing_update_check_result = None;
                self.syncthing_update_in_progress = false;
                self.syncthing_update_error =
                    Some(format!("Failed to check Syncthing updates: {}", err));
                self.syncthing_update_progress_message = None;
                self.send_syncthing_update_status(functionality).await;
            }
        }
    }

    pub async fn handle_syncthing_update_install(&mut self, functionality: &BackendReplier<Self>) {
        if self.syncthing_update_in_progress {
            self.send_error(functionality, "Syncthing update already in progress");
            return;
        }

        let update_available = self
            .syncthing_update_check_result
            .as_ref()
            .map(|check| check.newer)
            .unwrap_or(false);
        if !update_available {
            self.send_error(functionality, "No Syncthing update available to install");
            return;
        }

        self.syncthing_update_in_progress = true;
        self.syncthing_update_error = None;
        self.syncthing_update_started = false;
        self.syncthing_update_progress_message = Some("Starting Syncthing upgrade...".to_string());
        self.send_syncthing_update_status(functionality).await;

        let result = match SyncthingClient::discover(&self.config).await {
            Ok(mut client) => client.perform_upgrade().await,
            Err(err) => Err(err),
        };

        match result {
            Ok(()) => {
                self.syncthing_update_check_result = None;
                self.syncthing_update_in_progress = false;
                self.syncthing_update_error = None;
                self.syncthing_update_started = true;
                self.syncthing_update_progress_message =
                    Some("Syncthing upgrade started. Waiting for service restart...".to_string());
                self.send_syncthing_update_status(functionality).await;
                self.send_status(functionality, "syncthing-upgrade-started")
                    .await;
            }
            Err(err) => {
                self.syncthing_update_in_progress = false;
                self.syncthing_update_error =
                    Some(format!("Failed to install Syncthing update: {}", err));
                self.syncthing_update_started = false;
                self.syncthing_update_progress_message = None;
                self.send_syncthing_update_status(functionality).await;
            }
        }
    }

    pub async fn send_syncthing_update_status(&self, functionality: &BackendReplier<Self>) {
        let status = SyncthingUpdateStatus {
            in_progress: self.syncthing_update_in_progress,
            progress_message: self.syncthing_update_progress_message.clone(),
            error: self.syncthing_update_error.clone(),
            success: !self.syncthing_update_in_progress && self.syncthing_update_error.is_none(),
            upgrade_started: self.syncthing_update_started,
        };

        if let Ok(payload) = serde_json::to_string(&status) {
            if let Err(err) = functionality.send_message(MSG_SYNCTHING_UPDATE_STATUS, &payload) {
                error!(error = ?err, "Failed to send Syncthing update status");
            }
        }
    }
}
