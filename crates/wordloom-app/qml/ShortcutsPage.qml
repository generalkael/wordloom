import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.wordloom.app
import com.wordloom.styling

// Preferences ▸ Keyboard Shortcuts: every menu command with its keys.
// Click a shortcut and press the new keys (Esc cancels, Backspace removes
// it); a command that already had those keys loses them.
ColumnLayout {
    id: page
    spacing: 8

    KeyText { id: keyText }
    property string filter: ""
    // The command waiting for keys, and what the last change did.
    property string recording: ""
    property string notice: ""
    readonly property var shown: {
        const f = filter.trim().toLowerCase();
        Shortcuts.customJson;   // refilter when keys change
        return Shortcuts.commands.filter(c => !f || (c.menu + " " + c.name).toLowerCase().indexOf(f) >= 0
            || keyText.nativeText(Shortcuts.seq(c.id)).toLowerCase().indexOf(f) >= 0);
    }
    function shortcutText(id) { const k = Shortcuts.seq(id); return k ? keyText.nativeText(k) : "—"; }

    function record(id) { recording = id; notice = ""; }
    // Click command `id`'s shortcut button, as the user would (self-test).
    function startRecording(id) {
        filter = "";
        const i = shown.findIndex(c => c.id === id);
        list.positionViewAtIndex(i, ListView.Contain);
        const it = list.itemAtIndex(i);
        if (it) it.button.clicked();
        return !!it && it.button.activeFocus;
    }
    // Use `keys` (portable text) for the command being recorded.
    function setKeys(id, keys) {
        const taken = Shortcuts.assign(id, keys);
        const c = Shortcuts.command(id);
        notice = taken ? qsTr("%1 is now %2. It was %3's, which now has none.").arg(keyText.nativeText(keys)).arg(c.name).arg(taken.name)
            : keys ? qsTr("%1 is now %2.").arg(keyText.nativeText(keys)).arg(c.name) : qsTr("%1 has no shortcut now.").arg(c.name);
        recording = "";
        return taken;
    }
    function keyPressed(e) {
        if (!recording) return false;
        if (e.key === Qt.Key_Escape && !e.modifiers) { recording = ""; return true; }
        if ((e.key === Qt.Key_Backspace || e.key === Qt.Key_Delete) && !e.modifiers) { setKeys(recording, ""); return true; }
        const k = keyText.fromEvent(e.key, e.modifiers);
        if (k) setKeys(recording, k);
        return true;
    }

    RowLayout {
        Layout.fillWidth: true
        TextField {
            Layout.fillWidth: true
            placeholderText: qsTr("Find a command or shortcut")
            selectByMouse: true
            text: page.filter
            onTextEdited: page.filter = text
        }
        Button {
            text: qsTr("Reset All")
            enabled: Shortcuts.customJson !== "{}"
            onClicked: { Shortcuts.resetAll(); page.notice = qsTr("Every shortcut is back to its default."); page.recording = ""; }
        }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: page.notice ? Theme.text : Theme.subtext
        font.pixelSize: Theme.px(12)
        text: page.recording ? qsTr("Press the new keys for %1. Esc cancels; Backspace removes the shortcut.").arg(Shortcuts.command(page.recording).name)
            : page.notice || qsTr("Click a shortcut to change it. Ctrl is ⌘ on macOS.")
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 200
        color: Theme.base
        border.color: Theme.border
        radius: 3
        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            model: page.shown
            ScrollBar.vertical: ScrollBar {}
            section.property: "menu"
            section.delegate: Label {
                required property string section
                width: ListView.view.width
                leftPadding: 8; topPadding: 6; bottomPadding: 2
                text: section
                font.bold: true
                color: Theme.subtext
                font.pixelSize: Theme.px(11)
            }
            delegate: Item {
                id: row
                required property var modelData
                property alias button: keyButton
                width: ListView.view.width
                height: Theme.px(32)
                readonly property bool custom: { Shortcuts.customJson; return Shortcuts.isCustom(modelData.id); }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    Label { Layout.fillWidth: true; text: row.modelData.name; color: Theme.text; elide: Text.ElideRight }
                    Button {
                        id: keyButton
                        Layout.preferredWidth: 150
                        flat: page.recording !== row.modelData.id
                        highlighted: page.recording === row.modelData.id
                        font.bold: row.custom
                        text: page.recording === row.modelData.id ? qsTr("Press keys…") : (Shortcuts.customJson, page.shortcutText(row.modelData.id))
                        onClicked: { page.record(row.modelData.id); forceActiveFocus(); }
                        onActiveFocusChanged: if (!activeFocus && page.recording === row.modelData.id) page.recording = ""
                        // Take every key while recording, before menu shortcuts see it.
                        Keys.onShortcutOverride: (e) => { if (page.recording === row.modelData.id) e.accepted = true; }
                        Keys.onPressed: (e) => { if (page.recording === row.modelData.id && page.keyPressed(e)) e.accepted = true; }
                        ToolTip.visible: hovered && page.recording !== row.modelData.id
                        ToolTip.delay: 600
                        ToolTip.text: row.custom ? qsTr("Changed (default: %1). Click to change.").arg(row.modelData.keys ? keyText.nativeText(row.modelData.keys) : qsTr("none")) : qsTr("Click to change")
                    }
                    ToolButton {
                        text: "↺"
                        enabled: row.custom
                        opacity: enabled ? 1 : 0.25
                        focusPolicy: Qt.NoFocus
                        onClicked: { const t = Shortcuts.reset(row.modelData.id); page.notice = t ? qsTr("%1 is back to its default; %2 has no shortcut now.").arg(row.modelData.name).arg(t.name) : qsTr("%1 is back to its default.").arg(row.modelData.name); }
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Back to the default")
                    }
                }
            }
        }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.subtext
        font.pixelSize: Theme.px(12)
        text: qsTr("These are the menu commands. Keys inside views (the binder's F2 and arrows, F3 in the find bar, Esc) stay as they are.")
    }
}
