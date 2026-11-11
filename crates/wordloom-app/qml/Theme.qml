pragma Singleton
import QtQuick
import QtCore

// Colours and metrics shared by every view. Follows the system light/dark
// scheme; the user can force one with `forced`.
QtObject {
    id: theme

    property string forced: ""   // "", "light" or "dark"
    readonly property bool dark: forced === "dark"
        || (forced === "" && Qt.styleHints.colorScheme === Qt.ColorScheme.Dark)

    // Colours you've chosen (Preferences ▸ Colours), kept separately for
    // the light and dark themes: JSON {"light": {role: "#rrggbb"}, "dark": {…}}.
    // A role you haven't set follows its default below.
    property string colourOverrides: "{}"
    readonly property var allCustom: {
        try { const o = JSON.parse(colourOverrides); return o && typeof o === "object" ? o : {}; }
        catch (e) { return {}; }
    }
    readonly property string scheme: dark ? "dark" : "light"
    readonly property var custom: allCustom[scheme] || {}
    function pick(role, fallback) {
        const c = custom[role];
        return typeof c === "string" && /^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(c) ? c : fallback;
    }
    function isCustom(role) { return pick(role, "") !== ""; }
    // Set (or, with an empty colour, reset) a role in the current theme.
    function setColour(role, c) {
        const all = JSON.parse(JSON.stringify(allCustom));
        const mine = all[scheme] || {};
        if (c === "" || c === undefined || c === null) delete mine[role];
        else mine[role] = String(c);
        if (Object.keys(mine).length) all[scheme] = mine; else delete all[scheme];
        colourOverrides = JSON.stringify(all);
    }
    function resetColours(roles) {
        if (!roles) { setColourMap({}); return; }
        const mine = Object.assign({}, custom);
        for (const r of roles) delete mine[r];
        setColourMap(mine);
    }
    function setColourMap(mine) {
        const all = JSON.parse(JSON.stringify(allCustom));
        if (Object.keys(mine).length) all[scheme] = mine; else delete all[scheme];
        colourOverrides = JSON.stringify(all);
    }

    // The interface as a whole: every view and dialog.
    readonly property color window: pick("window", dark ? "#1f2023" : "#f3f1ec")
    readonly property color panel: pick("panel", dark ? "#26282c" : "#ebe8e1")
    readonly property color base: pick("base", dark ? "#2d2f34" : "#ffffff")
    readonly property color text: pick("text", dark ? "#e6e4df" : "#24231f")
    readonly property color subtext: pick("subtext", dark ? "#9c9a94" : "#77746c")
    readonly property color border: pick("border", dark ? "#3a3c42" : "#d6d2c8")
    readonly property color accent: pick("accent", "#c0703a")
    readonly property color accentSoft: dark ? "#4a3626" : "#f3dfcf"
    readonly property color selection: pick("selection", dark ? "#3e4a5c" : "#d7e3f4")
    readonly property color danger: "#d64545"
    readonly property color ok: "#5a9e5a"
    // The editor's page (also the reader and Compare).
    readonly property color paper: pick("paper", dark ? "#25272b" : "#fffefb")
    readonly property color ink: pick("ink", dark ? "#dcd9d2" : "#1d1c19")
    readonly property color editorBackground: pick("editorBackground", window)
    readonly property color editorSelection: pick("editorSelection", selection)
    readonly property color editorSelectedText: pick("editorSelectedText", ink)
    // Corkboards and index cards.
    readonly property color cork: pick("cork", dark ? "#3b342b" : "#c9a97c")
    readonly property color card: pick("card", dark ? "#34363b" : "#fffdf5")
    readonly property color cardLine: pick("cardLine", dark ? "#43464d" : "#e6eef7")
    readonly property color cardText: pick("cardText", ink)
    readonly property color cardSubtext: pick("cardSubtext", subtext)
    // The binder.
    readonly property color binderBackground: pick("binderBackground", panel)
    readonly property color binderText: pick("binderText", text)
    readonly property color binderSubtext: pick("binderSubtext", subtext)
    readonly property color binderSelection: pick("binderSelection", selection)
    // The Details panel.
    readonly property color detailsBackground: pick("detailsBackground", panel)
    readonly property color detailsText: pick("detailsText", text)
    readonly property color detailsSubtext: pick("detailsSubtext", subtext)
    readonly property color detailsField: pick("detailsField", card)
    readonly property color detailsFieldText: pick("detailsFieldText", ink)
    // The outliner.
    readonly property color outlinerBackground: pick("outlinerBackground", base)
    readonly property color outlinerAlternate: pick("outlinerAlternate", panel)
    readonly property color outlinerText: pick("outlinerText", text)
    readonly property color outlinerSubtext: pick("outlinerSubtext", subtext)

    // What Preferences ▸ Colours lists, area by area.
    readonly property var colourAreas: [
        { name: qsTr("Interface"), note: qsTr("Menus, panels, dialogs and every view; the areas below start from these."), roles: [
            { role: "window", name: qsTr("Window background") },
            { role: "panel", name: qsTr("Panels and toolbars") },
            { role: "base", name: qsTr("Fields and lists") },
            { role: "text", name: qsTr("Text") },
            { role: "subtext", name: qsTr("Secondary text") },
            { role: "border", name: qsTr("Borders") },
            { role: "accent", name: qsTr("Accent and highlights") },
            { role: "selection", name: qsTr("Selection") } ] },
        { name: qsTr("Binder"), roles: [
            { role: "binderBackground", name: qsTr("Background") },
            { role: "binderText", name: qsTr("Titles") },
            { role: "binderSubtext", name: qsTr("Word counts and headings") },
            { role: "binderSelection", name: qsTr("Selected item") } ] },
        { name: qsTr("Details"), roles: [
            { role: "detailsBackground", name: qsTr("Background") },
            { role: "detailsText", name: qsTr("Text") },
            { role: "detailsSubtext", name: qsTr("Field names") },
            { role: "detailsField", name: qsTr("Synopsis and notes background") },
            { role: "detailsFieldText", name: qsTr("Synopsis and notes text") } ] },
        { name: qsTr("Editor"), roles: [
            { role: "editorBackground", name: qsTr("Around the page") },
            { role: "paper", name: qsTr("Page") },
            { role: "ink", name: qsTr("Text") },
            { role: "editorSelection", name: qsTr("Selection") },
            { role: "editorSelectedText", name: qsTr("Selected text") } ] },
        { name: qsTr("Corkboard"), note: qsTr("A board's own colour, set from its bar, takes the place of the board colour."), roles: [
            { role: "cork", name: qsTr("Board") },
            { role: "card", name: qsTr("Index cards") },
            { role: "cardText", name: qsTr("Card text") },
            { role: "cardSubtext", name: qsTr("Card details") },
            { role: "cardLine", name: qsTr("Ruled lines") } ] },
        { name: qsTr("Outliner"), roles: [
            { role: "outlinerBackground", name: qsTr("Background") },
            { role: "outlinerAlternate", name: qsTr("Header and alternate rows") },
            { role: "outlinerText", name: qsTr("Text") },
            { role: "outlinerSubtext", name: qsTr("Secondary text") } ] }
    ]

    // The interface font (Preferences ▸ Interface): menus, panels, dialogs,
    // the binder, cards and lists. "" and 0 follow the system. The editor
    // has its own font, below.
    property string uiFont: ""
    property real uiFontSize: 0          // points
    readonly property font systemFont: Qt.application.font   // never set, so it stays the system's
    readonly property real systemPointSize: systemFont.pointSize > 0 ? systemFont.pointSize : Math.max(6, systemFont.pixelSize * 0.75)
    readonly property real uiPointSize: uiFontSize > 0 ? uiFontSize : systemPointSize
    // How much bigger than the system's the interface text is; sizes in the
    // QML were chosen for the system font, so they scale by this.
    readonly property real uiTextScale: uiPointSize / systemPointSize
    // A size in pixels designed for the system font, at the chosen size.
    function px(n) { return Math.max(1, Math.round(n * uiTextScale)); }
    function resetUiFont() { uiFont = ""; uiFontSize = 0; }

    // The writing font (View ▸ Editor Font & Spacing…). If it isn't
    // installed, Qt substitutes a similar one.
    property string editorFont: "Georgia"
    readonly property string defaultEditorFont: "Georgia"
    property int editorSize: 15
    // Text column width in pixels; 0 = fit the editor pane (the default).
    property int pageWidth: 0
    // Line spacing, as a multiple of single spacing (editor and preview).
    property real lineHeight: 1.45
    // First-line indent of body paragraphs in ems (0 = none), and the height
    // of the blank lines between paragraphs as a fraction of a line.
    property real firstLineIndent: 0
    property real blankLineHeight: 1.0
    // Editor zoom (Ctrl+= / Ctrl+− / Ctrl+0, Ctrl+wheel): scales the text
    // and a fixed page width without changing the font size itself.
    property real editorZoom: 1.0
    readonly property var zoomSteps: [0.5, 0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    readonly property real minZoom: 0.5
    readonly property real maxZoom: 3.0
    // What the editor actually draws at.
    readonly property int editorPixelSize: Math.max(6, Math.round(editorSize * editorZoom))
    function setZoom(z) { editorZoom = Math.round(Math.max(minZoom, Math.min(maxZoom, z)) * 100) / 100; }
    // The next step up or down from the current zoom.
    function zoomIn() { const z = zoomSteps.find(s => s > editorZoom + 0.001); setZoom(z === undefined ? maxZoom : z); }
    function zoomOut() { const z = zoomSteps.slice().reverse().find(s => s < editorZoom - 0.001); setZoom(z === undefined ? minZoom : z); }
    function resetZoom() { editorZoom = 1.0; }
    readonly property string zoomText: Math.round(editorZoom * 100) + "%"
    // Corkboard card width (the Card size slider, Ctrl+scroll on a board).
    property int cardWidth: 230
    // Freeform corkboards: drop cards and notes on a 20-unit grid.
    property bool boardSnap: false
    // Show Markdown styling (bold, headings, quotes…) while editing.
    property bool styledMarkdown: true
    // Underline misspelled words in the editor.
    property bool spellCheck: true
    property string spellLanguage: ""   // a Hunspell code such as "en_GB"; "" follows the system
    // “Smart” quotes, dashes and ellipses as you type (EditorView.smartKey).
    property bool smartPunctuation: true
    // Suggest character and place names as you type (EditorView).
    property bool completeNames: true
    // A bar behind the line being edited (EditorView), in a colour of your
    // choice; translucent by default so it suits light and dark themes.
    property bool lineHighlight: false
    property bool highlightRepeats: false   // tint words repeated nearby (repeats.rs)
    property color lineHighlightColor: "#40f2c14e"

    // Preferences ▸ General: reopen the last project at startup, how often
    // to autosave, and where New Project suggests creating projects
    // ("" = Documents/Wordloom).
    property bool reopenLast: false
    property int autosaveSeconds: 15
    property string projectsFolder: ""
    readonly property string defaultProjectsFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation).toString() + "/Wordloom"
    readonly property string newProjectsFolder: projectsFolder || defaultProjectsFolder
    // "General", capitalised: Qt's .ini files keep this group as
    // [%General] and read it back only under that spelling, so "general"
    // was saved but never loaded.
    property Settings general: SavedSettings {
        category: "General"
        property alias reopenLast: theme.reopenLast
        property alias autosaveSeconds: theme.autosaveSeconds
        property alias projectsFolder: theme.projectsFolder
    }

    // Remembered between runs (~/.config/Wordloom/Wordloom.conf on Linux).
    property Settings prefs: SavedSettings {
        category: "appearance"
        property alias theme: theme.forced
        property alias uiFont: theme.uiFont
        property alias uiFontSize: theme.uiFontSize
        property alias editorFont: theme.editorFont
        property alias editorSize: theme.editorSize
        property alias pageWidth: theme.pageWidth
        property alias lineHeight: theme.lineHeight
        property alias firstLineIndent: theme.firstLineIndent
        property alias blankLineHeight: theme.blankLineHeight
        property alias editorZoom: theme.editorZoom
        property alias cardWidth: theme.cardWidth
        property alias boardSnap: theme.boardSnap
        property alias styledMarkdown: theme.styledMarkdown
        property alias spellCheck: theme.spellCheck
        property alias spellLanguage: theme.spellLanguage
        property alias smartPunctuation: theme.smartPunctuation
        property alias completeNames: theme.completeNames
        property alias lineHighlight: theme.lineHighlight
        property alias highlightRepeats: theme.highlightRepeats
        property alias lineHighlightColor: theme.lineHighlightColor
        property alias colourOverrides: theme.colourOverrides
    }

    readonly property int gap: 8
    readonly property int radius: 5

    // URL of the bundled SVG icon for an item kind or section root (see
    // KindIcon). Timeline track kinds (plotline, …) work too.
    function kindIcon(kind, role) {
        const roles = ["manuscript", "characters", "places", "research", "notes", "trash"];
        const kinds = { folder: "folder", character: "character", place: "place", research: "attachment", note: "note", plotline: "plotline" };
        const name = roles.indexOf(role) >= 0 ? role : (kinds[kind] || "text");
        return Qt.resolvedUrl("icons/" + name + ".svg");
    }
}
