//! Wordloom desktop application entry point.

// A release build on Windows is a GUI app: no console window opens with it.
#![cfg_attr(all(windows, not(debug_assertions)), windows_subsystem = "windows")]

mod controller;
mod styling;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QQuickStyle, QString, QUrl};

fn main() {
    // Preferences ▸ General ▸ Interface size scales the whole UI; Qt reads
    // it once, at startup. A QT_SCALE_FACTOR set by the user wins.
    if std::env::var_os("QT_SCALE_FACTOR").is_none() {
        let scale = wordloom_core::uiscale::load(&controller::config_dir());
        if (scale - 1.0).abs() > 1e-9 {
            std::env::set_var("QT_SCALE_FACTOR", scale.to_string());
        }
    }
    // The AppImage carries its own Qt without the desktop's theme plugins
    // (KDE's, GNOME's), so Qt can't tell the system is in dark mode and
    // Wordloom would start light, hiding colours chosen for the dark theme.
    // The bundled xdg-desktop-portal theme asks the desktop instead.
    if std::env::var_os("APPIMAGE").is_some()
        && std::env::var_os("QT_QPA_PLATFORMTHEME").is_none()
        && std::env::var("QT_QPA_PLATFORM").map_or(true, |p| p != "offscreen")
    {
        std::env::set_var("QT_QPA_PLATFORMTHEME", "xdgdesktopportal");
    }
    let mut app = QGuiApplication::new();
    if let Some(mut app) = app.as_mut() {
        app.as_mut()
            .set_application_name(&QString::from("Wordloom"));
        // The screenshot tour changes window size and view options; keep those
        // out of the user's saved preferences.
        let tour = std::env::args().any(|a| {
            a.starts_with("--screenshots=") || a == "--selftest" || a.starts_with("--bench=")
        });
        let org = if tour {
            "Wordloom-screenshots"
        } else {
            "Wordloom"
        };
        app.as_mut().set_organization_name(&QString::from(org));
        app.as_mut()
            .set_application_version(&QString::from(env!("CARGO_PKG_VERSION")));
    }
    // Matches packaging/linux/<id>.desktop, so Wayland compositors and
    // Flatpak tie windows to the right launcher and icon.
    QGuiApplication::set_desktop_file_name(&QString::from("io.github.generalkael.Wordloom"));
    // Fusion renders consistently on Linux, Windows and macOS and follows the
    // system light/dark palette. Users can override with QT_QUICK_CONTROLS_STYLE.
    if std::env::var_os("QT_QUICK_CONTROLS_STYLE").is_none() {
        QQuickStyle::set_style(&QString::from("Fusion"));
    }

    styling::ffi::register_styler_types();
    styling::ffi::set_app_icon();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/com/wordloom/app/qml/Main.qml"));
    }
    let code = app.as_mut().map(|app| app.exec()).unwrap_or(1);
    // Tear down QML before exiting so objects such as Settings (saved
    // preferences) get to write their final state; process::exit skips drops.
    drop(engine);
    drop(app);
    std::process::exit(code);
}
