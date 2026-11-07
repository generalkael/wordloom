import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.wordloom.app

// View ▸ Editor Font & Spacing…: the writing font, its size and the line
// spacing, with a live sample. Changes apply at once (and to every open
// editor); Reset goes back to the defaults. Zoom is separate (Ctrl+= / −).
Dialog {
    id: td
    title: qsTr("Editor Font & Spacing")
    modal: false
    width: 560
    standardButtons: Dialog.Close

    readonly property var allFamilies: Qt.fontFamilies()
    property string filter: ""
    readonly property var families: {
        const f = filter.trim().toLowerCase();
        return f ? allFamilies.filter(n => n.toLowerCase().indexOf(f) >= 0) : allFamilies;
    }
    readonly property bool installed: allFamilies.indexOf(Theme.editorFont) >= 0
    // A few good writing fonts, shown first when installed.
    readonly property var suggested: ["Georgia", "Libre Baskerville", "Merriweather", "Noto Serif", "DejaVu Serif",
        "Liberation Serif", "Times New Roman", "Courier Prime", "Courier New", "Noto Sans", "DejaVu Sans", "Arial"]
        .filter(n => allFamilies.indexOf(n) >= 0)
    readonly property var spacings: [
        { v: 1.0, name: qsTr("Single") }, { v: 1.15, name: "1.15" }, { v: 1.3, name: "1.3" },
        { v: 1.45, name: qsTr("1.45 (default)") }, { v: 1.6, name: "1.6" }, { v: 1.8, name: "1.8" },
        { v: 2.0, name: qsTr("Double") }
    ]
    function choose(name) { Theme.editorFont = name; }
    onAboutToShow: { filter = ""; familyList.positionViewAtIndex(Math.max(0, families.indexOf(Theme.editorFont)), ListView.Center); }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            // Font family list
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 260
                spacing: 4
                Label { text: qsTr("Font"); font.bold: true; color: Theme.text }
                TextField {
                    id: filterField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search fonts")
                    selectByMouse: true
                    text: td.filter
                    onTextEdited: td.filter = text
                    Keys.onReturnPressed: if (td.families.length) td.choose(td.families[0])
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: td.suggested.length > 0 && td.filter === ""
                    Repeater {
                        model: td.suggested.slice(0, 6)
                        delegate: Button {
                            required property string modelData
                            text: modelData
                            font.family: modelData
                            flat: Theme.editorFont !== modelData
                            highlighted: Theme.editorFont === modelData
                            onClicked: td.choose(modelData)
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: Theme.base
                    border.color: Theme.border
                    radius: 3
                    ListView {
                        id: familyList
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true
                        model: td.families
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ItemDelegate {
                            required property string modelData
                            width: ListView.view.width
                            height: 28
                            clip: true   // some display fonts draw far outside their line
                            highlighted: modelData === Theme.editorFont
                            contentItem: Label { text: modelData; font.family: modelData; font.pixelSize: 14; elide: Text.ElideRight; color: Theme.text; verticalAlignment: Text.AlignVCenter }
                            onClicked: td.choose(modelData)
                        }
                    }
                    Label { anchors.centerIn: parent; visible: td.families.length === 0; text: qsTr("No fonts match"); color: Theme.subtext }
                }
                Label {
                    Layout.fillWidth: true
                    visible: !td.installed
                    wrapMode: Text.Wrap
                    color: Theme.subtext
                    font.pixelSize: 11
                    text: qsTr("“%1” isn't installed, so a similar font is used.").arg(Theme.editorFont)
                }
            }
            // Size and spacing
            GridLayout {
                Layout.alignment: Qt.AlignTop
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Label { text: qsTr("Size"); color: Theme.text }
                SpinBox {
                    id: sizeBox
                    from: 9; to: 40
                    value: Theme.editorSize
                    editable: true
                    onValueModified: Theme.editorSize = value
                }
                Label { text: qsTr("Line spacing"); color: Theme.text }
                ComboBox {
                    id: spacingBox
                    Layout.preferredWidth: 150
                    model: td.spacings.map(s => s.name)
                    currentIndex: {
                        const i = td.spacings.findIndex(s => Math.abs(s.v - Theme.lineHeight) < 0.01);
                        return i;
                    }
                    displayText: currentIndex >= 0 ? currentText : Theme.lineHeight.toFixed(2)
                    onActivated: (i) => Theme.lineHeight = td.spacings[i].v
                }
                Label { text: qsTr("Zoom"); color: Theme.text }
                RowLayout {
                    spacing: 2
                    ToolButton { text: "−"; onClicked: Theme.zoomOut(); ToolTip.visible: hovered; ToolTip.text: qsTr("Zoom out (Ctrl+−)") }
                    Label { text: Theme.zoomText; color: Theme.text; Layout.minimumWidth: 40; horizontalAlignment: Text.AlignHCenter }
                    ToolButton { text: "+"; onClicked: Theme.zoomIn(); ToolTip.visible: hovered; ToolTip.text: qsTr("Zoom in (Ctrl+=)") }
                    ToolButton { text: qsTr("Reset"); enabled: Theme.editorZoom !== 1; onClicked: Theme.resetZoom(); ToolTip.visible: hovered; ToolTip.text: qsTr("Actual size (Ctrl+0)") }
                }
                Item { Layout.columnSpan: 2; Layout.preferredHeight: 4 }
                Button {
                    Layout.columnSpan: 2
                    text: qsTr("Reset to Defaults")
                    onClicked: { Theme.editorFont = Theme.defaultEditorFont; Theme.editorSize = 15; Theme.lineHeight = 1.45; Theme.resetZoom(); }
                }
            }
        }

        // A sample in the chosen font, size and spacing (at 100% zoom).
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: Theme.paper
            border.color: Theme.border
            radius: 3
            clip: true
            Text {
                id: sample
                anchors.fill: parent
                anchors.margins: 14
                wrapMode: Text.Wrap
                font.family: Theme.editorFont
                font.pixelSize: Theme.editorSize
                lineHeight: Theme.lineHeight
                color: Theme.ink
                textFormat: Text.StyledText
                text: qsTr("<b>The storm came in at dusk.</b> Elias climbed the hundred and twelve steps, counting each one, as his father had — <i>never trust a light you haven't checked yourself.</i> Below, the sea threw itself against the rocks.")
            }
        }
    }
}
