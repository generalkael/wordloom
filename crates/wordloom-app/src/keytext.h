// Key sequences as text, for Preferences ▸ Keyboard Shortcuts: turn a key
// press into "Ctrl+Shift+K", check and tidy typed sequences, and show them
// the way the platform does (⌘⇧K on macOS).
#pragma once

#include <QObject>
#include <QString>

class KeyText : public QObject
{
    Q_OBJECT
public:
    explicit KeyText(QObject *parent = nullptr);

    // The sequence for a key press (a Qt.Key_… value and Qt modifiers), in
    // portable form ("Ctrl+Shift+K"); "" for a bare modifier key.
    Q_INVOKABLE QString fromEvent(int key, int modifiers) const;
    // `text` parsed and written back in portable form; "" if it isn't a
    // single valid sequence.
    Q_INVOKABLE QString portable(const QString &text) const;
    // `text` (portable) as the platform shows it in menus.
    Q_INVOKABLE QString nativeText(const QString &text) const;
};
