use tokio::sync::mpsc;
use tracing::error;

use crate::deployment::InstallerStatus;
use crate::types::MonitorError;
use appload_client::BackendReplier;

use super::super::protocol::MSG_INSTALL_STATUS;
use super::super::Backend;
use super::progress_runner::ProgressTarget;

impl Backend {
    pub async fn send_install_status(&self, functionality: &BackendReplier<Self>) {
        let status = self.build_install_status().await;
        if let Err(err) = self
            .send_json_message(functionality, MSG_INSTALL_STATUS, &status)
            .await
        {
            error!(error = ?err, "Failed to send installer status");
        }
    }

    pub async fn build_install_status(&self) -> InstallerStatus {
        let binary_present = self.installer.binary_present().await;
        let service_installed = self.installer.service_installed().await;
        InstallerStatus {
            binary_present,
            service_installed,
            in_progress: self.installer_state.in_progress,
            progress_message: self.installer_state.progress_message.clone(),
            error: self.installer_state.error.clone(),
            installer_disabled: self.config.disable_syncthing_installer,
        }
    }

    pub async fn run_installer(&mut self, functionality: &BackendReplier<Self>) {
        self.installer_state.in_progress = true;
        self.installer_state.error = None;
        self.installer_state.progress_message =
            Some("Checking Syncthing installation...".to_string());
        self.send_install_status(functionality).await;

        if !self.installer.binary_present().await {
            self.installer_state.progress_message =
                Some("Downloading latest Syncthing release...".to_string());
            self.send_install_status(functionality).await;
            let (progress_tx, progress_rx) = mpsc::channel(16);
            let installer = self.installer.clone();
            let download_future =
                Box::pin(async move { installer.download_latest_binary(Some(progress_tx)).await });

            match self
                .run_with_download_progress(
                    functionality,
                    download_future,
                    progress_rx,
                    ProgressTarget::Installer,
                    "Downloading latest Syncthing release",
                    None,
                )
                .await
            {
                Ok(()) => {}
                Err(err) => {
                    self.finish_installer_with_error(err, functionality).await;
                    return;
                }
            }
        }

        self.installer_state.progress_message =
            Some("Binary ready. Preparing systemd service...".to_string());
        self.send_install_status(functionality).await;

        let service_installed = self.installer.service_installed().await;

        if !service_installed {
            self.installer_state.progress_message =
                Some("Creating and enabling systemd service...".to_string());
            self.send_install_status(functionality).await;
            if let Err(err) = self.installer.install_service().await {
                self.finish_installer_with_error(err, functionality).await;
                return;
            }
        } else {
            self.installer_state.progress_message =
                Some("Restarting existing Syncthing service...".to_string());
            self.send_install_status(functionality).await;
            if let Err(err) = self.installer.restart_service().await {
                self.finish_installer_with_error(err, functionality).await;
                return;
            }
        }

        self.installer_state.progress_message =
            Some("Syncthing installed successfully.".to_string());
        self.installer_state.in_progress = false;
        self.installer_state.error = None;
        self.send_install_status(functionality).await;
        self.send_status(functionality, "installer").await;
    }

    pub async fn finish_installer_with_error(
        &mut self,
        err: MonitorError,
        functionality: &BackendReplier<Self>,
    ) {
        self.installer_state.in_progress = false;
        self.installer_state.error = Some(err.to_string());
        self.installer_state.progress_message =
            Some("Installer failed. See error for details.".to_string());
        self.send_install_status(functionality).await;
    }
}
