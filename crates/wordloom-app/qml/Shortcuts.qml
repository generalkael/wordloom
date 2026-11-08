pragma Singleton
import QtQuick
import QtCore

// The menu commands' keyboard shortcuts: their defaults and the ones set in
// Preferences ▸ Keyboard Shortcuts. Each menu Action reads its key with
// seq(id). Keys are portable text ("Ctrl+Shift+K"; Ctrl is ⌘ on macOS).
QtObject {
    id: sc

    // Every command, in menu order: id, menu, name, default keys, and when
    // its shortcut works: "start" (no project open), "project" (one is open)
    // or "any". Shortcuts only clash when those overlap (Ctrl+N is New
    // Project on the start screen and New Document in a project).
    readonly property var commands: [
        { id: "file.newProject", menu: qsTr("File"), name: qsTr("New Project…"), keys: "Ctrl+N", when: "start" },
        { id: "file.open", menu: qsTr("File"), name: qsTr("Open Project…"), keys: "Ctrl+O", when: "any" },
        { id: "file.save", menu: qsTr("File"), name: qsTr("Save"), keys: "Ctrl+S", when: "any" },
        { id: "file.saveAs", menu: qsTr("File"), name: qsTr("Save As…"), keys: "", when: "any" },
        { id: "file.backup", menu: qsTr("File"), name: qsTr("Back Up to Zip…"), keys: "", when: "any" },
        { id: "file.restore", menu: qsTr("File"), name: qsTr("Restore from Zip Backup…"), keys: "", when: "any" },
        { id: "file.importManuscript", menu: qsTr("File"), name: qsTr("Import Manuscript…"), keys: "", when: "any" },
        { id: "file.importFile", menu: qsTr("File"), name: qsTr("Import File…"), keys: "Ctrl+Shift+I", when: "any" },
        { id: "file.cleanUp", menu: qsTr("File"), name: qsTr("Clean Up Unused Files…"), keys: "", when: "any" },
        { id: "file.snapshot", menu: qsTr("File"), name: qsTr("Take Snapshot"), keys: "Ctrl+5", when: "any" },
        { id: "file.compile", menu: qsTr("File"), name: qsTr("Compile / Export…"), keys: "Ctrl+Shift+E", when: "any" },
        { id: "file.bible", menu: qsTr("File"), name: qsTr("Export Story Bible…"), keys: "", when: "any" },
        { id: "file.projectSettings", menu: qsTr("File"), name: qsTr("Project Settings…"), keys: "", when: "any" },
        { id: "file.close", menu: qsTr("File"), name: qsTr("Close Project"), keys: "", when: "any" },
        { id: "file.quit", menu: qsTr("File"), name: qsTr("Quit"), keys: "Ctrl+Q", when: "any" },
        { id: "edit.undo", menu: qsTr("Edit"), name: qsTr("Undo"), keys: "Ctrl+Z", when: "any" },
        { id: "edit.redo", menu: qsTr("Edit"), name: qsTr("Redo"), keys: "Ctrl+Shift+Z", when: "any" },
        { id: "edit.find", menu: qsTr("Edit"), name: qsTr("Find in Document…"), keys: "Ctrl+F", when: "any" },
        { id: "edit.replace", menu: qsTr("Edit"), name: qsTr("Replace in Document…"), keys: "Ctrl+H", when: "any" },
        { id: "edit.findProject", menu: qsTr("Edit"), name: qsTr("Find in Project"), keys: "Ctrl+Shift+F", when: "any" },
        { id: "edit.replaceProject", menu: qsTr("Edit"), name: qsTr("Replace in Project…"), keys: "", when: "any" },
        { id: "edit.smarten", menu: qsTr("Edit"), name: qsTr("Convert to Smart Punctuation"), keys: "", when: "any" },
        { id: "edit.body", menu: qsTr("Edit"), name: qsTr("Paragraph Style: Body Text"), keys: "Ctrl+Alt+0", when: "any" },
        { id: "edit.h1", menu: qsTr("Edit"), name: qsTr("Paragraph Style: Heading 1"), keys: "Ctrl+Alt+1", when: "any" },
        { id: "edit.h2", menu: qsTr("Edit"), name: qsTr("Paragraph Style: Heading 2"), keys: "Ctrl+Alt+2", when: "any" },
        { id: "edit.h3", menu: qsTr("Edit"), name: qsTr("Paragraph Style: Heading 3"), keys: "Ctrl+Alt+3", when: "any" },
        { id: "edit.quote", menu: qsTr("Edit"), name: qsTr("Paragraph Style: Block Quote"), keys: "Ctrl+Alt+Q", when: "any" },
        { id: "edit.comment", menu: qsTr("Edit"), name: qsTr("Insert Comment"), keys: "Ctrl+Alt+M", when: "any" },
        { id: "edit.footnote", menu: qsTr("Edit"), name: qsTr("Insert Footnote"), keys: "Ctrl+Alt+F", when: "any" },
        { id: "edit.preferences", menu: qsTr("Edit"), name: qsTr("Preferences…"), keys: "Ctrl+,", when: "any" },
        { id: "project.newDocument", menu: qsTr("Project"), name: qsTr("New Document"), keys: "Ctrl+N", when: "project" },
        { id: "project.newFolder", menu: qsTr("Project"), name: qsTr("New Folder"), keys: "Ctrl+Shift+N", when: "any" },
        { id: "project.newCharacter", menu: qsTr("Project"), name: qsTr("New Character"), keys: "", when: "any" },
        { id: "project.newPlace", menu: qsTr("Project"), name: qsTr("New Place"), keys: "", when: "any" },
        { id: "project.names", menu: qsTr("Project"), name: qsTr("Name Generator…"), keys: "Ctrl+Shift+G", when: "any" },
        { id: "project.duplicate", menu: qsTr("Project"), name: qsTr("Duplicate"), keys: "Ctrl+D", when: "any" },
        { id: "project.split", menu: qsTr("Project"), name: qsTr("Split at Cursor"), keys: "Ctrl+K", when: "any" },
        { id: "project.merge", menu: qsTr("Project"), name: qsTr("Merge with Next"), keys: "Ctrl+Shift+M", when: "any" },
        { id: "project.favourite", menu: qsTr("Project"), name: qsTr("Add to / Remove from Favourites"), keys: "Ctrl+Shift+D", when: "any" },
        { id: "project.trash", menu: qsTr("Project"), name: qsTr("Move to Trash"), keys: "", when: "any" },
        { id: "project.emptyTrash", menu: qsTr("Project"), name: qsTr("Empty Trash"), keys: "", when: "any" },
        { id: "project.goTo", menu: qsTr("Project"), name: qsTr("Go to…"), keys: "Ctrl+P", when: "any" },
        { id: "project.stats", menu: qsTr("Project"), name: qsTr("Writing Statistics…"), keys: "Ctrl+Shift+T", when: "any" },
        { id: "project.history", menu: qsTr("Project"), name: qsTr("Word Count History…"), keys: "Ctrl+Shift+H", when: "any" },
        { id: "project.analysis", menu: qsTr("Project"), name: qsTr("Text Analysis…"), keys: "Ctrl+Shift+A", when: "any" },
        { id: "project.grid", menu: qsTr("Project"), name: qsTr("Character Grid…"), keys: "", when: "any" },
        { id: "project.sprint", menu: qsTr("Project"), name: qsTr("Writing Sprint…"), keys: "Ctrl+Shift+R", when: "any" },
        { id: "view.editor", menu: qsTr("View"), name: qsTr("Editor"), keys: "Ctrl+1", when: "any" },
        { id: "view.corkboard", menu: qsTr("View"), name: qsTr("Corkboard"), keys: "Ctrl+2", when: "any" },
        { id: "view.outliner", menu: qsTr("View"), name: qsTr("Outliner"), keys: "Ctrl+3", when: "any" },
        { id: "view.timeline", menu: qsTr("View"), name: qsTr("Timeline (Gantt)"), keys: "Ctrl+4", when: "any" },
        { id: "view.relations", menu: qsTr("View"), name: qsTr("Relationship Map"), keys: "Ctrl+6", when: "any" },
        { id: "view.reader", menu: qsTr("View"), name: qsTr("Reading Mode"), keys: "Ctrl+7", when: "any" },
        { id: "view.back", menu: qsTr("View"), name: qsTr("Go Back"), keys: "Alt+Left", when: "any" },
        { id: "view.forward", menu: qsTr("View"), name: qsTr("Go Forward"), keys: "Alt+Right", when: "any" },
        { id: "view.split", menu: qsTr("View"), name: qsTr("Split Editor"), keys: "Ctrl+\\", when: "any" },
        { id: "view.focus", menu: qsTr("View"), name: qsTr("Focus Mode"), keys: "F11", when: "any" },
        { id: "view.binder", menu: qsTr("View"), name: qsTr("Show Binder"), keys: "", when: "any" },
        { id: "view.details", menu: qsTr("View"), name: qsTr("Show Details"), keys: "Ctrl+Alt+I", when: "any" },
        { id: "view.repeats", menu: qsTr("View"), name: qsTr("Highlight Repeated Words"), keys: "", when: "any" },
        { id: "view.lineHighlight", menu: qsTr("View"), name: qsTr("Highlight Current Line"), keys: "", when: "any" },
        { id: "view.spelling", menu: qsTr("View"), name: qsTr("Check Spelling"), keys: "F7", when: "any" },
        { id: "view.styled", menu: qsTr("View"), name: qsTr("Styled Markdown"), keys: "", when: "any" },
        { id: "view.fonts", menu: qsTr("View"), name: qsTr("Editor Font & Spacing…"), keys: "", when: "any" },
        { id: "view.zoomIn", menu: qsTr("View"), name: qsTr("Zoom In"), keys: "Ctrl++", when: "any" },
        { id: "view.zoomOut", menu: qsTr("View"), name: qsTr("Zoom Out"), keys: "Ctrl+-", when: "any" },
        { id: "view.actualSize", menu: qsTr("View"), name: qsTr("Actual Size"), keys: "Ctrl+0", when: "any" },
        { id: "help.about", menu: qsTr("Help"), name: qsTr("About Wordloom"), keys: "", when: "any" }
    ]

    // Changed shortcuts, {id: keys}; "" means none. Saved as JSON.
    property string customJson: "{}"
    readonly property var custom: { try { return JSON.parse(customJson) || {}; } catch (e) { return {}; } }
    property Settings saved: Settings {
        category: "shortcuts"
        property alias custom: sc.customJson
    }

    function command(id) { return commands.find(c => c.id === id) || null; }
    // The keys for command `id` now.
    function seq(id) {
        if (Object.prototype.hasOwnProperty.call(custom, id)) return custom[id];
        const c = command(id);
        return c ? c.keys : "";
    }
    function isCustom(id) { return Object.prototype.hasOwnProperty.call(custom, id) && custom[id] !== (command(id) || {}).keys; }
    function overlap(a, b) { return a === "any" || b === "any" || a === b; }
    // Another command that `keys` would clash with, or null.
    function clash(id, keys) {
        if (!keys) return null;
        const me = command(id);
        const k = keys.toLowerCase();
        return commands.find(c => c.id !== id && seq(c.id).toLowerCase() === k && overlap(c.when, me.when)) || null;
    }
    function store(map) { customJson = JSON.stringify(map); }
    // Give command `id` the keys (portable text, "" for none). A command
    // already using them loses them; returns that command (or null).
    function assign(id, keys) {
        const me = command(id);
        if (!me) return null;
        const taken = clash(id, keys);
        const map = Object.assign({}, custom);
        if (taken) map[taken.id] = "";
        if (keys === me.keys) delete map[id]; else map[id] = keys;
        store(map);
        return taken;
    }
    // Back to the default keys (taking them from anything that has them now).
    function reset(id) { const c = command(id); return c ? assign(id, c.keys) : null; }
    function resetAll() { store({}); }
}
