use std::future::Future;
use std::pin::Pin;

use appload_client::BackendReplier;
use tokio::sync::mpsc;

use crate::deployment::{
    render_download_progress_message, should_emit_download_progress, DownloadProgress,
};
use crate::types::MonitorError;

use super::super::Backend;

pub enum ProgressTarget {
    Installer,
    AppUpdate,
}

type ProgressFuture<T> = Pin<Box<dyn Future<Output = Result<T, MonitorError>> + Send>>;

impl Backend {
    pub async fn run_with_download_progress<T>(
        &mut self,
        functionality: &BackendReplier<Self>,
        mut operation: ProgressFuture<T>,
        mut progress_rx: mpsc::Receiver<DownloadProgress>,
        target: ProgressTarget,
        progress_prefix: &str,
        completion_message: Option<&str>,
    ) -> Result<T, MonitorError> {
        let mut operation_result: Option<Result<T, MonitorError>> = None;
        let mut channel_open = true;
        let mut completion_reported = false;
        let mut last_percent_reported: Option<u8> = None;
        let mut last_bytes_reported: u64 = 0;

        while operation_result.is_none() || channel_open {
            tokio::select! {
                result = &mut operation, if operation_result.is_none() => {
                    operation_result = Some(result);
                }
                progress = progress_rx.recv(), if channel_open => {
                    match progress {
                        Some(progress) => {
                            if should_emit_download_progress(
                                &progress,
                                &mut last_percent_reported,
                                &mut last_bytes_reported,
                            ) {
                                self.set_progress_message(
                                    &target,
                                    render_download_progress_message(progress_prefix, &progress),
                                );
                                self.send_progress_status(functionality, &target).await;
                            }
                        }
                        None => {
                            channel_open = false;
                            if !completion_reported && operation_result.is_none() {
                                if let Some(message) = completion_message {
                                    completion_reported = true;
                                    self.set_progress_message(&target, message.to_string());
                                    self.send_progress_status(functionality, &target).await;
                                }
                            }
                        }
                    }
                }
            }
        }

        match operation_result {
            Some(result) => result,
            None => Err(MonitorError::Config(
                "Download operation ended without a result".to_string(),
            )),
        }
    }

    fn set_progress_message(&mut self, target: &ProgressTarget, message: String) {
        match target {
            ProgressTarget::Installer => self.installer_state.progress_message = Some(message),
            ProgressTarget::AppUpdate => self.update_state.progress_message = Some(message),
        }
    }

    async fn send_progress_status(
        &self,
        functionality: &BackendReplier<Self>,
        target: &ProgressTarget,
    ) {
        match target {
            ProgressTarget::Installer => self.send_install_status(functionality).await,
            ProgressTarget::AppUpdate => self.send_update_status(functionality).await,
        }
    }
}
