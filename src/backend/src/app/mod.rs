mod event_stream;
mod operations;
pub mod protocol;
mod realtime;
mod status_builder;

pub use protocol::{ControlRequest, GuiAddressToggleRequest};

use async_trait::async_trait;
use serde::Serialize;
use serde_json::json;
use tokio::task::JoinHandle;
use tracing::error;

use crate::config::Config;
use crate::deployment::{Installer, Updater};
use crate::syncthing_client::{SyncthingClient, SyncthingUpgradeCheck};
use crate::types::MonitorError;
use appload_client::{AppLoadBackend, BackendReplier, Message};

use self::protocol::*;

#[derive(Debug, Default)]
pub struct InstallerFlowState {
    pub in_progress: bool,
    pub progress_message: Option<String>,
    pub error: Option<String>,
}

#[derive(Debug, Default)]
pub struct AppUpdateFlowState {
    pub in_progress: bool,
    pub progress_message: Option<String>,
    pub error: Option<String>,
    pub pending_update_url: Option<String>,
    pub pending_restart: bool,
    pub restart_seconds_remaining: Option<u32>,
}

#[derive(Debug, Default)]
pub struct SyncthingUpdateFlowState {
    pub check_result: Option<SyncthingUpgradeCheck>,
    pub in_progress: bool,
    pub progress_message: Option<String>,
    pub error: Option<String>,
    pub upgrade_started: bool,
}

pub struct Backend {
    pub client: Option<SyncthingClient>,
    pub config: Config,
    pub installer: Installer,
    pub installer_state: InstallerFlowState,
    pub updater: Updater,
    pub update_state: AppUpdateFlowState,
    pub syncthing_update_state: SyncthingUpdateFlowState,
    pub realtime_task: Option<JoinHandle<()>>,
    pub systemd_monitor_task: Option<JoinHandle<()>>,
}

impl Backend {
    pub async fn new(config: Config) -> Self {
        let client = SyncthingClient::discover(&config).await.ok();
        let installer = Installer::new(config.clone());
        let updater = Updater::new();
        Self {
            client,
            config,
            installer,
            installer_state: InstallerFlowState::default(),
            updater,
            update_state: AppUpdateFlowState::default(),
            syncthing_update_state: SyncthingUpdateFlowState::default(),
            realtime_task: None,
            systemd_monitor_task: None,
        }
    }

    pub async fn send_status(&mut self, functionality: &BackendReplier<Self>, reason: &str) {
        let snapshot =
            status_builder::build_status_payload(&self.config, &mut self.client, reason).await;
        if let Err(err) = self
            .send_json_message(functionality, MSG_STATUS_UPDATE, &snapshot)
            .await
        {
            self.send_error(
                functionality,
                &format!("Failed to send status update: {err}"),
            );
        }
    }

    pub fn send_error(&self, functionality: &BackendReplier<Self>, message: &str) {
        let payload = json!({ "message": message });
        if let Err(err) = self.send_json_message_sync(functionality, MSG_ERROR, &payload) {
            error!(error = ?err, "Failed to send error message");
        }
    }

    pub async fn send_json_message<T>(
        &self,
        functionality: &BackendReplier<Self>,
        msg_type: u32,
        payload: &T,
    ) -> Result<(), MonitorError>
    where
        T: Serialize + ?Sized,
    {
        self.send_json_message_sync(functionality, msg_type, payload)
    }

    pub fn send_json_message_sync<T>(
        &self,
        functionality: &BackendReplier<Self>,
        msg_type: u32,
        payload: &T,
    ) -> Result<(), MonitorError>
    where
        T: Serialize + ?Sized,
    {
        let contents = serde_json::to_string(payload)?;
        functionality
            .send_message(msg_type, &contents)
            .map_err(|err| {
                MonitorError::Config(format!("Failed to send message {msg_type}: {err:?}"))
            })
    }
}

#[async_trait]
impl AppLoadBackend for Backend {
    async fn handle_message(&mut self, functionality: &BackendReplier<Self>, message: Message) {
        match message.msg_type {
            MSG_SYSTEM_NEW_COORDINATOR => {
                self.ensure_realtime_updates(functionality);
                self.send_install_status(functionality).await;
                self.send_syncthing_update_status(functionality).await;
                self.send_status(functionality, "frontend-connected").await;
            }
            MSG_CONTROL_REQUEST => {
                match serde_json::from_str::<ControlRequest>(&message.contents) {
                    Ok(req) => self.handle_service_control(functionality, req).await,
                    Err(err) => {
                        self.send_error(functionality, &format!("Invalid control payload: {err}"))
                    }
                }
            }
            MSG_INSTALL_TRIGGER => {
                if self.config.disable_syncthing_installer {
                    self.installer_state.error = Some(
                        "Installer disabled via config. Please install Syncthing manually."
                            .to_string(),
                    );
                    self.installer_state.progress_message = None;
                    self.installer_state.in_progress = false;
                    self.send_install_status(functionality).await;
                } else if self.installer_state.in_progress {
                    self.installer_state.progress_message =
                        Some("Installer is already running...".to_string());
                    self.send_install_status(functionality).await;
                } else {
                    self.run_installer(functionality).await;
                }
            }
            MSG_GUI_ADDRESS_TOGGLE => {
                match serde_json::from_str::<GuiAddressToggleRequest>(&message.contents) {
                    Ok(req) => {
                        self.handle_syncthing_gui_listen_address(functionality, req)
                            .await
                    }
                    Err(err) => self.send_error(
                        functionality,
                        &format!("Invalid GUI address toggle payload: {err}"),
                    ),
                }
            }
            MSG_UPDATE_CHECK_REQUEST => {
                self.handle_update_check(functionality).await;
            }
            MSG_UPDATE_DOWNLOAD_REQUEST => {
                self.handle_update_download(functionality).await;
            }
            MSG_UPDATE_RESTART_REQUEST => {
                self.handle_update_restart_request(functionality).await;
            }
            MSG_SYNCTHING_UPDATE_CHECK_REQUEST => {
                self.handle_syncthing_update_check(functionality).await;
            }
            MSG_SYNCTHING_UPDATE_INSTALL_REQUEST => {
                self.handle_syncthing_update_install(functionality).await;
            }
            other => {
                self.send_error(functionality, &format!("Unknown message type {other}"));
            }
        }
    }
}
