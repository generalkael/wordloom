//! The interface size (Preferences ▸ General): a scale for the whole UI,
//! applied through Qt's `QT_SCALE_FACTOR` when the app starts. It is kept
//! in a small file next to the recent-projects list, because the app must
//! read it before Qt (and so QSettings) is running.

use std::path::{Path, PathBuf};

use crate::{Error, Result};

/// The sizes offered, and the limits of what's accepted.
pub const MIN: f64 = 0.75;
pub const MAX: f64 = 2.5;

fn file(dir: &Path) -> PathBuf {
    dir.join("interface-scale")
}

/// The saved scale (1.0 if none, or if the file is unreadable or out of range).
pub fn load(dir: &Path) -> f64 {
    std::fs::read_to_string(file(dir))
        .ok()
        .and_then(|s| s.trim().parse::<f64>().ok())
        .filter(|f| f.is_finite() && (MIN..=MAX).contains(f))
        .unwrap_or(1.0)
}

/// Save a scale for the next start; 1.0 removes the file. Returns what was saved.
pub fn save(dir: &Path, scale: f64) -> Result<f64> {
    if !scale.is_finite() || !(MIN..=MAX).contains(&scale) {
        return Err(Error::Invalid(format!(
            "the interface size must be between {}% and {}%",
            MIN * 100.0,
            MAX * 100.0
        )));
    }
    let scale = (scale * 100.0).round() / 100.0;
    if (scale - 1.0).abs() < 1e-9 {
        match std::fs::remove_file(file(dir)) {
            Err(e) if e.kind() != std::io::ErrorKind::NotFound => return Err(e.into()),
            _ => {}
        }
    } else {
        std::fs::create_dir_all(dir)?;
        crate::storage::write_atomic(&file(dir), format!("{scale}\n").as_bytes())?;
    }
    Ok(scale)
}

/// The scale this run uses (QT_SCALE_FACTOR, set by the app or the user).
pub fn running() -> f64 {
    std::env::var("QT_SCALE_FACTOR")
        .ok()
        .and_then(|s| s.trim().parse::<f64>().ok())
        .filter(|f| f.is_finite() && *f > 0.0)
        .unwrap_or(1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn saves_and_loads() {
        let tmp = tempfile::tempdir().unwrap();
        let dir = tmp.path().join("cfg");
        assert_eq!(load(&dir), 1.0);
        assert_eq!(save(&dir, 1.254).unwrap(), 1.25);
        assert_eq!(load(&dir), 1.25);
        assert!(save(&dir, 9.0).is_err() && save(&dir, f64::NAN).is_err());
        assert_eq!(load(&dir), 1.25);
        save(&dir, 1.0).unwrap();
        assert!(!file(&dir).exists());
        save(&dir, 1.0).unwrap();
        std::fs::write(file(&dir), "lots").unwrap();
        assert_eq!(load(&dir), 1.0);
    }
}
