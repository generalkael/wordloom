import QtQuick
import com.wordloom.app
import com.wordloom.styling

// `wordloom --sample=DIR --selftest`: drives the real UI through checks for
// bugs fixed in the past, prints PASS / FAIL lines and exits with status 1
// if anything failed. CI runs it on every push.
Item {
    id: st
    property var win                     // the ApplicationWindow
    property var history                 // HistoryWindow
    property var sprint                  // SprintDialog
    property var analysis                // AnalysisDialog
    property var compile                 // CompileDialog
    property string noteId: ""          // the note resized (note resize)
    property var replaceBefore: []        // texts before a project replace
    property var groupStart: null        // spots before a group drag (freeform groups)
    property var noteAdded: null         // revision and editor right after + Note (freeform corkboard)
    property var goTo                    // GoToPopup
    property var autoBackup              // Main.qml's automatic backups
    property var prefs                   // PreferencesDialog
    property var grid                    // PresenceDialog
    property int step: 0
    InputSim { id: input }
    property int failures: 0
    property int passes: 0
    property string current: ""

    function log(s) { Api.call("log", s); }
    function check(ok, what) {
        if (ok) { passes++; log("PASS  " + current + ": " + what); }
        else { failures++; log("FAIL  " + current + ": " + what); }
    }
    function rowId(title) { const r = Api.get("binder", []).find(x => x.title === title); return r ? r.id : ""; }
    function ws() { return win.ws; }
    function ed() { return win.ws.mainEditor(); }

    // Each step runs after the previous one has had time to lay out.
    readonly property var steps: [
        ["select opens editor", () => { ws().select(rowId("The Storm")); }],
        ["select opens editor", () => {
            check(ws().viewMode === "corkboard", "a folder without text opens the corkboard");
            ws().select(rowId("Arrival"));
            check(ws().viewMode === "editor", "a document clicked from the corkboard opens the editor");
            ws().viewMode = "outliner"; ws().select(rowId("The Keeper"));
            check(ws().viewMode === "editor", "a document clicked from the outliner opens the editor");
        }],
        ["page fills pane", () => {
            Theme.pageWidth = 0;
            const i = ed().testInfo();
            // Pane minus the scroll-bar gutter (14) and the page margin (24).
            check(Math.abs(i.pageW - (i.paneW - 38)) <= 1, "the page fills the pane (" + Math.round(i.pageW) + " of " + Math.round(i.paneW) + ")");
        }],
        ["caret stays visible", () => {
            const a = ed().firstArea();
            a.forceActiveFocus(); a.cursorPosition = a.length;
            for (let k = 0; k < 60; ++k) a.insert(a.cursorPosition, "\nline " + k);
        }],
        ["caret stays visible", () => {
            const i = ed().testInfo();
            check(i.contentY > 0, "the editor scrolled while typing past the bottom");
            check(i.caretY >= i.contentY && i.caretY + i.caretH <= i.contentY + i.viewH, "the caret is inside the visible area");
        }],
        ["formatting", () => {
            const a = ed().firstArea();
            a.text = "one two three";
            a.select(4, 7); ed().activeArea = a; ed().toggleEmphasis(2);
            check(a.text === "one **two** three", "Ctrl+B wraps the selection: " + JSON.stringify(a.text));
            ed().toggleEmphasis(2);
            check(a.text === "one two three", "Ctrl+B again unwraps it");
            a.cursorPosition = 2; ed().cycleHeading();
            check(a.text.startsWith("# "), "the heading button adds #");
        }],
        ["comments", () => {
            const a = ed().firstArea();
            a.text = "one two";
            a.cursorPosition = 7; ed().activeArea = a; ed().insertComment();
            a.insert(a.cursorPosition, "fix");
            check(a.text === "one two {>> fix <<}", "the comment button inserts {>> <<} with the caret inside: " + JSON.stringify(a.text));
            ed().flush();
            const id = ws().currentId;
            check(Api.get("nodeInfo", null, id).words === 2, "a comment isn't counted as words");
            const cs = Api.get("comments", [], id);
            check(cs.length === 1 && cs[0].text === "fix", "Details lists the comment");
            a.cursorPosition = 0;
            check(ed().showComment(id, 0) && a.selectedText === "{>> fix <<}", "clicking it selects the comment in the editor");
        }],
        ["repeated words", () => {
            const a = ed().firstArea();
            a.text = "The window was dark. Beyond the window, a lantern swung.";
            Theme.highlightRepeats = true;
        }],
        ["repeated words", () => {
            const a = ed().firstArea(), t = a.text;
            const tinted = (word, nth) => { let i = -1; for (let n = 0; n <= nth; n++) i = t.indexOf(word, i + 1); const c = a.tintAt(i + 1); return c.a > 0 && c.b > c.r; }; // the blue repeat tint, not spelling's red
            check(tinted("window", 0) && tinted("window", 1), "both uses of a repeated word are tinted");
            check(!tinted("lantern", 0) && !tinted("dark", 0), "words used once are not");
            Theme.highlightRepeats = false;
        }],
        ["repeated words", () => {
            const a = ed().firstArea();
            check(a.tintAt(a.text.indexOf("window") + 1).a === 0, "it can be switched off (" + a.tintAt(a.text.indexOf("window") + 1) + ")");
            a.text = "";
        }],
        ["footnotes", () => {
            const a = ed().firstArea();
            a.text = "The log lied.\n\n";
            a.forceActiveFocus(); ed().activeArea = a;
            a.cursorPosition = a.text.indexOf(".") + 1;
            ws().insertFootnote();
            check(a.text === "The log lied.[^1]\n\n[^1]: " && a.cursorPosition === a.length, "Insert Footnote adds [^1] and its note at the end (" + JSON.stringify(a.text) + ")");
            a.insert(a.length, "Pages were cut.");
            a.cursorPosition = a.text.indexOf("lied") + 4;
            ws().insertFootnote();
            check(a.text === "The log lied[^2].[^1]\n\n[^1]: Pages were cut.\n\n[^2]: ", "the next one is numbered 2 (" + JSON.stringify(a.text) + ")");
            a.text = "";
        }],
        ["line highlight", () => {
            const a = ed().firstArea();
            a.text = "First line\nSecond line\nThird line";
            Theme.lineHighlight = true;
            Theme.lineHighlightColor = "#40112233";
            a.forceActiveFocus(); ed().activeArea = a;
            a.cursorPosition = a.text.indexOf("Third");
        }],
        ["line highlight", () => {
            const a = ed().firstArea(), bar = ed().lineBarRef();
            const caretY = a.mapToItem(bar.parent, 0, a.cursorRectangle.y).y;
            check(bar.visible && Math.abs(bar.y - caretY) < 1 && bar.height === a.cursorRectangle.height,
                  "the bar sits on the caret's line (bar " + Math.round(bar.y) + ", caret " + Math.round(caretY) + ")");
            check(Qt.colorEqual(bar.color, "#40112233"), "the bar uses the chosen colour");
            a.cursorPosition = 0;
            check(Math.abs(bar.y - a.mapToItem(bar.parent, 0, a.cursorRectangle.y).y) < 1, "it follows the caret to another line");
            Theme.lineHighlight = false;
            check(!bar.visible, "it can be switched off");
            Theme.lineHighlightColor = "#40f2c14e";
            a.text = "";
        }],
        ["fonts and zoom", () => {
            const a = ed().firstArea();
            Theme.resetZoom(); Theme.lineHeight = 1.45;
            a.text = "# The Title\nA body line\n## A part";
        }],
        ["fonts and zoom", () => {
            const a = ed().firstArea(), px = Theme.editorPixelSize;
            check(Math.abs(a.lineHeightAt(0) - 1.45) < 0.01 && Math.abs(a.lineHeightAt(a.text.indexOf("body")) - 1.45) < 0.01,
                  "the editor uses the line spacing (" + a.lineHeightAt(0) + ")");
            check(a.pixelSizeAt(3) === Math.round(px * 1.6) && a.pixelSizeAt(a.text.indexOf("part")) === Math.round(px * 1.35),
                  "headings are sized from the text (" + a.pixelSizeAt(3) + ", " + a.pixelSizeAt(a.text.indexOf("part")) + " for " + px + ")");
            check(!a.canUndo, "laying out the spacing leaves nothing to undo");
            Theme.zoomIn();
            check(Theme.editorZoom === 1.1 && a.font.pixelSize === Math.round(Theme.editorSize * 1.1), "Zoom In scales the text (" + Theme.zoomText + ", " + a.font.pixelSize + ")");
            Theme.setZoom(1.5);
        }],
        ["fonts and zoom", () => {
            const a = ed().firstArea();
            check(a.pixelSizeAt(3) === Math.round(Math.round(Theme.editorSize * 1.5) * 1.6), "and the headings with it (" + a.pixelSizeAt(3) + ")");
            input.key(win, Qt.Key_0, Qt.ControlModifier);
            check(Theme.editorZoom === 1, "Ctrl+0 goes back to actual size (" + Theme.zoomText + ")");
            input.key(win, Qt.Key_Equal, Qt.ControlModifier);
            check(Theme.editorZoom === 1.1, "Ctrl+= zooms in (" + Theme.zoomText + ")");
            Theme.resetZoom();
            a.forceActiveFocus(); a.cursorPosition = a.length;
            a.insert(a.length, " grows");
            Theme.lineHeight = 2.0;
        }],
        ["fonts and zoom", () => {
            const a = ed().firstArea();
            check(Math.abs(a.lineHeightAt(0) - 2) < 0.01 && Math.abs(a.lineHeightAt(a.length) - 2) < 0.01, "changing the spacing re-lays out the open text (" + a.lineHeightAt(0) + ")");
            a.insert(a.length, "\nA new line");
            check(Math.abs(a.lineHeightAt(a.length) - 2) < 0.01, "new paragraphs get it too");
            Theme.lineHeight = 1.45;
            ws().openTextSettings();
            check(prefs.opened && prefs.page === "font", "the editor's Aa button opens Preferences at Font & Spacing (" + prefs.page + ")");
            prefs.close();
        }],
        ["preferences", () => {
            prefs.openAt("writing");
            check(prefs.opened && prefs.page === "writing", "Preferences opens at a chosen page");
            check(!Api.call("spellCheck", "zorblaxian"), "a made-up word is misspelled");
            check(!prefs.addWord("two words"), "a phrase can't be added to the dictionary");
            check(prefs.addWord("zorblaxian") && prefs.words.indexOf("zorblaxian") >= 0 && Api.call("spellCheck", "zorblaxian"), "a word added in Preferences is listed and accepted");
            prefs.wordFilter = "zorbl";
            check(prefs.shownWords.length === 1, "the word list filters (" + prefs.shownWords + ")");
            prefs.wordFilter = "";
            check(prefs.removeWord("zorblaxian") && prefs.words.indexOf("zorblaxian") < 0 && !Api.call("spellCheck", "zorblaxian"), "removing it there makes it misspelled again");
            Theme.autosaveSeconds = 60;
            check(win.autosaveMs() === 60000, "the autosave period follows the preference (" + win.autosaveMs() + ")");
            Theme.autosaveSeconds = 15;
            check(Theme.projectsFolder === "" && Theme.newProjectsFolder.endsWith("/Wordloom"), "new projects go in Documents/Wordloom by default (" + Theme.newProjectsFolder + ")");
            check(prefs.setScale(1.25) === 1.25 && prefs.scaleInfo.saved === 1.25 && Api.call("uiScale").saved === 1.25, "the interface size is saved for the next start");
            check(Api.call("uiScale").running === 1, "and doesn't change this run");
            check(prefs.setScale(7) === undefined && Api.call("uiScale").saved === 1.25, "a size out of range is refused");
            prefs.setScale(1);
            check(Api.call("uiScale").saved === 1, "100% goes back to normal");
            prefs.openAt("nonsense");
            check(prefs.page === "writing", "an unknown page leaves the page as it was");
            prefs.close();
        }],
        ["interface font", () => {
            Theme.resetUiFont();
            check(win.font.family === Theme.systemFont.family && Math.abs(win.font.pointSize - Theme.systemPointSize) < 0.01 && Theme.px(11) === 11,
                "the interface follows the system font by default (" + win.font.family + " " + win.font.pointSize + ")");
            const fam = Qt.fontFamilies().find(f => f !== Theme.systemFont.family);
            Theme.uiFont = fam;
            check(win.font.family === fam && prefs.font.family === fam && history.font.family === fam, "a chosen interface font reaches the window, dialogs and the history window (" + fam + ")");
            const pt = Math.min(prefs.uiSizeMax, Math.round(Theme.systemPointSize) + 4);
            check(prefs.setUiFontSize(pt) && win.font.pointSize === pt && prefs.font.pointSize === pt, "the interface size can be set in points (" + pt + ")");
            check(Theme.px(11) > 11 && Theme.px(28) > 28, "fixed sizes and row heights grow with it (" + Theme.px(11) + ", " + Theme.px(28) + ")");
            check(!prefs.setUiFontSize(99) && win.font.pointSize === pt, "a size out of range is refused");
            Theme.resetUiFont();
            check(win.font.family === Theme.systemFont.family && Theme.uiFontSize === 0 && Theme.px(11) === 11, "Use the System Font goes back to the system's");
        }],
        ["indent and blank lines", () => {
            const a = ed().firstArea();
            Theme.firstLineIndent = 1.5; Theme.blankLineHeight = 1;
            a.text = "# Title\nFirst para.\n\nSecond para.\ncontinued\n\n> A quote\n\nThird.";
        }],
        ["indent and blank lines", () => {
            const a = ed().firstArea(), em = Math.round(1.5 * Theme.editorPixelSize), at = (w) => a.indentAt(a.text.indexOf(w));
            check(at("First") === 0 && at("Second") === em && at("continued") === 0 && at("quote") === 0 && at("Title") === 0,
                  "body paragraphs are indented, except after a heading, continuation lines and quotes ("
                  + [at("First"), at("Second"), at("continued"), at("quote")] + " for " + em + ")");
            check(!a.canUndo, "the indent leaves nothing to undo");
            a.insert(a.text.indexOf("Second"), "# ");
        }],
        ["indent and blank lines", () => {
            const a = ed().firstArea(), at = (w) => a.indentAt(a.text.indexOf(w));
            check(at("Second") === 0, "a line made a heading loses its indent (" + at("Second") + ")");
            a.forceActiveFocus();
            input.key(win, Qt.Key_Z, Qt.ControlModifier);
        }],
        ["indent and blank lines", () => {
            const a = ed().firstArea(), em = Math.round(1.5 * Theme.editorPixelSize), at = (w) => a.indentAt(a.text.indexOf(w));
            check(a.text.indexOf("# Second") >= 0 && at("Second") === em, "the first Ctrl+Z undoes just the layout fix (" + at("Second") + ", " + JSON.stringify(a.text) + ")");
            input.key(win, Qt.Key_Z, Qt.ControlModifier);
            check(a.text.indexOf("# Second") < 0 && at("Second") === em, "the second undoes the typing (" + at("Second") + ", " + JSON.stringify(a.text) + ")");
            input.key(win, Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier);
            input.key(win, Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier);
            check(a.text.indexOf("# Second") >= 0 && at("Second") === 0, "and Ctrl+Shift+Z twice redoes both (" + at("Second") + ")");
            input.key(win, Qt.Key_Z, Qt.ControlModifier);
            input.key(win, Qt.Key_Z, Qt.ControlModifier);
            a.insert(a.length, "\n\nFourth.");
        }],
        ["indent and blank lines", () => {
            const a = ed().firstArea(), em = Math.round(1.5 * Theme.editorPixelSize), at = (w) => a.indentAt(a.text.indexOf(w));
            check(at("Fourth") === em && at("Third") === 0, "a new paragraph is indented (" + at("Fourth") + ", after a quote " + at("Third") + ")");
            Theme.blankLineHeight = 0.3;
        }],
        ["indent and blank lines", () => {
            const a = ed().firstArea(), blank = a.text.indexOf("\n\n") + 1;
            check(Math.abs(a.lineHeightAt(blank) - 1.45 * 0.3) < 0.02 && Math.abs(a.lineHeightAt(a.text.indexOf("First")) - 1.45) < 0.01,
                  "blank lines can be shorter (" + a.lineHeightAt(blank) + ")");
            check(a.canUndo, "changing the layout mid-edit keeps the undo history");
            Theme.firstLineIndent = 0; Theme.blankLineHeight = 1;
            a.text = "";
        }],
        ["paragraph style", () => {
            const a = ed().firstArea();
            a.text = "Line one\nLine two";
            a.forceActiveFocus(); ed().activeArea = a;
            a.cursorPosition = a.text.indexOf("two");
            ws().setParagraphStyle("h2");
            check(a.text === "Line one\n## Line two" && ed().paragraphStyle === "h2", "a heading style marks the caret's line (" + JSON.stringify(a.text) + ")");
            check(a.text.substring(a.cursorPosition, a.cursorPosition + 3) === "two", "the caret stays on its word");
            ws().setParagraphStyle("quote");
            check(a.text === "Line one\n> Line two" && ed().paragraphStyle === "quote", "the quote style replaces the heading (" + JSON.stringify(a.text) + ")");
            input.key(win, Qt.Key_1, Qt.ControlModifier | Qt.AltModifier);
            check(a.text === "Line one\n# Line two", "Ctrl+Alt+1 makes it a heading (" + JSON.stringify(a.text) + ")");
            input.key(win, Qt.Key_0, Qt.ControlModifier | Qt.AltModifier);
            check(a.text === "Line one\nLine two" && ed().paragraphStyle === "body", "Ctrl+Alt+0 makes it body text (" + JSON.stringify(a.text) + ")");
            a.select(0, a.length);
            ws().setParagraphStyle("quote");
            check(a.text === "> Line one\n> Line two", "a quote covers every selected line (" + JSON.stringify(a.text) + ")");
            a.text = "";
        }],
        ["name completion", () => {
            const a = ed().firstArea();
            a.forceActiveFocus(); ed().activeArea = a;
            a.text = "Then ";
            a.cursorPosition = 5;
            a.insert(5, "Tob");
            check(ed().completions.length > 0 && ed().completions.indexOf("Tobias Wren") >= 0, "typing 'Tob' suggests Tobias Wren (" + JSON.stringify(ed().completions) + ")");
            ed().completionIndex = ed().completions.indexOf("Tobias Wren");
            ed().completionKey({ key: Qt.Key_Tab });
            check(a.text === "Then Tobias Wren" && ed().completions.length === 0, "Tab completes it: " + JSON.stringify(a.text));
            a.insert(a.cursorPosition, " met mara");
            check(ed().completions.length === 0, "lower-case words aren't completed");
            a.text = "";
        }],
        ["smart punctuation", () => {
            const a = ed().firstArea();
            a.text = "";
            a.forceActiveFocus(); ed().activeArea = a;
            const type = (s) => { for (const ch of s) if (!ed().smartKey(a, { text: ch, modifiers: 0 })) a.insert(a.cursorPosition, ch); };
            type("\"Don't--\" she said... \"Wait.\"\n\n---");
            check(a.text === "“Don’t—” she said… “Wait.”\n\n---", "typing gives curly quotes, dashes and ellipses, and keeps --- as a scene break: " + JSON.stringify(a.text));
            a.text = "\"Plain\" -- text...";
            ed().smartenAll();
            check(a.text === "“Plain” — text…", "Convert to Smart Punctuation fixes existing text: " + JSON.stringify(a.text));
        }],
        ["split editor follows focus", () => {
            ws().select(rowId("Arrival"), "editor");
            ws().openInSplit(rowId("The Keeper"));
        }],
        ["split editor follows focus", () => {
            const main = ws().currentId;
            ws().splitEditorRef().firstArea().forceActiveFocus();
            ws().binderRef().selected(rowId("Night Watch"));    // as a click in the binder does
            check(ws().splitId === rowId("Night Watch") && ws().currentId === main,
                  "with the split editor focused, a binder pick opens there and the main editor keeps its document");
            check(ws().binderRef().currentId === ws().splitId && ws().inspectorRef().nodeId === ws().splitId,
                  "the binder highlight and Details follow the focused split editor");
            ed().firstArea().forceActiveFocus();
            ws().binderRef().selected(rowId("The Week Before"));
            check(ws().currentId === rowId("The Week Before") && ws().splitId === rowId("Night Watch"),
                  "with the main editor focused, a binder pick opens in the main editor");
            ws().splitId = "";
        }],
        ["find & replace", () => {
            const a = ed().firstArea();
            a.text = "the cat and then the dog";
            ws().findInDocument(true);
            ed().findText = "the"; ed().findStep(0);
            check(ed().matchCount === 2, "whole words: 'the' matches twice, not inside 'then' (" + ed().matchCount + ")");
            ed().replaceText = "a"; ed().replaceAll();
            check(a.text === "a cat and then a dog", "replace all leaves 'then' alone: " + JSON.stringify(a.text));
            ed().closeFind();
        }],
        ["spelling", () => {
            const a = ed().firstArea();
            a.text = "The lantren was lit by Tobias.";
            const r = a.positionToRectangle(6);
            a.prepareMenu(Qt.point(r.x + 1, r.y + r.height / 2));
            check(a.word === "lantren" && a.misspelled, "'lantren' is flagged");
            check(a.suggestions.indexOf("lantern") >= 0, "'lantern' is suggested");
            ed().menuArea = a;
            const m = ed().menuRef();
            check(m.misspelled && m.suggestions.indexOf("lantern") >= 0, "the shared right-click menu shows them for the area clicked");
            ed().menuArea = null; a.prepareMenu(Qt.point(0, 0));
            input.click(win, a.mapToItem(null, r.x + 1, r.y + r.height / 2), Qt.RightButton);
            check(m.opened && m.a === a && m.suggestions.indexOf("lantern") >= 0, "a real right-click on the word opens the menu with suggestions (" + m.opened + ")");
            m.close();
            check(Api.get("spellCheck", false, "Tobias"), "character names are accepted");
        }],
        ["views", () => {
            ws().viewMode = "relations";
        }],
        ["views", () => {
            check(Api.get("relations", null).people.length === 3, "the map lists the sample's three characters");
            ws().viewMode = "reader";
        }],
        ["views", () => {
            check(ws().viewMode === "reader", "reading mode opens");
            ws().viewMode = "editor";
            history.show(0);
        }],
        ["history window", () => {
            check(history.hist !== null && history.hist.buckets.length === 30, "the Daily preset shows 30 days");
            history.applyPreset(1);
            check(history.hist.bucket === "week", "Weekly groups by week");
            check(Qt.colorEqual(history.palette.base, Theme.base) && Qt.colorEqual(history.palette.text, Theme.text),
                  "the window's controls use the app theme, not the system colours");
            history.close();
        }],
        ["appearances", () => {
            ws().select(rowId("Tobias Wren"));
        }],
        ["appearances", () => {
            const ap = ws().inspectorRef().appearances;
            check(ap !== null && ap.total > 0 && ap.documents.length > 0, "Details lists the scenes that mention Tobias (" + (ap ? ap.total : "none") + ")");
            if (ap && ap.documents.length) ws().showMention(ap.documents[0].id, ap.documents[0].name);
        }],
        ["appearances", () => {
            check(ws().viewMode === "editor" && ed().findOpen && ed().matchCount > 0, "clicking one opens the scene with the name found (" + ed().matchCount + ")");
            ed().closeFind();
        }],
        ["text analysis", () => {
            analysis.wholeBook = true;
            analysis.open();
        }],
        ["text analysis", () => {
            const r = analysis.r;
            check(r !== null && r.words === Api.get("stats", null).manuscript_words, "Text Analysis counts the same words as the statistics (" + (r ? r.words : "none") + ")");
            check(r !== null && r.top_words.length > 0 && r.top_words.every(w => w.text !== "the"), "most used words leave out common words");
            analysis.close();
        }],
        ["go to", () => {
            goTo.start();
            const recent = goTo.hits.length;
            goTo.hits = Api.get("goTo", [], "nght wtch");
            check(recent > 0 && goTo.hits.length > 0 && goTo.hits[0].title === "Night Watch", "Go to finds 'Night Watch' from 'nght wtch'");
            goTo.choose(0);
            check(!goTo.opened && ws().current && ws().current.title === "Night Watch" && ws().viewMode === "editor", "choosing it opens the document");
        }],
        ["pdf export", () => {
            const dir = Api.get("meta", null).path;
            const base = "file://" + dir.substring(0, dir.lastIndexOf("/"));
            compile.selectFormat("pdf", 0);
            const book = compile.writePdf(base + "/selftest-book.pdf");
            check(book.ok && book.pages >= 3, "a book PDF is written (" + book.pages + " pages)");
            compile.selectFormat("pdf", 1);
            const ms = compile.writePdf(base + "/selftest-manuscript.pdf");
            check(ms.ok && ms.pages >= 4, "a manuscript PDF is written (" + ms.pages + " pages)");
            check(compile.shortTitle() === "Lighthouse Keeper", "the header uses a short title: " + compile.shortTitle());
            // A long chapter runs on over many pages.
            const para = "The keeper climbed the hundred and twelve steps again, counting each one under his breath, and the lamp waited at the top as it always had. ";
            Api.call("setText", rowId("Arrival"), Array(60).fill(para + para).join("\n\n"));
            const longPdf = compile.writePdf(base + "/selftest-long.pdf");
            check(longPdf.ok && longPdf.pages >= ms.pages + 10, "a long chapter continues over many pages (" + longPdf.pages + ")");
            compile.selectFormat("markdown", 0);
        }],
        ["compile indent", () => {
            compile.selectFormat("html", 0);
            compile.setIndent(5);
            check(compile.options().indent === 2 && Api.get("compile", "", compile.options()).indexOf("p{margin:0;text-indent:2em}") >= 0, "a chosen paragraph indent reaches the export");
            Theme.firstLineIndent = 1;
            compile.setIndent(1);
            check(compile.options().indent === 1, "Same as editor uses the editor's indent (" + compile.options().indent + ")");
            Theme.firstLineIndent = 0;
            compile.setIndent(2);
            check(Api.get("compile", "", compile.options()).indexOf("p{margin:0 0 1em;text-indent:0}") >= 0, "None spaces the paragraphs instead");
            compile.setIndent(0);
            check(compile.options().indent === null, "the format's default sends no indent");
            compile.selectFormat("markdown", 0);
        }],
        ["import manuscript", () => {
            // Round trip: export the manuscript as Markdown, import it back.
            const meta = Api.get("meta", null), dir = meta.path.substring(0, meta.path.lastIndexOf("/"));
            const before = Api.get("stats", null).manuscript_words;
            const file = Api.call("export", "file://" + dir + "/selftest-export.md", { format: "markdown" });
            const r = file ? win.importManuscript("file://" + file) : null;
            check(r !== null && r.chapters === 3 && r.scenes >= 4 && r.words === before, "an exported manuscript imports back: " + JSON.stringify(r) + " of " + before + " words");
            check(ws().viewMode === "corkboard" && ws().current && ws().current.title === meta.title, "the imported book opens on the corkboard, named after its title (" + ws().viewMode + ", " + (ws().current ? ws().current.title : "none") + ")");
        }],
        ["zip backup", () => {
            const dir = Api.get("meta", null).path;
            const r = Api.call("backupZip", dir.substring(0, dir.lastIndexOf("/")) + "/selftest-backup.zip");
            check(r && r.files >= 5 && r.bytes > 1000, "Back Up to Zip packs the project (" + (r ? r.files + " files, " + r.bytes + " bytes" : "failed") + ")");
        }],
        ["hidden editor", () => {
            ws().select(rowId("Arrival"), "editor");
            const ms = Api.call("rootId", "manuscript");
            ws().select(ms, "corkboard");
            check(ed().stale && !ed().docs.some(d => d.id === ms), "a hidden editor doesn't build what's selected (a whole manuscript would take seconds)");
            ws().viewMode = "editor";
            check(!ed().stale && ed().docs.length > 0 && ed().docs[0].id === ms, "it catches up when shown (" + (ed().docs.length ? ed().docs[0].title : "none") + ")");
            ws().select(rowId("Arrival"), "editor");
        }],
        ["binder multi-select", () => {
            const b = ws().binderRef(), click = (t, m) => input.click(win, b.rowPoint(rowId(t)), Qt.LeftButton, m || 0);
            click("Arrival");
            click("The Keeper", Qt.ControlModifier);
            click("Night Watch", Qt.ControlModifier);
            check(b.pickCount === 3 && ws().current.title === "Arrival", "Ctrl+click picks items and keeps the open one (" + b.pickCount + ")");
            const done = Api.get("labels", null).statuses.find(x => x.name === "Done");
            b.setPicked("status", done.id);
            check(["Arrival", "The Keeper", "Night Watch"].every(t => Api.get("nodeInfo", {}, rowId(t)).status === done.id), "a status is set on all of them");
            Api.call("undo");
            check(["Arrival", "The Keeper", "Night Watch"].every(t => Api.get("nodeInfo", {}, rowId(t)).status !== done.id), "and one Undo takes it off all of them");
            click("Arrival");
            check(b.pickCount === 0, "a plain click goes back to one item");
            click("Night Watch", Qt.ShiftModifier);
            check(b.pickedIds().map(id => b.rows[b.rowIndex(id)].title).join(",") === "Arrival,The Keeper,The Log,Night Watch", "Shift+click picks a range (" + b.pickedIds().length + ")");
            input.key(win, Qt.Key_Escape);
            check(b.pickCount === 0, "Esc clears it");
            click("Arrival"); click("The Keeper", Qt.ControlModifier);
            input.key(win, Qt.Key_Delete);
            check(Api.get("children", [], rowId("The Storm")).length === 0, "Delete moves all the picked items to the Trash");
            Api.call("undo");
            check(Api.get("children", [], rowId("The Storm")).map(x => x.title).join(",") === "Arrival,The Keeper", "one Undo brings them both back");
        }],
        ["binder multi-select", () => {
            // Drag two picked scenes into The Return, by the second one.
            const b = ws().binderRef(), at = (t) => b.rowPoint(rowId(t));
            input.click(win, at("Arrival"));
            input.click(win, at("Night Watch"), Qt.LeftButton, Qt.ControlModifier);
            input.drag(win, at("Night Watch"), at("The Return"));
            const kids = Api.get("children", [], rowId("The Return")).map(x => x.title).join(",");
            check(kids === "Confession,Arrival,Night Watch", "dragging picked items moves them all, in binder order (" + kids + ")");
            check(Api.call("history").undo === "Move 2 Items", "as one undo step");
            Api.call("undo");
            check(Api.get("children", [], rowId("The Storm")).map(x => x.title).join(",") === "Arrival,The Keeper", "Undo puts them back");
        }],
        ["corkboard drag", () => { ws().select(rowId("The Storm"), "corkboard"); }],
        ["corkboard drag", () => {
            const c = ws().corkboardRef(), titles = () => c.cards.map(x => x.title).join(",");
            check(titles() === "Arrival,The Keeper", "the corkboard shows The Storm's scenes (" + titles() + ")");
            c.startDrag(rowId("The Keeper"), "The Keeper");
            c.updateDrag(c.cardPoint(1, 0.5));
            check(c.dropMode === "", "dropping a card on itself does nothing");
            c.updateDrag(c.cardPoint(0, 0.2));
            check(c.dropMode === "before" && c.dropIndex === 0, "the left half of a card drops before it (" + c.dropMode + " " + c.dropIndex + ")");
            check(c.finishDrag() && titles() === "The Keeper,Arrival", "dragging a card reorders the scenes (" + titles() + ")");
            Api.call("undo");
            check(titles() === "Arrival,The Keeper", "Undo puts it back (" + titles() + ")");
        }],
        // Steps of their own: after Undo the cards are rebuilt on the next layout.
        ["corkboard drag", () => {
            // The same with real mouse events, starting on the card's edge.
            const c = ws().corkboardRef(), titles = () => c.cards.map(x => x.title).join(",");
            const from = c.cardGrip(1), to = c.cardPoint(0, 0.2);
            if (from && to) input.drag(win, from, to);
            check(titles() === "The Keeper,Arrival", "a mouse drag moves the card (" + titles() + ")");
            if (titles() === "The Keeper,Arrival") Api.call("undo");
        }],
        // Its own step: after Undo the cards are rebuilt on the next layout.
        ["corkboard drag", () => {
            const c = ws().corkboardRef(), titles = () => c.cards.map(x => x.title).join(",");
            const from = c.cardPoint(1, 0.5), to = c.cardPoint(0, 0.2);
            check(from !== null && to !== null, "the cards are laid out");
            if (from && to) input.drag(win, from, to);
            check(titles() === "Arrival,The Keeper" && c.dragId === "", "dragging across the synopsis text selects it instead of moving the card (" + titles() + ", drag " + c.dragId + " " + c.dropMode + ")");
            ws().select(Api.call("rootId", "manuscript"), "corkboard");
        }],
        ["corkboard drag", () => {
            const c = ws().corkboardRef(), ret = rowId("The Return"), log = rowId("The Log");
            const iLog = c.cards.findIndex(x => x.id === log);
            c.startDrag(ret, "The Return");
            c.updateDrag(c.cardPoint(iLog, 0.5));
            check(c.dropMode === "inside", "the middle of a folder card drops into the folder (" + c.dropMode + ")");
            c.finishDrag();
            check(Api.get("children", [], log).some(x => x.id === ret), "the card moves into the folder");
            Api.call("undo");
            check(c.cards.some(x => x.id === ret), "Undo brings it back");
        }],
        ["corkboard keys", () => { ws().select(rowId("The Storm"), "corkboard"); }],
        ["corkboard keys", () => {
            const c = ws().corkboardRef(), titles = () => c.cards.map(x => x.title).join(",");
            const key = (k, m) => input.key(win, k, m || 0);
            c.focusBoard();
            c.keyId = c.cards[0].id;
            key(Qt.Key_Right);
            check(c.keyIndex === 1, "→ highlights the next card (" + c.keyIndex + ")");
            key(Qt.Key_Left, Qt.ControlModifier);
            check(titles() === "The Keeper,Arrival" && c.cards[c.keyIndex].title === "The Keeper", "Ctrl+← moves the card earlier and keeps it highlighted (" + titles() + ")");
            Api.call("undo");
            key(Qt.Key_Backspace);
        }],
        ["corkboard keys", () => {
            const c = ws().corkboardRef(), key = (k, m) => input.key(win, k, m || 0);
            check(c.containerTitle === "Manuscript" && c.cards[c.keyIndex].title === "The Storm", "Backspace goes up a folder, highlighting where you were (" + c.containerTitle + ", " + (c.keyIndex >= 0 ? c.cards[c.keyIndex].title : "none") + ")");
            key(Qt.Key_Return);
        }],
        ["corkboard keys", () => {
            const c = ws().corkboardRef(), key = (k, m) => input.key(win, k, m || 0);
            check(c.containerTitle === "The Storm" && ws().viewMode === "corkboard", "Enter on a folder card shows its cards (" + c.containerTitle + ")");
            key(Qt.Key_End);
            check(c.cards[c.keyIndex].title === "The Keeper", "End highlights the last card");
            key(Qt.Key_Delete);
            check(c.cards.map(x => x.title).join(",") === "Arrival" && c.cards[c.keyIndex].title === "Arrival", "Delete trashes the card and highlights its neighbour");
            Api.call("undo");
            key(Qt.Key_End);
            key(Qt.Key_Return);
            check(ws().viewMode === "editor" && ws().current && ws().current.title === "The Keeper", "Enter on a document opens it in the editor (" + ws().viewMode + ")");
        }],
        ["freeform corkboard", () => { ws().select(rowId("The Storm"), "corkboard"); }],
        ["freeform corkboard", () => {
            const c = ws().corkboardRef();
            c.setFreeform(true);
        }],
        ["freeform corkboard", () => {
            const c = ws().corkboardRef();
            const s0 = c.spots[c.cards[0].id], s1 = c.spots[c.cards[1].id];
            check(c.freeform && s0 && s1 && (s0.x !== s1.x || s0.y !== s1.y), "a freeform board lays the cards out in free slots");
            const from = c.cardGrip(0), to = from ? Qt.point(from.x + 2 * c.cardWidth, from.y + c.cardHeight) : null;
            if (from) input.drag(win, from, to);
        }],
        ["freeform corkboard", () => {
            const c = ws().corkboardRef(), titles = () => c.cards.map(x => x.title).join(",");
            const p = c.board.positions[rowId("Arrival")];
            check(p !== undefined && p[0] > 300 && p[1] > 100, "dragging a card puts it where it was dropped (" + JSON.stringify(p) + ")");
            check(titles() === "Arrival,The Keeper", "without changing the binder order (" + titles() + ")");
            c.orderBinder();
            check(titles() === "The Keeper,Arrival", "Order Binder by Board reads the board in rows (" + titles() + ")");
            Api.call("undo");
            check(Api.call("undo") === "Move on Corkboard" && c.board.positions[rowId("Arrival")] === undefined, "Undo takes the move back");
            check(c.freeform, "and leaves the board freeform");
            const id = c.addNote(null);
            // What the check below compares with, if focus is missing on CI.
            st.noteAdded = { rev: Wordloom.revision, editor: c.noteEditor(id) };
            Qt.callLater(() => { if (st.noteAdded) st.noteAdded.focused = !!(c.noteEditor(id) && c.noteEditor(id).activeFocus); });
        }],
        ["freeform corkboard", () => {
            const c = ws().corkboardRef(), notes = c.board.notes;
            check(notes.length === 1 && c.items.length === c.cards.length + 1, "+ Note puts a note on the board, not in the binder");
            const ta = c.noteEditor(notes[0].id);
            const a = st.noteAdded || {}, fi = win.activeFocusItem;
            check(ta !== null && ta.activeFocus, "the new note is ready to type in (" + (ta ? "focus " + ta.activeFocus : "no editor")
                + (ta && ta.activeFocus ? "" : "; same editor " + (ta === a.editor) + ", focused after callLater " + a.focused
                    + ", revision +" + (Wordloom.revision - a.rev) + ", focus on " + (fi ? fi + (fi.parent ? " in " + fi.parent : "") : "nothing")
                    + ", window active " + win.active) + ")");
            if (ta) { ta.insert(0, "Storm rips the lamp glass"); c.focusBoard(); }
        }],
        ["freeform corkboard", () => {
            const c = ws().corkboardRef(), n = c.board.notes[0];
            check(n && n.text === "Storm rips the lamp glass", "the note's text is saved (" + (n ? n.text : "") + ")");
            const before = c.cards.length;
            const id = c.noteToDocument(n.id);
            check(id && c.cards.length === before + 1 && c.board.notes.length === 0, "Make into Document adds it to the binder");
            check(JSON.stringify(c.board.positions[id]) === JSON.stringify([n.x, n.y]), "in the note's place on the board");
            Api.call("undo");
            check(c.board.notes.length === 1 && c.cards.length === before, "Undo turns it back into a note");
            c.keyId = c.board.notes[0].id;
            c.focusBoard();
            input.key(win, Qt.Key_Delete);
            check(c.board.notes.length === 0, "Delete removes a highlighted note");
            c.setBoardColor("#3f6b4e");
            check(Qt.colorEqual(c.color, "#3f6b4e") && !c.boardIsLight, "the board takes the chosen colour (" + c.color + ")");
            check(Api.get("board", null, rowId("The Log")).color === null, "only this board (" + JSON.stringify(Api.get("board", null, rowId("The Log")).color) + ")");
            c.useColorEverywhere();
            check(Api.get("board", null, rowId("The Log")).color === "#3f6b4e", "Use This Colour on All Boards sets the others");
            Api.call("undo");
            Api.call("undo");
            check(Qt.colorEqual(c.color, Theme.cork), "Undo brings back the cork colour");
            c.setFreeform(false);
            check(!c.freeform, "the board goes back to a grid");
        }],
        ["freeform into folder", () => {
            ws().select(Api.call("rootId", "manuscript"), "corkboard");
            ws().corkboardRef().setFreeform(true);
        }],
        ["freeform into folder", () => {
            const c = ws().corkboardRef(), ret = rowId("The Return");
            const iRet = c.items.findIndex(x => x.id === ret), iStorm = c.items.findIndex(x => x.title === "The Storm");
            const from = c.cardGrip(iRet), to = c.cardPoint(iStorm, 0.5);
            check(from !== null && to !== null, "the folder cards are on the board");
            if (from && to) input.drag(win, from, to);
        }],
        ["freeform into folder", () => {
            const c = ws().corkboardRef(), ret = rowId("The Return");
            check(Api.get("children", [], rowId("The Storm")).some(x => x.id === ret) && c.freeDropFolder === "",
                  "dropping a card on the middle of a folder card moves it into the folder");
            Api.call("undo");
            check(c.cards.some(x => x.id === ret), "Undo brings it back");
            const w = c.cardWidth;
            c.zoomWheel({ angleDelta: { y: 120 }, accepted: false });
            check(c.cardWidth === w + 20 && Theme.cardWidth === w + 20, "Ctrl+scroll makes the cards bigger (" + w + " → " + c.cardWidth + ")");
            c.zoomWheel({ angleDelta: { y: -120 }, accepted: false });
            check(c.cardWidth === w, "and smaller again");
            c.setFreeform(false);
        }],
        ["freeform groups", () => {
            ws().select(Api.call("rootId", "manuscript"), "corkboard");
            ws().corkboardRef().setFreeform(true);
        }],
        ["freeform groups", () => {
            const c = ws().corkboardRef(), log = rowId("The Log"), ret = rowId("The Return");
            c.picked = []; c.keyId = log; c.focusBoard();
            c.tapCard(ret, Qt.ControlModifier);
            check(c.picked.length === 2 && c.isPicked(log) && c.isPicked(ret), "Ctrl+click picks a second card with the highlighted one (" + c.picked.length + ")");
            const from = c.cardGrip(c.items.findIndex(x => x.id === log));
            groupStart = { log: c.spots[log], ret: c.spots[ret] };
            if (from) input.drag(win, from, Qt.point(from.x + 60, from.y + 300));
        }],
        ["freeform groups", () => {
            const c = ws().corkboardRef(), log = rowId("The Log"), ret = rowId("The Return");
            const dl = c.spots[log].y - groupStart.log.y, dr = c.spots[ret].y - groupStart.ret.y;
            const xl = c.spots[log].x - groupStart.log.x, xr = c.spots[ret].x - groupStart.ret.x;
            check(dl > 100 && Math.abs(dl - dr) < 0.5 && Math.abs(xl - xr) < 0.5, "dragging one picked card moves them all together (" + [dl, dr, xl, xr].map(v => v.toFixed(1)) + ")");
            check(c.groupLead === "" && c.groupDx === 0, "and the drag is over");
            check(Api.call("undo") === "Move 2 on Corkboard" && Math.abs(c.spots[ret].y - groupStart.ret.y) < 0.5, "one Undo puts both back");
            const vis = (id) => c.cardItem(id).parent.y - c.toView(c.spots[id].y);
            check(Math.abs(vis(log)) < 1 && Math.abs(vis(ret)) < 1, "and they show where they are, the one dragged too (" + vis(log) + ", " + vis(ret) + ")");
            c.handleKey({ key: Qt.Key_Escape, modifiers: 0 });
            check(c.picked.length === 0, "Esc unpicks them");
            c.handleKey({ key: Qt.Key_A, modifiers: Qt.ControlModifier });
            check(c.picked.length === c.items.length, "Ctrl+A picks everything on the board");
            c.picked = [];
            // A box dragged from the empty board over the first card.
            let maxY = 0; for (const id in c.spots) maxY = Math.max(maxY, c.spots[id].y);
            const first = c.freeOrder[0], p = c.spots[first.id];
            const from = c.boardPoint(c.toView(p.x) + 4, c.toView(maxY) + c.cardHeight + 20), to = c.boardPoint(c.toView(p.x) + 30, c.toView(p.y) + 30);
            input.drag(win, from, to);
            check(c.isPicked(first.id) && c.picked.length >= 1, "dragging a box on the empty board picks the cards in it (" + c.picked.length + ")");
            Theme.boardSnap = true;
            c.placeAt(first.id, c.toView(53), c.toView(87));
            check(c.spots[first.id].x === 60 && c.spots[first.id].y === 80, "Snap to Grid puts a dropped card on the grid (" + JSON.stringify(c.spots[first.id]) + ")");
            Theme.boardSnap = false;
            Api.call("undo");
            c.picked = [log, ret];
        }],
        ["freeform groups", () => {
            const c = ws().corkboardRef(), storm = c.items.findIndex(x => x.title === "The Storm");
            const from = c.cardGrip(c.items.findIndex(x => x.id === rowId("The Log"))), to = c.cardPoint(storm, 0.5);
            if (from && to) input.drag(win, from, to);
        }],
        ["freeform groups", () => {
            const c = ws().corkboardRef(), inStorm = Api.get("children", [], rowId("The Storm")).map(x => x.title);
            check(inStorm.indexOf("The Log") >= 0 && inStorm.indexOf("The Return") >= 0, "dropping the group on a folder card moves them all in (" + inStorm + ")");
            check(Api.call("undo") === "Move 2 Items" && c.cards.some(x => x.title === "The Log"), "one Undo brings them back");
            c.setFreeform(false);
        }],
        ["grid notes", () => {
            ws().select(rowId("The Storm"), "corkboard");
            const c = ws().corkboardRef(), sid = rowId("The Storm");
            for (const t of ["one", "two"]) Api.call("addBoardNote", sid, 0, 0, t);
        }],
        ["grid notes", () => {
            const c = ws().corkboardRef(), texts = () => c.board.notes.map(n => n.text).join(",");
            check(!c.freeform && texts() === "one,two", "the notes follow the cards on a grid (" + texts() + ")");
            const iTwo = c.items.findIndex(x => x.text === "two"), iOne = iTwo - 1;
            const from = c.cardGrip(iTwo), to = c.cardPoint(iOne, 0.2);
            if (from && to) input.drag(win, from, to);
        }],
        ["grid notes", () => {
            const c = ws().corkboardRef(), texts = () => c.board.notes.map(n => n.text).join(",");
            check(texts() === "two,one", "a note dragged on the grid moves among the notes (" + texts() + ")");
            check(c.cards.map(x => x.title).join(",") === "Arrival,The Keeper", "and the cards stay put");
            // Onto a folder card: the note goes to that folder's board.
            const ms = Api.call("rootId", "manuscript"), two = c.board.notes[0].id;
            ws().select(ms, "corkboard");
            Api.call("moveBoardNote", rowId("The Storm"), two, ms, 0);
        }],
        ["grid notes", () => {
            const c = ws().corkboardRef();
            const iNote = c.items.findIndex(x => x.text === "two"), iLog = c.items.findIndex(x => x.title === "The Log");
            c.startDrag(c.items[iNote].id, "two");
            c.updateDrag(c.cardPoint(iLog, 0.5));
            check(c.dropMode === "inside", "a note over the middle of a folder card drops into it (" + c.dropMode + ")");
            c.finishDrag();
            check(Api.get("board", null, rowId("The Log")).notes.some(n => n.text === "two") && !c.items.some(x => x.text === "two"),
                  "and moves to that folder's board");
            for (const id of [rowId("The Log"), rowId("The Storm")])
                for (const n of Api.get("board", null, id).notes) Api.call("removeBoardNote", id, n.id);
        }],
        ["outliner", () => {
            Api.call("setField", rowId("Arrival"), "field:POV", "Mara");
            ws().select(Api.call("rootId", "manuscript"), "outliner");
        }],
        ["outliner", () => {
            const o = ws().outlinerRef(), all = o.rows.length, storm = o.rows.find(x => x.title === "The Storm");
            check(storm && all > storm.child_count, "the outliner lists the manuscript (" + all + " rows)");
            o.toggle(storm.id);
            check(o.rows.length === all - storm.child_count && !o.rows.some(x => x.title === "Arrival"), "collapsing a folder hides what's inside it");
            o.setAllCollapsed(false);
            check(o.rows.length === all, "Expand All shows everything again");
            check(o.fieldKeys.indexOf("POV") >= 0, "custom fields used below are offered as columns (" + o.fieldKeys + ")");
            o.toggleColumn("field:POV");
            check(o.hasColumn("field:POV") && o.cellText(o.rows.find(x => x.title === "Arrival"), "field:POV") === "Mara", "a field column shows each item's value");
            o.setCell(o.rows.find(x => x.title === "The Keeper"), "field:POV", "Tobias");
            check(Api.get("nodeInfo", {}, rowId("The Keeper")).fields.POV === "Tobias", "editing a field cell saves it");
            o.setCell(o.rows.find(x => x.title === "The Keeper"), "keywords", "storm, arrival");
            check(Api.get("nodeInfo", {}, rowId("The Keeper")).keywords.join("|") === "storm|arrival", "keywords are edited comma separated");
            o.toggleColumn("field:POV");
            check(!o.hasColumn("field:POV"), "the column can be hidden again");
            o.filterText = "mara";
            const titles = o.rows.map(x => x.title + (x.context ? "*" : ""));
            check(titles.indexOf("Arrival") >= 0 && titles.indexOf("The Storm*") >= 0 && titles.indexOf("The Keeper") < 0,
                  "a text filter shows matching items under their folders (" + titles + ")");
            o.clearFilter();
            Api.call("setField", rowId("Confession"), "field:POV", "Zed");
            o.filterText = "zed";
            check(o.matchCount === 1 && o.rows.some(x => x.title === "Confession" && !x.context), "it matches custom field values (" + o.rows.map(x => x.title) + ")");
            Api.call("setField", rowId("Confession"), "field:POV", "");
            o.clearFilter();
            const todo = o.meta.statuses.find(x => x.name === "To Do");
            o.filterStatus = todo.id;
            check(o.rows.filter(x => !x.context).every(x => x.status === todo.id) && o.matchCount >= 2, "a status filter shows only those items (" + o.matchCount + ")");
            o.filterLabel = "none";
            check(o.rows.filter(x => !x.context).every(x => !x.label && x.status === todo.id), "label and status filters combine");
            o.clearFilter();
            check(!o.filtering && o.rows.length === all, "clearing the filter shows everything again");
            Api.call("setField", rowId("Arrival"), "field:POV", ""); Api.call("setField", rowId("The Keeper"), "field:POV", ""); Api.call("setField", rowId("The Keeper"), "keywords", "");
        }],
        ["templates", () => {
            const t = Api.call("templates") || [];
            check(t.map(x => x.id).join(",") === "blank,novel,short-story,nonfiction", "New Project offers the templates (" + t.map(x => x.name) + ")");
            // Build one beside the sample and look at its shape, then go back.
            const meta = Api.get("meta", null), dir = meta.path.substring(0, meta.path.lastIndexOf("/"));
            Api.call("close");
            const made = Api.call("newProject", "file://" + dir, "Template Test", "", "novel");
            const acts = made !== undefined ? Api.get("children", [], Api.call("rootId", "manuscript")).map(x => x.title).join(",") : "";
            check(acts === "Act I,Act II,Act III", "a Novel starts with three acts (" + acts + ")");
            Api.call("close");
            win.openPath(meta.path);
            check(Api.get("meta", null).title === meta.title, "the sample opens again");
        }],
        ["spelling language", () => {
            const info = Api.call("spellLanguages");
            check(info && info.list.some(x => x.code === "en_US" && x.name === "English (US)"), "the installed dictionaries are listed, with names");
            const r = win.setSpellLanguage("en_US");
            check(Theme.spellLanguage === "en_US" && r && r.dictionary.indexOf("en_US") === 0, "choosing a language loads it (" + (r ? r.dictionary : "") + ")");
            check(Api.call("spellCheck", "colour") === false && Api.call("spellCheck", "Mara") === true, "US English rejects “colour” and still knows the project's names");
            const missing = win.setSpellLanguage("zz_ZZ");
            check(missing && missing.dictionary.length > 0, "a language that isn't installed falls back (" + (missing ? missing.dictionary : "") + ")");
            win.setSpellLanguage("");
            check(Theme.spellLanguage === "", "Automatic follows the system again");
        }],
        ["chapter snapshot", () => {
            ws().select(rowId("The Storm"), "corkboard");
            const arrival = rowId("Arrival"), keeper = rowId("The Keeper");
            const before = [Api.call("text", arrival), Api.call("text", keeper)];
            const n = Api.call("takeSnapshot", rowId("The Storm"), "Chapter test");
            check(n === 2, "a folder snapshot saves each scene in it (" + n + ")");
            const ip = ws().inspectorRef();
            ip.reloadSnapshots();
            const g = ip.snaps.find(x => x.title === "Chapter test");
            check(g && g.group && g.count === 2, "the chapter lists it once, for both scenes");
            Api.call("setText", arrival, "Changed."); Api.call("setText", keeper, "Changed too.");
            Api.call("restoreSnapshot", rowId("The Storm"), g.id);
            check(Api.call("text", arrival) === before[0] && Api.call("text", keeper) === before[1], "Restore All puts both scenes back");
            Api.call("deleteSnapshot", rowId("The Storm"), g.id);
            ip.reloadSnapshots();
            check(!ip.snaps.some(x => x.title === "Chapter test"), "Delete All removes it from both");
        }],
        ["character grid", () => { grid.open(); }],
        ["character grid", () => {
            const g = grid.grid, tobias = g.rows.find(r => r.title === "Tobias Wren");
            check(g.columns.slice(0, 3).map(c => c.title).join(",") === "The Storm,The Log,The Return" && tobias && tobias.total > 0, "the grid has a column per chapter (the sample's three, then the book imported earlier) and counts Tobias's mentions (" + (tobias ? tobias.counts : "none") + ")");
            const i = tobias.counts.findIndex(n => n > 0);
            grid.mentionRequested(tobias.first[i][0], tobias.first[i][1]);
        }],
        ["character grid", () => {
            check(ws().viewMode === "editor" && ed().findText.indexOf("Tobias") === 0, "clicking a cell opens the scene with the name in the find bar (" + ed().findText + ")");
            ed().closeFind();
            grid.kind = "place";
            check(grid.grid.rows.length === 1 && grid.grid.rows[0].title === "Skerry Light", "and it does places too");
            grid.kind = "character";
            grid.close();
        }],
        ["note resize", () => {
            const ms = Api.call("rootId", "manuscript");
            ws().select(ms, "corkboard");
            ws().corkboardRef().setFreeform(true);
            Theme.boardSnap = false;
            st.noteId = Api.call("addBoardNote", ms, 300, 380, "Resize me");
        }],
        ["note resize", () => {
            const c = ws().corkboardRef(), g = c.noteGrip(st.noteId);
            check(g !== null, "a freeform note has a resize grip");
            if (g) input.drag(win, g, Qt.point(g.x + 100, g.y + 60));
        }],
        ["note resize", () => {
            const c = ws().corkboardRef(), ms = Api.call("rootId", "manuscript");
            const n = Api.get("board", null, ms).notes.find(x => x.id === st.noteId) || {};
            const ew = 230 + 100 / c.unit, eh = 230 * 0.66 + 60 / c.unit;
            check(Math.abs(n.w - ew) <= 2 && Math.abs(n.h - eh) <= 2, "dragging the grip resizes the note (" + n.w + "×" + n.h + ", expected about " + Math.round(ew) + "×" + Math.round(eh) + ")");
            check(n.x === 300 && n.y === 380, "without moving it (" + n.x + ", " + n.y + ")");
            check(Math.abs(c.spots[st.noteId].w - n.w) < 0.01, "the board lays it out at its new size");
            c.resizeNote(st.noteId, 0, 0);
            check(Api.get("board", null, ms).notes.find(x => x.id === st.noteId).w === undefined, "Reset Size goes back to the card size");
            Api.call("undo");
            check(Math.abs(Api.get("board", null, ms).notes.find(x => x.id === st.noteId).w - n.w) < 0.01, "Undo brings the size back");
            Theme.boardSnap = true;
            c.resizeNote(st.noteId, 251, 133);
            const sn = Api.get("board", null, ms).notes.find(x => x.id === st.noteId);
            check(sn.w === 260 && sn.h === 140, "with Snap to Grid the size snaps too (" + sn.w + "×" + sn.h + ")");
            c.resizeNote(st.noteId, 5000, 1);
            const big = Api.get("board", null, ms).notes.find(x => x.id === st.noteId);
            check(big.w === c.noteMax[0] && big.h === c.noteMin[1], "and stays within limits (" + big.w + "×" + big.h + ")");
            Theme.boardSnap = false;
            Api.call("removeBoardNote", ms, st.noteId);
            c.setFreeform(false);
        }],
        ["shortcuts", () => {
            // Window shortcuts need the main window active (the history
            // window took that earlier).
            win.requestActivate();
        }],
        ["shortcuts", () => {
            check(win.active, "the main window is active");
            Shortcuts.resetAll();
            prefs.openAt("shortcuts");
            const pg = prefs.shortcutsRef();
            check(pg.startRecording("project.sprint") && pg.recording === "project.sprint", "clicking a shortcut waits for keys");
            input.key(win, Qt.Key_P, Qt.ControlModifier);
        }],
        ["shortcuts", () => {
            const pg = prefs.shortcutsRef();
            check(Shortcuts.seq("project.sprint") === "Ctrl+P" && !goTo.visible, "the keys pressed become the shortcut, without running Go to… (" + Shortcuts.seq("project.sprint") + ")");
            check(Shortcuts.seq("project.goTo") === "", "Go to… loses Ctrl+P (" + Shortcuts.seq("project.goTo") + ")");
            check(pg.notice.indexOf("Go to") >= 0, "and the page says so");
            pg.record("view.styled");
            pg.keyPressed({ key: Qt.Key_Escape, modifiers: 0 });
            check(pg.recording === "" && Shortcuts.seq("view.styled") === "", "Esc cancels");
            pg.record("view.spelling");
            pg.keyPressed({ key: Qt.Key_Control, modifiers: Qt.ControlModifier });
            check(pg.recording === "view.spelling", "a modifier on its own keeps waiting");
            pg.keyPressed({ key: Qt.Key_Backspace, modifiers: 0 });
            check(Shortcuts.seq("view.spelling") === "", "Backspace removes a shortcut");
            check(Shortcuts.clash("project.newDocument", "Ctrl+N") === null, "New Document and New Project share Ctrl+N (start screen and project)");
            prefs.close();
            input.key(win, Qt.Key_P, Qt.ControlModifier);
            check(sprint.visible, "the menu command runs on its new keys");
            sprint.close();
        }],
        ["shortcuts", () => {
            const t = Shortcuts.reset("project.goTo");
            check(Shortcuts.seq("project.goTo") === "Ctrl+P" && t && t.id === "project.sprint" && Shortcuts.seq("project.sprint") === "", "resetting one takes its keys back from the other");
            Shortcuts.resetAll();
            check(Shortcuts.customJson === "{}" && Shortcuts.seq("project.sprint") === "Ctrl+Shift+R" && Shortcuts.seq("view.spelling") === "F7", "Reset All restores the defaults");
            input.key(win, Qt.Key_F7, Qt.NoModifier);
            check(!Theme.spellCheck, "F7 works again");
            Theme.spellCheck = true;
        }],
        ["project replace", () => {
            const sp = ws().binderRef().searchPaneRef();
            ws().searchFor("lamp"); sp.matchCase = false; sp.wholeWords = false; sp.run();
            const all = sp.textHits.length, total = sp.replaceCount;
            check(all >= 2, "the sample has \"lamp\" in several documents (" + all + ")");
            check(sp.marked("the Lamp room").indexOf("<b>Lamp</b>") >= 0, "matches are bold in the snippets");
            sp.wholeWords = true;
            check(sp.replaceCount <= total && sp.marked("lamplight").indexOf("<b>") < 0, "whole words leaves out \"lamplight\" (" + sp.replaceCount + " of " + total + ")");
            sp.wholeWords = false;
            ws().searchFor("LAMP"); sp.matchCase = true; sp.run();
            check(sp.textHits.length === 0, "match case finds no \"LAMP\"");
            sp.matchCase = false;
            ws().searchFor("lamp"); sp.run();
            const first = sp.textHits[0].id, rest = sp.textHits.slice(1).map(h => h.id);
            st.replaceBefore = [first].concat(rest).map(id => Api.call("text", id));
            sp.setSkipped(first, true);
            check(sp.chosenHits.length === all - 1, "unticking a document leaves it out");
            const r = sp.replace("LANTERN");
            check(r && r.documents === all - 1, "replace changes the ticked documents (" + JSON.stringify(r) + ")");
            check(/lamp/i.test(Api.call("text", first)) && rest.every(id => !/lamp/i.test(Api.call("text", id)) && Api.call("text", id).indexOf("LANTERN") >= 0),
                  "the unticked one keeps its text, the others are replaced");
            ws().undo();
            check([first].concat(rest).every((id, i) => Api.call("text", id) === st.replaceBefore[i]), "one Undo puts every document back");
            ws().searchFor("");
        }],
        ["story bible", () => {
            const dir = Api.get("meta", null).path, base = "file://" + dir.substring(0, dir.lastIndexOf("/")) + "/selftest-bible";
            const bible = win.bibleRef();
            check(bible.target(base, 1) === base + ".html" && bible.target(base + ".md", 0) === base + ".md", "the file type picks the extension");
            const docx = bible.write(base + ".docx"), md = bible.write(base + ".md");
            check(docx && docx.endsWith(".docx") && md && md.endsWith(".md"), "the story bible exports as Word and Markdown (" + docx + ", " + md + ")");
        }],
        ["automatic backup", () => {
            const dir = Api.get("meta", null).path, folder = dir.substring(0, dir.lastIndexOf("/")) + "/selftest-auto";
            autoBackup.folder = folder; autoBackup.keep = 2; autoBackup.closeBackups = true;
            const r1 = autoBackup.run(true);
            check(r1 && !r1.skipped && /autobackup \d{4}-\d\d-\d\d \d{4}\.zip$/.test(r1.path), "an automatic backup is written (" + (r1 ? r1.path : "failed") + ")");
            const r2 = autoBackup.run(true);
            check(r2 && r2.skipped === true, "an unchanged project isn't backed up again");
            const k = rowId("The Keeper"), old = Api.call("text", k);
            Api.call("setText", k, old + " One more line.");
            const r3 = autoBackup.run(true);
            Api.call("setText", k, old);
            check(r3 && !r3.skipped, "a change makes a new automatic backup");
            autoBackup.closeBackups = false; autoBackup.folder = ""; autoBackup.keep = 10;
        }],
        ["restore zip", () => {
            const meta = Api.get("meta", null), dir = meta.path.substring(0, meta.path.lastIndexOf("/"));
            const zip = Api.call("backupZip", dir + "/selftest-restore.zip");
            const r = zip ? win.restoreZip("file://" + zip.path, "file://" + dir + "/restored") : null;
            check(r && r.path.indexOf("/restored/") > 0 && r.title === meta.title, "a zip backup restores into the chosen folder and opens (" + (r ? r.path : "failed") + ")");
            check(Api.get("binder", []).some(x => x.title === "Arrival"), "the restored project has its documents");
            win.openPath(meta.path);
            check(Api.get("meta", null).path === meta.path, "the original opens again");
        }],
        ["back and forward", () => {
            win.requestActivate();
            ws().select(rowId("Arrival"), "editor");
            const a = ed().firstArea();
            a.forceActiveFocus();
            a.cursorPosition = 7;
            ws().select(rowId("The Storm"), "corkboard");
        }],
        // (One step per place: changes in one go count as one place.)
        ["back and forward", () => { ws().select(rowId("The Keeper")); }],
        ["back and forward", () => {
            check(ws().canGoBack && !ws().canGoForward, "places visited are remembered");
            ed().firstArea().forceActiveFocus();
            input.key(win, Qt.Key_Left, Qt.AltModifier);
            check(ws().viewMode === "corkboard" && ws().current.title === "The Storm", "Alt+← goes back to the last place, in its view, even from the text (" + ws().viewMode + ", " + ws().current.title + ")");
            input.key(win, Qt.Key_Left, Qt.AltModifier);
        }],
        ["back and forward", () => {
            const a = ed().firstArea();
            check(ws().viewMode === "editor" && ws().current.title === "Arrival", "and again, to the document before");
            check(a.activeFocus && a.cursorPosition === 7, "with the caret where it was (" + a.cursorPosition + ")");
            input.click(win, Qt.point(win.width / 2, win.height / 2), Qt.ForwardButton);
            check(ws().viewMode === "corkboard" && ws().current.title === "The Storm" && ws().canGoForward, "the mouse's Forward button goes forward");
            ws().select(rowId("Arrival"));
        }],
        ["back and forward", () => {
            check(!ws().canGoForward && ws().canGoBack, "going somewhere new drops the Forward steps");
        }],
        ["favourites", () => {
            ws().select(rowId("The Keeper"));
            input.key(win, Qt.Key_D, Qt.ControlModifier | Qt.ShiftModifier);
            const b = ws().binderRef();
            check(b.favorites.length === 1 && b.favorites[0].title === "The Keeper" && b.favorites[0].where === "Manuscript › The Storm", "Ctrl+Shift+D adds the item to Favourites (" + JSON.stringify(b.favorites) + ")");
            check(b.rows.find(r => r.title === "The Keeper").favorite, "and the binder marks it with a star");
            ws().select(rowId("Confession"));
        }],
        ["favourites", () => {
            const p = ws().binderRef().favoritePoint(0);
            input.click(win, p);
            check(ws().current.title === "The Keeper", "clicking a favourite opens it (" + ws().current.title + ")");
            input.key(win, Qt.Key_D, Qt.ControlModifier | Qt.ShiftModifier);
            check(ws().binderRef().favorites.length === 0, "Ctrl+Shift+D again takes it off the list");
        }],
        ["sprint", () => {
            ws().select(rowId("Arrival"), "editor");
            sprint.durationMin = 1; sprint.goal = 3; sprint.start();
        }],
        ["sprint", () => {
            const a = ed().firstArea();
            a.forceActiveFocus(); a.insert(a.length, " alpha beta gamma delta");
        }],
        ["sprint", () => {
            sprint.finish(false);
            check(sprint.lastSprint !== null && sprint.lastSprint.words === 4, "a sprint counts the words typed (" + (sprint.lastSprint ? sprint.lastSprint.words : "none") + ")");
            check(Api.get("sprints", null).count >= 1, "the sprint is saved");
            sprint.close();
        }],
        // Last: it adds a folder of twelve scenes to the sample.
        ["long composite", () => {
            const ms = Api.call("rootId", "manuscript"), f = Api.call("add", ms, "folder", "Many Scenes", true);
            for (let i = 1; i <= 12; ++i) {
                const d = Api.call("add", f, "text", "Part " + i, true);
                Api.call("setText", d, "Words of part " + i + ".");
            }
            ws().select(f, "editor");
            check(ed().docs.length === 13 && !ed().built && ed().firstArea() !== null, "a long composite shows its first parts at once and builds the rest after");
            check(ed().built, "anything that needs every part (find, word lists) builds the rest first");
        }],
        ["long composite", () => {
            ws().select(rowId("Many Scenes"), "corkboard");
            ws().viewMode = "editor";
        }],
        ["long composite", () => {
            const ed2 = ed();
            check(ed2.built && ed2.editors().length === 12 && ed2.editors()[11].text === "Words of part 12.", "and the rest arrive by themselves (the folder itself has no text) (" + ed2.editors().length + ")");
        }]
    ]

    Timer {
        id: runner
        interval: 700
        repeat: true
        onTriggered: {
            if (st.step >= st.steps.length) {
                stop();
                st.log((st.failures ? "SELFTEST FAILED: " : "SELFTEST OK: ") + st.passes + " passed, " + st.failures + " failed");
                Qt.exit(st.failures ? 1 : 0);
                return;
            }
            const s = st.steps[st.step++];
            st.current = s[0];
            try { s[1](); } catch (e) { st.check(false, "threw " + e); }
        }
    }
    function start() { runner.start(); }
}
