import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import com.wordloom.app

// Edit ▸ Preferences… (Ctrl+,): every app-wide setting in one place, on
// pages listed down the left. Changes apply at once and are remembered
// (Theme.qml keeps most of them). Project-specific settings stay in
// File ▸ Project Settings…
Dialog {
    id: pd
    title: qsTr("Preferences")
    modal: false
    standardButtons: Dialog.Close

    property var win                      // Main.qml's window (setSpellLanguage)
    property var autoBackup               // Main.qml's automatic backups

    readonly property var pages: [
        { id: "general", name: qsTr("General") },
        { id: "font", name: qsTr("Font & Spacing") },
        { id: "editor", name: qsTr("Editor") },
        { id: "writing", name: qsTr("Spelling & Typing") },
        { id: "corkboard", name: qsTr("Corkboard") },
        { id: "backups", name: qsTr("Backups") },
        { id: "shortcuts", name: qsTr("Keyboard Shortcuts") }
    ]
    property string page: "general"
    // Open on one page ("font" from the editor's Aa button, …).
    function openAt(id) {
        if (id && pages.some(p => p.id === id)) page = id;
        open();
    }
    function pageIndex() { return Math.max(0, pages.findIndex(p => p.id === page)); }

    onAboutToShow: {
        fontFilter = "";
        familyList.positionViewAtIndex(Math.max(0, families.indexOf(Theme.editorFont)), ListView.Center);
        spellInfo = Api.call("spellLanguages") || spellInfo;
        scaleInfo = Api.call("uiScale") || scaleInfo;
        loadWords();
    }

    // ---- General ----
    readonly property var autosaves: [
        { v: 5, name: qsTr("Every 5 seconds") }, { v: 15, name: qsTr("Every 15 seconds (default)") },
        { v: 30, name: qsTr("Every 30 seconds") }, { v: 60, name: qsTr("Every minute") },
        { v: 300, name: qsTr("Every 5 minutes") }
    ]
    // Interface size: saved for the next start (uiscale.rs).
    readonly property var scales: [0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0]
    property var scaleInfo: ({ saved: 1, running: 1 })
    function setScale(f) {
        const r = Api.call("setUiScale", f);
        if (r !== undefined) scaleInfo = { saved: r, running: scaleInfo.running };
        return r;
    }
    function folderText(u) { return decodeURIComponent(String(u).replace(/^file:\/\//, "")); }

    // ---- Font & Spacing ----
    readonly property var allFamilies: Qt.fontFamilies()
    property string fontFilter: ""
    readonly property var families: {
        const f = fontFilter.trim().toLowerCase();
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
    readonly property var indents: [
        { v: 0, name: qsTr("None") }, { v: 1, name: qsTr("1 em") }, { v: 1.5, name: qsTr("1.5 em") },
        { v: 2, name: qsTr("2 em") }, { v: 3, name: qsTr("3 em") }
    ]
    readonly property var gaps: [
        { v: 1.0, name: qsTr("Full line") }, { v: 0.6, name: qsTr("Half line") }, { v: 0.3, name: qsTr("Narrow") }
    ]
    function indexIn(list, v) { return list.findIndex(s => Math.abs(s.v - v) < 0.01); }
    function chooseFont(name) { Theme.editorFont = name; }
    function resetFont() {
        Theme.editorFont = Theme.defaultEditorFont; Theme.editorSize = 15; Theme.lineHeight = 1.45;
        Theme.firstLineIndent = 0; Theme.blankLineHeight = 1; Theme.resetZoom();
    }

    // ---- Editor ----
    // Page width choices in pixels (0 = fit the window); the editor's page
    // button steps through the same ones.
    readonly property var widths: [
        { v: 0, name: qsTr("Fit the window") }, { v: 560, name: qsTr("Narrow (560 px)") },
        { v: 740, name: qsTr("Medium (740 px)") }, { v: 920, name: qsTr("Wide (920 px)") },
        { v: 1100, name: qsTr("Extra wide (1100 px)") }
    ]
    // Line highlight presets (translucent, so text stays readable in either theme).
    readonly property var lineColours: [
        { name: qsTr("Amber"), c: "#40f2c14e" }, { name: qsTr("Blue"), c: "#3d5b9bd5" },
        { name: qsTr("Green"), c: "#3d6abf69" }, { name: qsTr("Rose"), c: "#3de57399" },
        { name: qsTr("Grey"), c: "#30808080" }
    ]
    function setLineColour(c) { Theme.lineHighlightColor = c; Theme.lineHighlight = true; }

    // ---- Spelling & Typing ----
    property var spellInfo: ({ chosen: "", system: "", systemName: "", list: [] })
    // Words added with *Add to Dictionary*, shared by every language.
    property var words: []
    property string wordFilter: ""
    readonly property var shownWords: {
        const f = wordFilter.trim().toLowerCase();
        return f ? words.filter(w => w.toLowerCase().indexOf(f) >= 0) : words;
    }
    function loadWords() { words = Api.call("spellWords") || []; }
    function addWord(w) {
        w = w.trim();
        if (!w || /\s/.test(w)) return false;
        Api.call("spellAdd", w);
        loadWords();
        Api.spellingChanged();
        return true;
    }
    function removeWord(w) {
        const r = Api.call("spellRemove", w);
        loadWords();
        Api.spellingChanged();
        return r === true;
    }

    ColorDialog {
        id: colourDialog
        title: qsTr("Line Highlight Colour")
        options: ColorDialog.ShowAlphaChannel
        onAccepted: pd.setLineColour(selectedColor)
    }
    FolderDialog {
        id: projectsFolderDialog
        title: qsTr("Suggest creating new projects in…")
        currentFolder: Theme.newProjectsFolder
        onAccepted: Theme.projectsFolder = selectedFolder.toString()
    }
    FolderDialog {
        id: backupFolderDialog
        title: qsTr("Keep automatic backups in…")
        currentFolder: pd.autoBackup ? pd.autoBackup.where : ""
        onAccepted: pd.autoBackup.folder = selectedFolder.toString()
    }

    component Heading: Label { font.bold: true; color: Theme.text; Layout.topMargin: 4 }
    component Note: Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.subtext; font.pixelSize: 12 }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // Page list
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 160
            color: Theme.panel
            border.color: Theme.border
            radius: 3
            ListView {
                id: pageList
                anchors.fill: parent
                anchors.margins: 4
                model: pd.pages
                currentIndex: pd.pageIndex()
                delegate: ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.name.replace("&", "&&")   // not a mnemonic
                    highlighted: pd.page === modelData.id
                    onClicked: pd.page = modelData.id
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: pd.pageIndex()

            // ---------------- General ----------------
            ScrollView {
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    Heading { text: qsTr("Appearance") }
                    ComboBox {
                        id: themeBox
                        Layout.preferredWidth: 220
                        model: [qsTr("Follow the system"), qsTr("Light"), qsTr("Dark")]
                        currentIndex: ["", "light", "dark"].indexOf(Theme.forced)
                        onActivated: (i) => Theme.forced = ["", "light", "dark"][i]
                    }
                    RowLayout {
                        Label { text: qsTr("Interface size"); color: Theme.text }
                        ComboBox {
                            id: scaleBox
                            Layout.preferredWidth: 150
                            model: pd.scales.map(f => f === 1 ? qsTr("100% (default)") : Math.round(f * 100) + "%")
                            currentIndex: pd.scales.findIndex(f => Math.abs(f - pd.scaleInfo.saved) < 0.001)
                            displayText: currentIndex >= 0 ? currentText : Math.round(pd.scaleInfo.saved * 100) + "%"
                            onActivated: (i) => pd.setScale(pd.scales[i])
                        }
                    }
                    Note {
                        text: Math.abs(pd.scaleInfo.saved - pd.scaleInfo.running) > 0.001
                            ? qsTr("Wordloom will use %1 the next time it starts (now %2).").arg(Math.round(pd.scaleInfo.saved * 100) + "%").arg(Math.round(pd.scaleInfo.running * 100) + "%")
                            : qsTr("Scales menus, panels, dialogs and the editor together. Changes take effect the next time Wordloom starts.")
                    }
                    Heading { text: qsTr("Starting up") }
                    CheckBox {
                        text: qsTr("Reopen the last project when Wordloom starts")
                        checked: Theme.reopenLast
                        onToggled: Theme.reopenLast = checked
                    }
                    Heading { text: qsTr("Saving") }
                    RowLayout {
                        Label { text: qsTr("Save changes"); color: Theme.text }
                        ComboBox {
                            id: autosaveBox
                            Layout.preferredWidth: 230
                            model: pd.autosaves.map(s => s.name)
                            currentIndex: pd.indexIn(pd.autosaves, Theme.autosaveSeconds)
                            onActivated: (i) => Theme.autosaveSeconds = pd.autosaves[i].v
                        }
                    }
                    Note { text: qsTr("Wordloom also saves when you close a project or quit, and Ctrl+S saves at once.") }
                    Heading { text: qsTr("New projects") }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: qsTr("Create in"); color: Theme.text }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            text: pd.folderText(Theme.newProjectsFolder)
                            color: Theme.subtext
                        }
                        Button { text: qsTr("Choose…"); onClicked: projectsFolderDialog.open() }
                        Button { text: qsTr("Reset"); enabled: Theme.projectsFolder !== ""; onClicked: Theme.projectsFolder = "" }
                    }
                    Note { text: qsTr("The folder New Project suggests. Each project is a folder of its own inside it.") }
                }
            }

            // ---------------- Font & Spacing ----------------
            ScrollView {
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 240
                            spacing: 4
                            Heading { text: qsTr("Font") }
                            TextField {
                                Layout.fillWidth: true
                                placeholderText: qsTr("Search fonts")
                                selectByMouse: true
                                text: pd.fontFilter
                                onTextEdited: pd.fontFilter = text
                                Keys.onReturnPressed: if (pd.families.length) pd.chooseFont(pd.families[0])
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 4
                                visible: pd.suggested.length > 0 && pd.fontFilter === ""
                                Repeater {
                                    model: pd.suggested.slice(0, 6)
                                    delegate: Button {
                                        required property string modelData
                                        text: modelData
                                        font.family: modelData
                                        flat: Theme.editorFont !== modelData
                                        highlighted: Theme.editorFont === modelData
                                        onClicked: pd.chooseFont(modelData)
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 180
                                color: Theme.base
                                border.color: Theme.border
                                radius: 3
                                ListView {
                                    id: familyList
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    clip: true
                                    model: pd.families
                                    ScrollBar.vertical: ScrollBar {}
                                    delegate: ItemDelegate {
                                        required property string modelData
                                        width: ListView.view.width
                                        height: 28
                                        clip: true   // some display fonts draw far outside their line
                                        highlighted: modelData === Theme.editorFont
                                        contentItem: Label { text: modelData; font.family: modelData; font.pixelSize: 14; elide: Text.ElideRight; color: Theme.text; verticalAlignment: Text.AlignVCenter }
                                        onClicked: pd.chooseFont(modelData)
                                    }
                                }
                                Label { anchors.centerIn: parent; visible: pd.families.length === 0; text: qsTr("No fonts match"); color: Theme.subtext }
                            }
                            Note {
                                visible: !pd.installed
                                text: qsTr("“%1” isn't installed, so a similar font is used.").arg(Theme.editorFont)
                            }
                        }
                        GridLayout {
                            Layout.alignment: Qt.AlignTop
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 8
                            Label { text: qsTr("Size"); color: Theme.text }
                            SpinBox {
                                from: 9; to: 40
                                value: Theme.editorSize
                                editable: true
                                onValueModified: Theme.editorSize = value
                            }
                            Label { text: qsTr("Line spacing"); color: Theme.text }
                            ComboBox {
                                Layout.preferredWidth: 150
                                model: pd.spacings.map(s => s.name)
                                currentIndex: pd.indexIn(pd.spacings, Theme.lineHeight)
                                displayText: currentIndex >= 0 ? currentText : Theme.lineHeight.toFixed(2)
                                onActivated: (i) => Theme.lineHeight = pd.spacings[i].v
                            }
                            Label { text: qsTr("First-line indent"); color: Theme.text }
                            ComboBox {
                                Layout.preferredWidth: 150
                                model: pd.indents.map(s => s.name)
                                currentIndex: pd.indexIn(pd.indents, Theme.firstLineIndent)
                                displayText: currentIndex >= 0 ? currentText : Theme.firstLineIndent + " em"
                                onActivated: (i) => Theme.firstLineIndent = pd.indents[i].v
                                ToolTip.visible: hovered
                                ToolTip.delay: 600
                                ToolTip.text: qsTr("Indents body paragraphs, except the first after a heading or scene break")
                            }
                            Label { text: qsTr("Blank lines"); color: Theme.text }
                            ComboBox {
                                Layout.preferredWidth: 150
                                model: pd.gaps.map(s => s.name)
                                currentIndex: pd.indexIn(pd.gaps, Theme.blankLineHeight)
                                displayText: currentIndex >= 0 ? currentText : Math.round(Theme.blankLineHeight * 100) + "%"
                                onActivated: (i) => Theme.blankLineHeight = pd.gaps[i].v
                                ToolTip.visible: hovered
                                ToolTip.delay: 600
                                ToolTip.text: qsTr("How tall the blank lines between paragraphs look (the file is unchanged)")
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
                                onClicked: pd.resetFont()
                            }
                        }
                    }

                    // A sample in the chosen font, size and spacing (at 100% zoom).
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        color: Theme.paper
                        border.color: Theme.border
                        radius: 3
                        clip: true
                        Text {
                            anchors.fill: parent
                            anchors.margins: 14
                            wrapMode: Text.Wrap
                            font.family: Theme.editorFont
                            font.pixelSize: Theme.editorSize
                            lineHeight: Theme.lineHeight
                            color: Theme.ink
                            textFormat: Text.RichText
                            // Two paragraphs, to show the indent and the blank line between.
                            readonly property int gap: Math.round(Theme.editorSize * 1.2 * Theme.lineHeight * Theme.blankLineHeight)
                            readonly property int indent: Math.round(Theme.firstLineIndent * Theme.editorSize)
                            text: "<p style='margin:0'>" + qsTr("<b>The storm came in at dusk.</b> Elias climbed the hundred and twelve steps, counting each one, as his father had.")
                                + "</p><p style='margin:0; margin-top:" + gap + "px; text-indent:" + indent + "px'>"
                                + qsTr("<i>Never trust a light you haven't checked yourself.</i> Below, the sea threw itself against the rocks.") + "</p>"
                        }
                    }
                }
            }

            // ---------------- Editor ----------------
            ScrollView {
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    Heading { text: qsTr("Page") }
                    RowLayout {
                        Label { text: qsTr("Page width"); color: Theme.text }
                        ComboBox {
                            Layout.preferredWidth: 210
                            model: pd.widths.map(s => s.name)
                            currentIndex: pd.indexIn(pd.widths, Theme.pageWidth)
                            displayText: currentIndex >= 0 ? currentText : Theme.pageWidth + " px"
                            onActivated: (i) => Theme.pageWidth = pd.widths[i].v
                        }
                    }
                    CheckBox {
                        text: qsTr("Show Markdown styling (bold, headings, quotes…) while writing")
                        checked: Theme.styledMarkdown
                        onToggled: Theme.styledMarkdown = checked
                    }
                    Heading { text: qsTr("Highlighting") }
                    CheckBox {
                        text: qsTr("Highlight the line being edited")
                        checked: Theme.lineHighlight
                        onToggled: Theme.lineHighlight = checked
                    }
                    RowLayout {
                        Layout.leftMargin: 28
                        spacing: 6
                        Label { text: qsTr("Colour"); color: Theme.text }
                        Repeater {
                            model: pd.lineColours
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool chosen: Qt.colorEqual(Theme.lineHighlightColor, modelData.c)
                                width: 22; height: 22; radius: 4
                                color: Theme.paper
                                border.color: chosen ? Theme.accent : Theme.border
                                border.width: chosen ? 2 : 1
                                Rectangle { anchors.fill: parent; anchors.margins: 3; radius: 2; color: parent.modelData.c }
                                ToolTip.visible: swatchHover.hovered
                                ToolTip.text: modelData.name
                                HoverHandler { id: swatchHover }
                                TapHandler { onTapped: pd.setLineColour(parent.modelData.c) }
                            }
                        }
                        Button {
                            text: qsTr("Custom…")
                            onClicked: { colourDialog.selectedColor = Theme.lineHighlightColor; colourDialog.open(); }
                        }
                    }
                    CheckBox {
                        text: qsTr("Highlight words repeated close together")
                        checked: Theme.highlightRepeats
                        onToggled: Theme.highlightRepeats = checked
                    }
                    Note { text: qsTr("These are also in the View menu, to switch on and off as you write.") }
                }
            }

            // ---------------- Spelling & Typing ----------------
            ScrollView {
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    Heading { text: qsTr("Typing") }
                    CheckBox {
                        text: qsTr("Smart punctuation: curly quotes, dashes and ellipses as you type")
                        checked: Theme.smartPunctuation
                        onToggled: Theme.smartPunctuation = checked
                    }
                    CheckBox {
                        text: qsTr("Suggest character and place names as you type")
                        checked: Theme.completeNames
                        onToggled: Theme.completeNames = checked
                    }
                    Heading { text: qsTr("Spelling") }
                    CheckBox {
                        text: qsTr("Check spelling as you type (F7)")
                        checked: Theme.spellCheck
                        onToggled: Theme.spellCheck = checked
                    }
                    RowLayout {
                        Label { text: qsTr("Language"); color: Theme.text }
                        ComboBox {
                            id: languageBox
                            Layout.preferredWidth: 260
                            model: [pd.spellInfo.system ? qsTr("Automatic: %1").arg(pd.spellInfo.systemName) : qsTr("Automatic")]
                                .concat(pd.spellInfo.list.map(l => l.name))
                            currentIndex: Theme.spellLanguage === "" ? 0 : 1 + pd.spellInfo.list.findIndex(l => l.code === Theme.spellLanguage)
                            onActivated: (i) => pd.win.setSpellLanguage(i === 0 ? "" : pd.spellInfo.list[i - 1].code)
                        }
                    }
                    Note { text: qsTr("Wordloom uses your system's Hunspell dictionaries. To add a language, install its Hunspell package or put its .aff and .dic files in ~/.local/share/hunspell.") }
                    Heading { text: qsTr("Your dictionary") }
                    Note { text: qsTr("Words you've added with Add to Dictionary, accepted in every language. The names of your characters, places and timeline tracks are always accepted and needn't be added.") }
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: newWord
                            Layout.fillWidth: true
                            placeholderText: qsTr("Find or add a word")
                            selectByMouse: true
                            text: pd.wordFilter
                            onTextEdited: pd.wordFilter = text
                            Keys.onReturnPressed: addButton.clicked()
                        }
                        Button {
                            id: addButton
                            text: qsTr("Add")
                            enabled: pd.wordFilter.trim() !== "" && !/\s/.test(pd.wordFilter.trim()) && pd.words.indexOf(pd.wordFilter.trim()) < 0
                            onClicked: if (enabled && pd.addWord(pd.wordFilter)) pd.wordFilter = ""
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 170
                        color: Theme.base
                        border.color: Theme.border
                        radius: 3
                        ListView {
                            id: wordList
                            anchors.fill: parent
                            anchors.margins: 1
                            clip: true
                            model: pd.shownWords
                            ScrollBar.vertical: ScrollBar {}
                            delegate: ItemDelegate {
                                required property string modelData
                                width: ListView.view.width
                                height: 28
                                contentItem: RowLayout {
                                    Label { Layout.fillWidth: true; text: modelData; color: Theme.text; elide: Text.ElideRight }
                                    ToolButton {
                                        text: "×"
                                        implicitHeight: 24
                                        onClicked: pd.removeWord(modelData)
                                        ToolTip.visible: hovered
                                        ToolTip.delay: 400
                                        ToolTip.text: qsTr("Remove from your dictionary")
                                    }
                                }
                            }
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: pd.shownWords.length === 0
                            text: pd.words.length ? qsTr("No words match") : qsTr("No words added yet")
                            color: Theme.subtext
                        }
                    }
                    Note { text: pd.words.length === 1 ? qsTr("1 word") : qsTr("%1 words").arg(pd.words.length) }
                }
            }

            // ---------------- Corkboard ----------------
            ScrollView {
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    Heading { text: qsTr("Cards") }
                    RowLayout {
                        Label { text: qsTr("Card size"); color: Theme.text }
                        Slider {
                            Layout.preferredWidth: 200
                            from: 170; to: 360; stepSize: 10
                            value: Theme.cardWidth
                            onMoved: Theme.cardWidth = Math.round(value)
                        }
                        Label { text: qsTr("%1 px").arg(Theme.cardWidth); color: Theme.subtext }
                        Button { text: qsTr("Reset"); enabled: Theme.cardWidth !== 230; onClicked: Theme.cardWidth = 230 }
                    }
                    Note { text: qsTr("Ctrl+scroll on a corkboard changes it too.") }
                    Heading { text: qsTr("Freeform boards") }
                    CheckBox {
                        text: qsTr("Snap cards and notes to a grid")
                        checked: Theme.boardSnap
                        onToggled: Theme.boardSnap = checked
                    }
                    Note { text: qsTr("Board colours are set on each board, from the swatch on its bar.") }
                }
            }

            // ---------------- Backups ----------------
            ScrollView {
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    Heading { text: qsTr("Automatic backups") }
                    CheckBox {
                        text: qsTr("Back up to a zip file whenever a project is closed")
                        checked: pd.autoBackup ? pd.autoBackup.closeBackups : false
                        onToggled: pd.autoBackup.closeBackups = checked
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: qsTr("Folder"); color: Theme.text }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            text: pd.autoBackup ? pd.folderText(pd.autoBackup.where) : ""
                            color: Theme.subtext
                        }
                        Button { text: qsTr("Choose…"); onClicked: backupFolderDialog.open() }
                    }
                    RowLayout {
                        Label { text: qsTr("Keep the newest"); color: Theme.text }
                        SpinBox {
                            from: 1; to: 100; editable: true
                            value: pd.autoBackup ? pd.autoBackup.keep : 10
                            onValueModified: pd.autoBackup.keep = value
                        }
                        Label { text: qsTr("backups of each project"); color: Theme.text }
                    }
                    Button {
                        text: qsTr("Back Up Now")
                        enabled: Wordloom.projectOpen
                        onClicked: pd.autoBackup.run(false)
                    }
                    Note { text: qsTr("Backups are named like “Title autobackup 2026-11-06 1730.zip”. If nothing has changed since the last one, no new zip is made. Older automatic backups beyond the number kept are deleted; other files in the folder, including ones made with Back Up to Zip, are left alone. Choose a folder on another drive or a synced cloud folder so a backup survives losing this disk.") }
                }
            }

            // ---------------- Keyboard Shortcuts ----------------
            ShortcutsPage { id: shortcutsPage }
        }
    }
    function shortcutsRef() { return shortcutsPage; }
}
