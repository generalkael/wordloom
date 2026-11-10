import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import com.wordloom.app

// Binder ▸ right-click ▸ Icon & Colour…: a binder item's icon, the icon's
// colour, the title's colour and the row's background. Changes apply at
// once (each is one undo step) to every item it was opened for.
Dialog {
    id: ld
    title: ids.length > 1 ? qsTr("Icon & Colour (%1 items)").arg(ids.length) : qsTr("Icon & Colour")
    modal: false
    parent: Overlay.overlay
    anchors.centerIn: parent
    standardButtons: Dialog.Close

    // The items being changed; the first one's look is shown.
    property var ids: []
    property var node: null
    readonly property var look: node && node.look ? node.look : ({})
    readonly property int rev: Wordloom.revision
    onRevChanged: if (visible) refresh()
    function refresh() {
        node = ids.length ? Api.get("nodeInfo", null, ids[0]) : null;
        if (ids.length && !node) close();   // trashed or gone
    }
    function openFor(list) {
        ids = list.filter(i => !!i);
        if (!ids.length) return;
        refresh();
        open();
    }

    // Set one part ("icon", "icon_color", "text_color", "row_color") on every item.
    function set(field, value) {
        if (!ids.length) return false;
        const v = value === undefined || value === null ? "" : String(value);
        const r = ids.length > 1 ? Api.call("setFieldMany", ids, field, v) : Api.call("setField", ids[0], field, v);
        return r !== undefined;
    }
    // How many of the icons on offer have loaded, and the names of any that
    // failed (the self-test).
    function iconStates() {
        const out = { ready: 0, bad: [] };
        for (let i = 0; i < iconRep.count; ++i) {
            const c = iconRep.itemAt(i);
            if (c && c.image.status === Image.Ready) out.ready++;
            else out.bad.push((c ? c.modelData : "?") + ":" + (c ? c.image.status : "none"));
        }
        return out;
    }
    function resetAll() { return set("look", "{}"); }

    property string customField: ""
    ColorDialog {
        id: customColour
        title: qsTr("Choose a Colour")
        options: ld.customField === "row_color" ? ColorDialog.ShowAlphaChannel : 0
        onAccepted: ld.set(ld.customField, String(selectedColor))
    }
    function chooseCustom(field) {
        customField = field;
        customColour.selectedColor = look[field] || (field === "row_color" ? "#4d808080" : Theme.accent);
        customColour.open();
    }

    component Heading: Label { font.bold: true; color: Theme.text; Layout.topMargin: 6 }
    // One row of colour choices for `field`: default, the swatches, Custom….
    component SwatchRow: Flow {
        id: sr
        property string field
        property string defaultText: qsTr("Default")
        property bool translucent: false
        readonly property string current: ld.look[field] || ""
        Layout.fillWidth: true
        spacing: 4
        Button {
            text: sr.defaultText
            checkable: true
            checked: sr.current === ""
            onClicked: ld.set(sr.field, "")
            height: Theme.px(26)
        }
        Repeater {
            model: Icons.swatches
            delegate: Rectangle {
                id: sw
                required property var modelData
                readonly property string value: sr.translucent ? Icons.rowSwatch(modelData.c) : modelData.c
                readonly property bool chosen: sr.current !== "" && Qt.colorEqual(sr.current, value)
                objectName: "swatch-" + sr.field + "-" + modelData.c
                width: Theme.px(26); height: Theme.px(26); radius: 4
                color: Theme.base
                border.color: chosen ? Theme.accent : Theme.border
                border.width: chosen ? 2 : 1
                Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 2; color: sw.value }
                HoverHandler { id: swHover; cursorShape: Qt.PointingHandCursor }
                ToolTip.visible: swHover.hovered
                ToolTip.text: modelData.name
                TapHandler { onTapped: ld.set(sr.field, sw.value) }
            }
        }
        Button {
            text: qsTr("Custom…")
            height: Theme.px(26)
            onClicked: ld.chooseCustom(sr.field)
        }
    }

    ColumnLayout {
        width: Math.min(Theme.px(470), ld.parent ? ld.parent.width - 60 : Theme.px(470))
        spacing: 6

        // How the (first) item looks in the binder now.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(34)
            radius: 4
            color: Theme.binderBackground
            border.color: Theme.border
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 4
                color: ld.look.row_color || "transparent"
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 6
                KindIcon {
                    kind: ld.node ? ld.node.kind : ""
                    role: ld.node && ld.node.is_root ? (ld.node.role || "") : ""
                    icon: ld.look.icon || ""
                    tint: ld.look.icon_color || ""
                }
                Label {
                    Layout.fillWidth: true
                    text: ld.node ? ld.node.title : ""
                    color: ld.look.text_color || Theme.binderText
                    elide: Text.ElideRight
                }
                Label {
                    visible: ld.ids.length > 1
                    text: qsTr("and %1 more").arg(ld.ids.length - 1)
                    color: Theme.binderSubtext
                }
            }
        }

        Heading { text: qsTr("Icon") }
        Flow {
            Layout.fillWidth: true
            spacing: 3
            Repeater {
                id: iconRep
                model: [""].concat(Icons.choices)
                delegate: Rectangle {
                    id: cell
                    required property string modelData
                    readonly property bool chosen: (ld.look.icon || "") === modelData
                    objectName: "icon-" + (modelData || "default")
                    width: Theme.px(30); height: Theme.px(30); radius: 4
                    color: chosen ? Theme.binderSelection : (cellHover.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.15) : "transparent")
                    border.color: chosen ? Theme.accent : "transparent"
                    property alias image: cellIcon
                    KindIcon {
                        id: cellIcon
                        anchors.centerIn: parent
                        size: Theme.px(18)
                        kind: ld.node ? ld.node.kind : ""
                        role: ld.node && ld.node.is_root ? (ld.node.role || "") : ""
                        icon: cell.modelData
                        tint: ld.look.icon_color || ""
                    }
                    HoverHandler { id: cellHover; cursorShape: Qt.PointingHandCursor }
                    ToolTip.visible: cellHover.hovered
                    ToolTip.text: cell.modelData ? Icons.set[cell.modelData].name : qsTr("The usual icon for this kind of item")
                    TapHandler { onTapped: ld.set("icon", cell.modelData) }
                }
            }
        }

        Heading { text: qsTr("Icon colour") }
        SwatchRow { field: "icon_color"; defaultText: qsTr("Own colours") }

        Heading { text: qsTr("Title colour") }
        SwatchRow { field: "text_color" }

        Heading { text: qsTr("Background") }
        SwatchRow { field: "row_color"; defaultText: qsTr("None"); translucent: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.subtext
                font.pixelSize: Theme.px(12)
                text: qsTr("Changes apply at once; Edit ▸ Undo takes them back one at a time.")
            }
            Button {
                text: qsTr("Reset All")
                enabled: Object.keys(ld.look).length > 0 || ld.ids.length > 1
                onClicked: ld.resetAll()
            }
        }
    }
}
