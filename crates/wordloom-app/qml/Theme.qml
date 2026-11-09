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

    readonly property color window: dark ? "#1f2023" : "#f3f1ec"
    readonly property color panel: dark ? "#26282c" : "#ebe8e1"
    readonly property color base: dark ? "#2d2f34" : "#ffffff"
    readonly property color text: dark ? "#e6e4df" : "#24231f"
    readonly property color subtext: dark ? "#9c9a94" : "#77746c"
    readonly property color border: dark ? "#3a3c42" : "#d6d2c8"
    readonly property color accent: "#c0703a"
    readonly property color accentSoft: dark ? "#4a3626" : "#f3dfcf"
    readonly property color selection: dark ? "#3e4a5c" : "#d7e3f4"
    readonly property color danger: "#d64545"
    readonly property color ok: "#5a9e5a"
    readonly property color cork: dark ? "#3b342b" : "#c9a97c"
    readonly property color card: dark ? "#34363b" : "#fffdf5"
    readonly property color cardLine: dark ? "#43464d" : "#e6eef7"
    readonly property color paper: dark ? "#25272b" : "#fffefb"
    readonly property color ink: dark ? "#dcd9d2" : "#1d1c19"

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
    property Settings general: SavedSettings {
        category: "general"
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
