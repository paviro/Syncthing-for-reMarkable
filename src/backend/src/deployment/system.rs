//! System-level helpers shared across deployment workflows.

use tokio::process::Command;

use crate::types::MonitorError;

pub async fn run_command(command: &str, args: &[&str]) -> Result<(), MonitorError> {
    let output = Command::new(command).args(args).output().await?;
    if output.status.success() {
        return Ok(());
    }

    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    Err(MonitorError::Config(if stderr.is_empty() {
        format!(
            "Command `{}` with args {:?} failed with status {}",
            command, args, output.status
        )
    } else {
        format!(
            "Command `{}` with args {:?} failed: {}",
            command, args, stderr
        )
    }))
}

