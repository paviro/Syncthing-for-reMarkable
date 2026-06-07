use tokio::sync::mpsc;
use tokio::time::{sleep, Duration};
use tracing::{error, warn};

use crate::deployment::UpdateStatus;
use appload_client::BackendReplier;

use super::super::protocol::{
    MSG_UPDATE_CHECK_RESULT, MSG_UPDATE_DOWNLOAD_STATUS, UPDATE_RESTART_DELAY_SECS,
};
use super::super::Backend;
use super::progress_runner::ProgressTarget;

impl Backend {
    pub async fn handle_update_check(&mut self, functionality: &BackendReplier<Self>) {
        if self.update_state.in_progress {
            self.send_error(functionality, "Update already in progress");
            return;
        }

        self.update_state.in_progress = true;
        self.update_state.progress_message = Some("Checking for updates...".to_string());
        self.update_state.error = None;
        self.send_update_status(functionality).await;

        match self.updater.check_for_updates().await {
            Ok(result) => {
                self.update_state.pending_update_url = result.download_url.clone();
                self.update_state.in_progress = false;
                self.update_state.progress_message = None;

                if let Err(err) = self
                    .send_json_message(functionality, MSG_UPDATE_CHECK_RESULT, &result)
                    .await
                {
                    error!(error = ?err, "Failed to send update check result");
                }
                self.send_update_status(functionality).await;
            }
            Err(err) => {
                self.update_state.in_progress = false;
                self.update_state.error = Some(format!("Failed to check for updates: {}", err));
                self.update_state.progress_message = None;
                self.send_update_status(functionality).await;
            }
        }
    }

    pub async fn handle_update_download(&mut self, functionality: &BackendReplier<Self>) {
        if self.update_state.in_progress {
            self.send_error(functionality, "Update already in progress");
            return;
        }

        let download_url = match &self.update_state.pending_update_url {
            Some(url) => url.clone(),
            None => {
                self.send_error(functionality, "No update available to download");
                return;
            }
        };

        self.update_state.in_progress = true;
        self.update_state.error = None;
        self.update_state.progress_message = Some("Downloading update...".to_string());
        self.update_state.pending_restart = false;
        self.update_state.restart_seconds_remaining = None;
        self.send_update_status(functionality).await;

        let (progress_tx, progress_rx) = mpsc::channel(16);
        let updater = self.updater.clone();
        let update_future = Box::pin(async move {
            updater
                .download_and_apply_update(&download_url, Some(progress_tx))
                .await
        });

        match self
            .run_with_download_progress(
                functionality,
                update_future,
                progress_rx,
                ProgressTarget::AppUpdate,
                "Downloading update",
                Some("Installing update files..."),
            )
            .await
        {
            Ok(()) => {
                self.begin_restart_countdown(functionality).await;
            }
            Err(err) => {
                self.update_state.in_progress = false;
                self.update_state.error = Some(format!("Failed to download/apply update: {}", err));
                self.update_state.progress_message = None;
                self.update_state.pending_restart = false;
                self.update_state.restart_seconds_remaining = None;
                self.send_update_status(functionality).await;
            }
        }
    }

    pub async fn send_update_status(&self, functionality: &BackendReplier<Self>) {
        let status = UpdateStatus {
            in_progress: self.update_state.in_progress,
            progress_message: self.update_state.progress_message.clone(),
            error: self.update_state.error.clone(),
            success: !self.update_state.in_progress && self.update_state.error.is_none(),
            pending_restart: self.update_state.pending_restart,
            restart_seconds_remaining: self.update_state.restart_seconds_remaining,
        };

        if let Err(err) = self
            .send_json_message(functionality, MSG_UPDATE_DOWNLOAD_STATUS, &status)
            .await
        {
            error!(error = ?err, "Failed to send update status");
        }
    }

    pub async fn begin_restart_countdown(&mut self, functionality: &BackendReplier<Self>) {
        self.update_state.in_progress = false;
        self.update_state.error = None;
        self.update_state.pending_update_url = None;
        self.update_state.pending_restart = true;
        self.update_state.restart_seconds_remaining = Some(UPDATE_RESTART_DELAY_SECS as u32);
        self.update_state.progress_message =
            Some("Update installed. Restarting shortly...".to_string());
        self.send_update_status(functionality).await;
        self.schedule_delayed_restart();
    }

    pub fn schedule_delayed_restart(&self) {
        tokio::spawn(async {
            sleep(Duration::from_secs(UPDATE_RESTART_DELAY_SECS)).await;
            warn!("Restarting backend after update countdown finished...");
            std::process::exit(0);
        });
    }

    pub async fn handle_update_restart_request(&mut self, functionality: &BackendReplier<Self>) {
        if !self.update_state.pending_restart {
            self.send_error(functionality, "No pending update closure");
            return;
        }
        self.update_state.progress_message = Some("Restarting now...".to_string());
        self.update_state.restart_seconds_remaining = Some(0);
        self.send_update_status(functionality).await;
        sleep(Duration::from_millis(250)).await;
        std::process::exit(0);
    }
}
