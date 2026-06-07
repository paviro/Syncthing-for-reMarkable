use std::fs::File;
use std::path::Path;

use flate2::read::GzDecoder;
use tar::Archive;
use tokio::task;
use zip::ZipArchive;

use crate::types::MonitorError;

pub async fn extract_zip_archive(zip_path: &Path, extract_dir: &Path) -> Result<(), MonitorError> {
    let zip_path = zip_path.to_path_buf();
    let extract_dir = extract_dir.to_path_buf();

    task::spawn_blocking(move || -> Result<(), MonitorError> {
        let file = File::open(&zip_path)?;
        let mut archive = ZipArchive::new(file)
            .map_err(|err| MonitorError::Config(format!("Failed to open zip archive: {}", err)))?;

        for index in 0..archive.len() {
            let mut file = archive.by_index(index).map_err(|err| {
                MonitorError::Config(format!("Failed to read zip entry: {}", err))
            })?;

            let outpath = match file.enclosed_name() {
                Some(path) => extract_dir.join(path),
                None => continue,
            };

            if file.name().ends_with('/') {
                std::fs::create_dir_all(&outpath)?;
            } else {
                if let Some(parent) = outpath.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                let mut outfile = File::create(&outpath)?;
                std::io::copy(&mut file, &mut outfile)?;
            }

            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                if let Some(mode) = file.unix_mode() {
                    std::fs::set_permissions(&outpath, std::fs::Permissions::from_mode(mode))?;
                }
            }
        }

        Ok(())
    })
    .await
    .map_err(|err| MonitorError::Config(format!("Extraction task failed: {}", err)))??;

    Ok(())
}

pub async fn extract_tarball_file(
    tarball_path: &Path,
    entry_path: &Path,
    destination: &Path,
) -> Result<(), MonitorError> {
    let tarball_path = tarball_path.to_path_buf();
    let entry_path = entry_path.to_path_buf();
    let destination = destination.to_path_buf();

    task::spawn_blocking(move || -> Result<(), MonitorError> {
        let file = std::fs::File::open(&tarball_path)?;
        let decoder = GzDecoder::new(file);
        let mut archive = Archive::new(decoder);
        let mut found = false;

        for entry_result in archive.entries()? {
            let mut entry = entry_result?;
            let matches = {
                let current_path = entry.path()?;
                current_path.as_ref() == entry_path.as_path()
            };

            if matches {
                if !entry.header().entry_type().is_file() {
                    return Err(MonitorError::Config(format!(
                        "Archive entry is not a regular file: {}",
                        entry_path.display()
                    )));
                }
                entry.unpack(&destination)?;
                found = true;
                break;
            }
        }

        if !found {
            return Err(MonitorError::Config(format!(
                "Archive did not contain expected entry: {}",
                entry_path.display()
            )));
        }

        Ok(())
    })
    .await
    .map_err(|err| {
        MonitorError::Config(format!("Extraction task failed to complete: {}", err))
    })??;

    Ok(())
}

#[cfg(test)]
mod tests {
    use std::path::Path;

    use flate2::write::GzEncoder;
    use flate2::Compression;
    use tar::{Builder, Header};
    use tempfile::NamedTempFile;

    use super::*;

    fn create_tarball(entries: &[(&str, &[u8])]) -> NamedTempFile {
        let encoder = GzEncoder::new(Vec::new(), Compression::default());
        let mut builder = Builder::new(encoder);

        for (path, contents) in entries {
            let mut header = Header::new_gnu();
            header.set_size(contents.len() as u64);
            header.set_mode(0o644);
            header.set_cksum();
            builder
                .append_data(&mut header, *path, *contents)
                .expect("append tar entry");
        }

        let encoder = builder.into_inner().expect("finish tar builder");
        let bytes = encoder.finish().expect("finish gzip encoder");
        let tarball = NamedTempFile::new().expect("create tarball tempfile");
        std::fs::write(tarball.path(), bytes).expect("write tarball tempfile");
        tarball
    }

    fn create_tarball_with_directory(path: &str) -> NamedTempFile {
        let encoder = GzEncoder::new(Vec::new(), Compression::default());
        let mut builder = Builder::new(encoder);
        builder.append_dir(path, ".").expect("append tar directory");
        let encoder = builder.into_inner().expect("finish tar builder");
        let bytes = encoder.finish().expect("finish gzip encoder");
        let tarball = NamedTempFile::new().expect("create tarball tempfile");
        std::fs::write(tarball.path(), bytes).expect("write tarball tempfile");
        tarball
    }

    #[tokio::test]
    async fn extract_tarball_file_uses_exact_path_not_basename() {
        let nested_profile = b"[syncthing]\ntitle=Syncthing\n";
        let binary = b"\x7fELFsyncthing";
        let tarball = create_tarball(&[
            (
                "syncthing-linux-arm64-v2.1.1/etc/firewall-ufw/syncthing",
                nested_profile,
            ),
            ("syncthing-linux-arm64-v2.1.1/syncthing", binary),
        ]);
        let destination = NamedTempFile::new().expect("create destination tempfile");

        extract_tarball_file(
            tarball.path(),
            Path::new("syncthing-linux-arm64-v2.1.1/syncthing"),
            destination.path(),
        )
        .await
        .expect("extract release binary");

        let extracted = std::fs::read(destination.path()).expect("read extracted entry");
        assert_eq!(extracted, binary);
    }

    #[tokio::test]
    async fn extract_tarball_file_fails_without_exact_path() {
        let tarball = create_tarball(&[(
            "syncthing-linux-arm64-v2.1.1/etc/firewall-ufw/syncthing",
            b"[syncthing]\n",
        )]);
        let destination = NamedTempFile::new().expect("create destination tempfile");

        let result = extract_tarball_file(
            tarball.path(),
            Path::new("syncthing-linux-arm64-v2.1.1/syncthing"),
            destination.path(),
        )
        .await;

        assert!(result.is_err());
    }

    #[tokio::test]
    async fn extract_tarball_file_rejects_matching_directory() {
        let tarball = create_tarball_with_directory("syncthing-linux-arm64-v2.1.1/syncthing");
        let destination = NamedTempFile::new().expect("create destination tempfile");

        let result = extract_tarball_file(
            tarball.path(),
            Path::new("syncthing-linux-arm64-v2.1.1/syncthing"),
            destination.path(),
        )
        .await;

        assert!(result.is_err());
    }
}
