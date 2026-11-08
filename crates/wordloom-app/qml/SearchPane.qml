import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import com.wordloom.app

// Project-wide search results (in the binder while its search box has
// text), with match case / whole words and replace. Replace changes document
// text only, in the documents ticked in the results (all of them at first),
// as one undo step; the Trash is left alone.
ColumnLayout {
    id: sp
    property string query: ""
    property var hits: []
    property bool matchCase: false
    property bool wholeWords: false
    // Text hits the user unticked, by document id.
    property var skipped: ({})
    signal chosen(string id, string field)
    spacing: 4

    Settings {
        category: "search"
        property alias matchCase: sp.matchCase
        property alias wholeWords: sp.wholeWords
    }

    readonly property int rev: Wordloom.revision
    onRevChanged: run()
    onQueryChanged: { skipped = {}; debounce.restart(); }
    onMatchCaseChanged: { skipped = {}; run(); }
    onWholeWordsChanged: { skipped = {}; run(); }
    Timer { id: debounce; interval: 200; onTriggered: sp.run() }
    function run() { hits = query.trim().length ? Api.get("search", [], query, matchCase, wholeWords) : []; }

    readonly property var textHits: hits.filter(h => h.field === "text")
    readonly property var chosenHits: textHits.filter(h => !skipped[h.id])
    readonly property int replaceCount: chosenHits.reduce((n, h) => n + h.count, 0)
    function setSkipped(id, on) {
        const s = Object.assign({}, skipped);
        if (on) s[id] = true; else delete s[id];
        skipped = s;
    }
    function setAll(on) {
        const s = {};
        if (!on) for (const h of textHits) s[h.id] = true;
        skipped = s;
    }
    // Replace in the ticked documents; returns the result (self-test).
    function replace(withText) {
        if (!chosenHits.length) return undefined;
        const ids = chosenHits.map(h => h.id);
        const r = Api.call("replaceAll", query.trim(), withText, matchCase, wholeWords, ids);
        if (r) Api.say(qsTr("Replaced %1 in %2 document(s) (Ctrl+Z undoes it)").arg(r.replacements).arg(r.documents));
        return r;
    }
    function focusReplace() { replaceField.forceActiveFocus(); replaceField.selectAll(); }

    // The snippet as rich text, with each match in bold.
    function marked(snippet) {
        const esc = (t) => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const q = query.trim();
        if (!q) return esc(snippet);
        const pat = q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const re = new RegExp(pat, matchCase ? "g" : "gi");
        // A letter, digit or underscore (for whole words).
        const wordy = (c) => c !== undefined && (c.toLowerCase() !== c.toUpperCase() || /[0-9_]/.test(c));
        let out = "", at = 0, m;
        while ((m = re.exec(snippet)) !== null) {
            if (m[0].length === 0) { re.lastIndex++; continue; }
            const end = m.index + m[0].length;
            if (wholeWords && (wordy(snippet[m.index - 1]) || wordy(snippet[end]))) { re.lastIndex = m.index + 1; continue; }
            out += esc(snippet.substring(at, m.index)) + "<b>" + esc(m[0]) + "</b>";
            at = end;
        }
        return out + esc(snippet.substring(at));
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        spacing: 2
        ToolButton {
            text: "Aa"
            checkable: true
            checked: sp.matchCase
            onToggled: sp.matchCase = checked
            focusPolicy: Qt.NoFocus
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Match case")
        }
        ToolButton {
            text: qsTr("Word")
            checkable: true
            checked: sp.wholeWords
            onToggled: sp.wholeWords = checked
            focusPolicy: Qt.NoFocus
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Whole words only (“lamp”, not “lamplight”)")
        }
        Item { Layout.fillWidth: true }
        Label {
            color: Theme.subtext
            font.pixelSize: 12
            text: sp.hits.length ? qsTr("%1 result(s)").arg(sp.hits.length) : qsTr("No matches")
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        TextField {
            id: replaceField
            Layout.fillWidth: true
            placeholderText: qsTr("Replace with…")
            selectByMouse: true
            Keys.onReturnPressed: if (replaceButton.enabled) replaceButton.clicked()
        }
        Button {
            id: replaceButton
            text: sp.replaceCount ? qsTr("Replace %1").arg(sp.replaceCount) : qsTr("Replace")
            enabled: sp.replaceCount > 0
            onClicked: sp.replace(replaceField.text)
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: qsTr("Replace in the text of the ticked documents (titles, synopses and notes are left alone)")
        }
    }
    CheckBox {
        Layout.leftMargin: 4
        visible: sp.textHits.length > 1
        text: qsTr("All %1 documents").arg(sp.textHits.length)
        tristate: true
        checkState: sp.chosenHits.length === 0 ? Qt.Unchecked
            : sp.chosenHits.length === sp.textHits.length ? Qt.Checked : Qt.PartiallyChecked
        nextCheckState: () => sp.chosenHits.length === sp.textHits.length ? Qt.Unchecked : Qt.Checked
        onClicked: sp.setAll(checkState === Qt.Checked)
    }
    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: sp.hits
        ScrollBar.vertical: ScrollBar {}
        delegate: ItemDelegate {
            id: hitRow
            required property var modelData
            width: ListView.view.width
            onClicked: sp.chosen(modelData.id, modelData.field)
            contentItem: RowLayout {
                spacing: 4
                CheckBox {
                    Layout.alignment: Qt.AlignTop
                    visible: hitRow.modelData.field === "text"
                    checked: !sp.skipped[hitRow.modelData.id]
                    onToggled: sp.setSkipped(hitRow.modelData.id, !checked)
                    padding: 0
                    focusPolicy: Qt.NoFocus
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: qsTr("Include this document when replacing")
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    RowLayout {
                        Label { text: hitRow.modelData.title; font.bold: true; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true }
                        Label { text: hitRow.modelData.field + (hitRow.modelData.count > 1 ? " ×" + hitRow.modelData.count : ""); color: Theme.accent; font.pixelSize: 11 }
                    }
                    Label {
                        text: sp.marked(hitRow.modelData.snippet)
                        textFormat: Text.StyledText
                        color: Theme.subtext
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
