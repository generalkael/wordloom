import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import com.wordloom.app

// Index cards for the children of the selected folder (or the siblings of
// the selected document). Synopses are edited right on the card.
//
// A board is a grid in binder order (drag to reorder), or freeform: cards
// stay wherever you drop them and the binder order doesn't change. Notes
// are sticky cards that live only on the board, not in the binder; one can
// be turned into a document. The board colour is the project's (core
// boards.rs keeps the layouts, notes and colour).
Rectangle {
    id: cb
    color: boardColor

    property string nodeId: ""
    property var node: null
    property bool active: false
    property var cards: []                  // binder items, in binder order
    property var board: ({ freeform: false, positions: {}, notes: [], color: null })
    // Everything on the board: the cards, then the notes ({note: true, …}).
    // Set once per reload, so the cards are rebuilt once.
    property var items: []
    readonly property bool freeform: board.freeform
    property string containerId: ""
    property string containerTitle: ""
    // Shared by every board and remembered between runs.
    readonly property int cardWidth: Theme.cardWidth
    function setCardWidth(w) { Theme.cardWidth = Math.round(Math.max(170, Math.min(360, w))); }
    // Ctrl+scroll: one size step per notch (touchpads add up).
    property real wheelAcc: 0
    function zoomWheel(e) {
        wheelAcc += e.angleDelta.y;
        while (wheelAcc >= 120) { setCardWidth(cardWidth + 20); wheelAcc -= 120; }
        while (wheelAcc <= -120) { setCardWidth(cardWidth - 20); wheelAcc += 120; }
        e.accepted = true;
    }
    readonly property real cardHeight: cardWidth * 0.66
    signal openRequested(string id)
    signal selectRequested(string id)

    // ---- colours ----
    // A colour value from the core: "#rrggbb", "cork" (the theme's) or null.
    function colorFor(c) { return c && c !== "cork" ? c : Theme.cork; }
    readonly property color boardColor: colorFor(board.color)
    readonly property bool boardIsLight: (0.299 * boardColor.r + 0.587 * boardColor.g + 0.114 * boardColor.b) > 0.5
    readonly property color boardText: boardIsLight ? "#3b2b17" : "#f1ece4"
    readonly property var boardColors: [
        { name: qsTr("Cork"), c: "cork" }, { name: qsTr("Walnut"), c: "#7a5a3a" }, { name: qsTr("Slate"), c: "#5b6770" },
        { name: qsTr("Felt Green"), c: "#3f6b4e" }, { name: qsTr("Navy"), c: "#2f4566" }, { name: qsTr("Burgundy"), c: "#6e3240" },
        { name: qsTr("Linen"), c: "#e8e1d3" }, { name: qsTr("Whiteboard"), c: "#f4f5f2" }
    ]
    readonly property var noteColors: [
        { id: "yellow", name: qsTr("Yellow"), light: "#fff3a8", dark: "#5a5230" },
        { id: "pink", name: qsTr("Pink"), light: "#ffd6e0", dark: "#5a3842" },
        { id: "blue", name: qsTr("Blue"), light: "#d3e8ff", dark: "#2f4558" },
        { id: "green", name: qsTr("Green"), light: "#d8f2cb", dark: "#34503a" },
        { id: "white", name: qsTr("White"), light: "#ffffff", dark: "#3a3c40" }
    ]
    function noteColor(id) { const c = noteColors.find(n => n.id === id) || noteColors[0]; return Theme.dark ? c.dark : c.light; }
    // This board's own colour ("" = the same as other boards).
    function setBoardColor(c) { Api.call("setBoardColor", containerId, c); }
    // This board's colour on every board (and as the default for new ones).
    function useColorEverywhere() { Api.call("setAllBoardsColor", board.color || ""); }
    // "#rrggbb" (no alpha) for a colour.
    function hex(c) { const h = (v) => ("0" + Math.round(v * 255).toString(16)).slice(-2); return "#" + h(c.r) + h(c.g) + h(c.b); }

    readonly property int rev: Wordloom.revision
    onRevChanged: if (active) reload()
    onActiveChanged: if (active) reload()
    onNodeIdChanged: if (active) reload()

    function reload() {
        if (!node) { cards = []; items = []; containerId = ""; return; }
        let cid = node.id;
        if (node.child_count === 0 && !node.is_root) {
            // A leaf: show it among its siblings.
            cid = parentOf(node.id);
        }
        if ((cid || "") !== containerId) picked = [];
        containerId = cid || "";
        const info = containerId ? Api.get("nodeInfo", null, containerId) : null;
        containerTitle = info ? info.title : "";
        const b = containerId ? Api.get("board", board, containerId) : ({ freeform: false, positions: {}, notes: [], color: board.color });
        const c = containerId ? Api.get("children", [], containerId) : [];
        board = b;
        cards = c;
        items = c.concat(b.notes.map(n => Object.assign({ note: true }, n)));
        picked = picked.filter(id => items.some(it => it.id === id));
    }

    // ---- freeform layout. Positions are in board units: pixels at the
    // standard card width (230), so the Card size slider scales the layout.
    readonly property real unit: cardWidth / 230
    readonly property real baseW: 230
    readonly property real baseH: 230 * 0.66
    readonly property real gapU: 16
    readonly property int margin: 12
    // Slots for unplaced cards fill the board's width (the board, not the
    // view, so a note added on the grid lands sensibly too).
    readonly property int freeColumns: Math.max(1, Math.floor((cb.width - 2 * margin - 14 + gapU * unit) / ((baseW + gapU) * unit)))
    // Where every item sits ({id: {x, y}} in board units). Cards that were
    // never placed take the first grid slots no placed card or note covers.
    readonly property var spots: layoutItems(items, board.positions, freeColumns)
    function overlaps(r, x, y) { return x < r.x + baseW + gapU / 2 && r.x < x + baseW + gapU / 2 && y < r.y + baseH + gapU / 2 && r.y < y + baseH + gapU / 2; }
    function layoutItems(list, positions, cols) {
        const out = {}, taken = [];
        for (const it of list) {
            const p = it.note ? [it.x, it.y] : positions[it.id];
            if (p) { out[it.id] = { x: p[0], y: p[1] }; taken.push(out[it.id]); }
        }
        let slot = 0;
        for (const it of list) {
            if (out[it.id]) continue;
            out[it.id] = freeSlot(taken, cols, slot);
            slot = out[it.id].slot + 1;
            taken.push(out[it.id]);
        }
        return out;
    }
    function freeSlot(taken, cols, from) {
        for (let s = from || 0; ; ++s) {
            const x = (s % cols) * (baseW + gapU), y = Math.floor(s / cols) * (baseH + gapU);
            if (!taken.some(r => overlaps(r, x, y))) return { x: x, y: y, slot: s };
        }
    }
    // The first empty slot on the board (for a new note).
    function nextFreeSpot() { return freeSlot(Object.values(spots), freeColumns, 0); }
    function setFreeform(on) {
        if (on === freeform || !containerId) return;
        Api.call("setBoardFreeform", containerId, on);
    }
    // Board units → pixels inside the freeform view's content, and back.
    function toView(u) { return margin + u * unit; }
    function toUnits(px) { return Math.max(0, (px - margin) / unit); }
    // The card or note at a point of the freeform view's content, or "".
    // `skip`: an id, or a list of ids, to look through (what's being dragged).
    function idAtBoard(px, py, skip) {
        const x = toUnits(px), y = toUnits(py), skips = Array.isArray(skip) ? skip : [skip];
        const hit = freeOrder.slice().reverse().find(it => { const p = spots[it.id]; return skips.indexOf(it.id) < 0 && p && x >= p.x && x <= p.x + baseW && y >= p.y && y <= p.y + baseH; });
        return hit ? hit.id : "";
    }
    // Freeform: while a card is dragged over the middle of a folder card,
    // that folder (dropping moves the card into it, as on the grid).
    property string freeDropFolder: ""
    function updateFreeDrag(id, scenePos) {
        const p = freeContent.mapFromItem(null, scenePos.x, scenePos.y);
        const under = idAtBoard(p.x, p.y, groupLead === id ? picked : id);
        const card = under ? cards.find(c => c.id === under) : null;
        const fx = card ? (toUnits(p.x) - spots[under].x) / baseW : 0;
        freeDropFolder = card && card.kind === "folder" && fx > 0.3 && fx < 0.7 ? under : "";
    }
    // Drop a dragged freeform card at its spot, or into a folder card (a
    // note goes to that folder's board).
    function finishFreeDrag(id, px, py) {
        const folder = freeDropFolder;
        freeDropFolder = "";
        if (groupLead === id) {
            lastLead = id;
            groupLead = ""; groupDx = 0; groupDy = 0;
            if (folder) return Api.call("dropOnBoardFolder", containerId, picked, folder) !== undefined;
            return moveGroup(px - toView(spots[id].x), py - toView(spots[id].y));
        }
        const note = !cards.some(c => c.id === id);
        if (folder && note) return Api.call("moveBoardNote", containerId, id, folder, 1e6) !== undefined;
        if (folder) return Api.call("dropOn", id, folder, "inside") !== undefined;
        return placeAt(id, px, py);
    }
    function placeAt(id, px, py) { return Api.call("placeOnBoard", containerId, id, snap(toUnits(px)), snap(toUnits(py))) !== undefined; }

    // ---- several at once (freeform): Ctrl+click picks and unpicks cards
    // and notes, dragging on the empty board picks those inside the box
    // (Ctrl adds to them). Dragging one of them moves them all.
    property var picked: []
    function isPicked(id) { return picked.indexOf(id) >= 0; }
    function togglePick(id) {
        // The highlighted card (if the board has the keys) joins the first
        // time something is added.
        let p = picked.length === 0 && boardFocused && keyId && keyId !== id ? [keyId] : picked.slice();
        const i = p.indexOf(id);
        if (i >= 0) p.splice(i, 1); else p.push(id);
        picked = p;
        keyId = id;
    }
    // A click on a card or note: Ctrl on a freeform board picks or unpicks
    // it; otherwise it becomes the one highlighted (and a card selected).
    function tapCard(id, modifiers, face) {
        if (freeform && (modifiers & Qt.ControlModifier)) {
            togglePick(id);
            focusBoard();
            return;
        }
        if (freeform) picked = [];
        keyId = id;
        if (cards.some(c => c.id === id)) selectRequested(id);
        if (face && face.focusView) face.focusView.forceActiveFocus();
    }
    function pickAll() { picked = freeOrder.map(it => it.id); }
    // The cards and notes touching the box between two points of the
    // board (pixels), added to `base`.
    function pickInBox(a, b, base) {
        const x0 = toUnits(Math.min(a.x, b.x)), x1 = toUnits(Math.max(a.x, b.x));
        const y0 = toUnits(Math.min(a.y, b.y)), y1 = toUnits(Math.max(a.y, b.y));
        const inside = freeOrder.filter(it => { const p = spots[it.id]; return p.x <= x1 && p.x + baseW >= x0 && p.y <= y1 && p.y + baseH >= y0; }).map(it => it.id);
        picked = base.concat(inside.filter(id => base.indexOf(id) < 0));
        if (inside.length) keyId = inside[0];
    }
    // While a picked card is dragged: it, and how far it has gone (pixels),
    // so the others follow.
    property string groupLead: ""
    property real groupDx: 0
    property real groupDy: 0
    function startGroupDrag(id) { if (picked.length > 1 && isPicked(id)) groupLead = id; }
    // Move every picked card and note by (dx, dy) pixels, as one undo
    // step; none goes past the board's top or left edge. With Snap to Grid
    // the one dragged lands on the grid and the rest keep their places
    // around it.
    function moveGroup(dx, dy) {
        const ids = picked.filter(id => spots[id]);
        if (!ids.length) return false;
        let du = dx / unit, dv = dy / unit;
        const lead = spots[groupLeadFor(ids)];
        du = snap(lead.x + du) - lead.x; dv = snap(lead.y + dv) - lead.y;
        du = Math.max(du, -Math.min(...ids.map(id => spots[id].x)));
        dv = Math.max(dv, -Math.min(...ids.map(id => spots[id].y)));
        if (Math.abs(du) < 0.01 && Math.abs(dv) < 0.01) return false;
        return Api.call("placeManyOnBoard", containerId, ids.map(id => [id, spots[id].x + du, spots[id].y + dv])) !== undefined;
    }
    property string lastLead: ""
    function groupLeadFor(ids) { return ids.indexOf(lastLead) >= 0 ? lastLead : (ids.indexOf(keyId) >= 0 ? keyId : ids[0]); }
    // Snap to Grid (Arrange menu): board units onto a 20-unit grid.
    readonly property int gridStep: 20
    function snap(u) { return Theme.boardSnap ? Math.round(u / gridStep) * gridStep : u; }
    // Add a note; in freeform at (x, y) units, else (or with no spot) in the
    // first free slot. Returns its id and focuses its text.
    function addNote(at) {
        if (!containerId) return "";
        const p = at ? { x: snap(at.x), y: snap(at.y) } : nextFreeSpot();
        const id = Api.call("addBoardNote", containerId, p.x, p.y, "");
        // The board has already reloaded (the call bumps the revision).
        if (id) { keyId = id; Qt.callLater(() => { const f = noteEditor(id); if (f) f.forceActiveFocus(); }); }
        return id || "";
    }
    function noteToDocument(noteId) {
        const id = Api.call("boardNoteToItem", containerId, noteId);
        if (id) keyId = id;
        return id || "";
    }
    // Reading order: rows top to bottom (a card within half a card's height
    // of a row's first card joins the row), left to right within a row.
    // For the arrow keys, and Order Binder by Board.
    readonly property var freeOrder: {
        const s = spots;
        const list = items.filter(it => s[it.id]).sort((a, b) => s[a.id].y - s[b.id].y || s[a.id].x - s[b.id].x);
        const out = [];
        for (let i = 0; i < list.length;) {
            const top = s[list[i].id].y;
            let j = i;
            while (j < list.length && s[list[j].id].y - top < baseH / 2) ++j;
            out.push(...list.slice(i, j).sort((a, b) => s[a.id].x - s[b.id].x));
            i = j;
        }
        return out;
    }
    // Arrange ▸ Order Binder by Board: the cards (not notes) as they read.
    function orderBinder() { Api.call("orderChildren", containerId, freeOrder.filter(it => !it.note).map(it => it.id)); }

    // ---- grid drag and drop: move a card before / after another, or into a folder card ----
    property string dragId: ""
    property string dragTitle: ""
    property point dragPos: Qt.point(0, 0)   // pointer, in cb's coordinates
    property int dropIndex: -1
    property string dropMode: ""             // "before", "after", "inside" or "" (no move)
    function startDrag(id, title) { dragId = id; dragTitle = title; dropIndex = -1; dropMode = ""; }
    // `scenePos`: the pointer in window coordinates.
    // Notes come after the cards and are dragged among the notes; a note
    // dropped on the middle of a folder card goes to that folder's board.
    readonly property bool draggingNote: dragId !== "" && !cards.some(c => c.id === dragId)
    function updateDrag(scenePos) {
        dragPos = cb.mapFromItem(null, scenePos.x, scenePos.y);
        const p = grid.contentItem.mapFromItem(null, scenePos.x, scenePos.y);
        let i = grid.indexAt(p.x, p.y);
        let mode = "";
        if (draggingNote) {
            const first = cards.length;
            const item = i >= 0 ? grid.itemAtIndex(i) : null;
            const fx = item ? (p.x - item.x) / item.width : 0.5;
            if (i >= 0 && i < first) {
                if (cards[i].kind === "folder" && fx > 0.3 && fx < 0.7) mode = "inside";
                else { i = first; mode = "before"; }   // over a card: the start of the notes
            } else if (i >= first) mode = fx < 0.5 ? "before" : "after";
            else if (p.y >= 0) { i = items.length - 1; mode = "after"; }
            const from = items.findIndex(c => c.id === dragId);
            if (mode !== "inside" && (i === from || (mode === "after" && i === from - 1) || (mode === "before" && i === from + 1))) mode = "";
            dropIndex = i;
            dropMode = mode;
            return;
        }
        if (i < 0 || i >= cards.length) {
            // Past the last card (or over a note): drop at the end.
            if (cards.length && (i >= cards.length || p.y >= 0)) { i = cards.length - 1; mode = "after"; }
            else i = -1;
        } else {
            const item = grid.itemAtIndex(i);
            const fx = item ? (p.x - item.x) / item.width : 0.5;
            if (cards[i].kind === "folder" && fx > 0.3 && fx < 0.7) mode = "inside";
            else mode = fx < 0.5 ? "before" : "after";
        }
        // Dropping a card next to (or onto) itself changes nothing.
        const from = cards.findIndex(c => c.id === dragId);
        if (i === from || (mode === "after" && i === from - 1) || (mode === "before" && i === from + 1)) mode = "";
        dropIndex = i;
        dropMode = mode;
    }
    // ---- keyboard: ← → ↑ ↓ Home End move a highlight between cards, Enter
    // opens (a folder on the board, a document in the editor), Backspace
    // goes up a folder, Ctrl+arrows move the card (in the binder on a grid,
    // across the board when freeform), Delete trashes it (or deletes a note) ----
    property string keyId: ""                // the highlighted card or note
    property string keyAfterReload: ""       // highlight this card once the board reloads
    readonly property int columns: Math.max(1, Math.floor(grid.width / grid.cellWidth))
    readonly property int keyIndex: items.findIndex(c => c.id === keyId)
    onItemsChanged: {
        const want = [keyAfterReload, keyId, nodeId].find(id => id && items.some(c => c.id === id));
        keyId = want || (items.length ? items[0].id : "");
        keyAfterReload = "";
    }
    function highlight(i) {
        if (!items.length) return;
        i = Math.max(0, Math.min(items.length - 1, i));
        keyId = items[i].id;
        if (freeform) revealFree(keyId); else grid.positionViewAtIndex(i, GridView.Contain);
    }
    function revealFree(id) {
        const p = spots[id];
        if (!p) return;
        const x = toView(p.x), y = toView(p.y);
        if (x < freeView.contentX) freeView.contentX = Math.max(0, x - margin);
        else if (x + cardWidth > freeView.contentX + freeView.width) freeView.contentX = x + cardWidth + margin - freeView.width;
        if (y < freeView.contentY) freeView.contentY = Math.max(0, y - margin);
        else if (y + cardHeight > freeView.contentY + freeView.height) freeView.contentY = y + cardHeight + margin - freeView.height;
    }
    function handleKey(e) {
        const i = keyIndex, ctrl = e.modifiers & Qt.ControlModifier;
        const it = i >= 0 ? items[i] : null;
        const arrow = [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].indexOf(e.key);
        if (arrow >= 0) {
            if (freeform) {
                if (ctrl) {
                    // Nudge the card or note a little (all of them, when
                    // several are picked).
                    if (it && picked.length > 1 && isPicked(it.id)) {
                        const d = 20 * unit;
                        lastLead = it.id;
                        moveGroup([-d, d, 0, 0][arrow], [0, 0, -d, d][arrow]);
                    } else if (it && spots[it.id]) {
                        const p = spots[it.id], d = 20;
                        const dx = [-d, d, 0, 0][arrow], dy = [0, 0, -d, d][arrow];
                        Api.call("placeOnBoard", containerId, it.id, Math.max(0, snap(p.x + dx)), Math.max(0, snap(p.y + dy)));
                    }
                } else {
                    const order = freeOrder, k = order.findIndex(c => c.id === keyId);
                    const next = order[Math.max(0, Math.min(order.length - 1, k < 0 ? 0 : k + (arrow % 2 === 0 ? -1 : 1)))];
                    if (next) { keyId = next.id; revealFree(next.id); }
                }
                return true;
            }
            const step = [-1, 1, -columns, columns][arrow];
            // Ctrl: one place earlier or later (the binder's order).
            if (ctrl) { if (it && !it.note) Api.call("shift", it.id, step < 0 ? -1 : 1); }
            else highlight(i < 0 ? 0 : i + step);
            return true;
        }
        if (freeform && e.key === Qt.Key_Escape && picked.length) { picked = []; return true; }
        if (freeform && e.key === Qt.Key_A && ctrl) { pickAll(); return true; }
        if (e.key === Qt.Key_Home) { highlight(0); return true; }
        if (e.key === Qt.Key_End) { highlight(items.length - 1); return true; }
        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && it) {
            if (it.note) { const f = noteEditor(it.id); if (f) f.forceActiveFocus(); }
            else if (it.child_count > 0) selectRequested(it.id); else openRequested(it.id);
            return true;
        }
        if (e.key === Qt.Key_Backspace) {
            const up = parentOf(containerId);
            if (up) { keyAfterReload = containerId; selectRequested(up); }
            return true;
        }
        if (e.key === Qt.Key_Delete && it) {
            const next = items[i + 1] || items[i - 1];
            keyAfterReload = next ? next.id : "";
            if (it.note) Api.call("removeBoardNote", containerId, it.id);
            else Api.call("trash", it.id);
            return true;
        }
        return false;
    }
    function focusBoard() { (freeform ? freeView : grid).forceActiveFocus(); }
    readonly property bool boardFocused: grid.activeFocus || freeView.activeFocus

    // The shown card or note for an id (in the grid, or on the freeform board).
    function cardItem(id) {
        if (freeform) {
            for (let k = 0; k < freeRep.count; ++k) { const d = freeRep.itemAt(k); if (d && d.modelData.id === id) return d.face; }
            return null;
        }
        const i = items.findIndex(c => c.id === id);
        const cell = i >= 0 ? grid.itemAtIndex(i) : null;
        return cell ? cell.face : null;
    }
    function noteEditor(id) { const f = cardItem(id); return f ? f.textEditor : null; }

    // A spot on card `i` that isn't text (just inside its left edge), in
    // window coordinates: where a real drag can start.
    function cardGrip(i) { const it = i >= 0 && i < items.length ? cardItem(items[i].id) : null; return it ? it.mapToItem(null, 4, it.height / 2) : null; }
    // A point on card `i` (fraction `fx` across it), in window coordinates.
    // A point of the freeform board (pixels), in window coordinates.
    function boardPoint(px, py) { return freeContent.mapToItem(null, px, py); }
    function cardPoint(i, fx) { const it = i >= 0 && i < items.length ? cardItem(items[i].id) : null; return it ? it.mapToItem(null, it.width * fx, it.height / 2) : null; }
    // Returns true if the card moved.
    function finishDrag() {
        if (draggingNote) {
            const id = dragId, mode = dropMode, at = dropIndex;
            dragId = ""; dropIndex = -1; dropMode = "";
            if (!mode || at < 0) return false;
            if (mode === "inside") return Api.call("moveBoardNote", containerId, id, cards[at].id, 1e6) !== undefined;
            const from = items.findIndex(c => c.id === id) - cards.length;
            let to = at - cards.length + (mode === "after" ? 1 : 0);
            if (from < to) --to;   // its own place closes up first
            return Api.call("moveBoardNote", containerId, id, containerId, Math.max(0, to)) !== undefined;
        }
        const id = dragId, mode = dropMode, target = dropIndex >= 0 && dropIndex < cards.length ? cards[dropIndex].id : "";
        dragId = ""; dropIndex = -1; dropMode = "";
        if (!id || !mode || !target) return false;
        return Api.call("dropOn", id, target, mode) !== undefined;
    }

    // Find the parent by scanning the binder (cheap for typical projects).
    function parentOf(id) {
        const rows = Api.get("binder", []);
        const i = rows.findIndex(r => r.id === id);
        for (let j = i - 1; j >= 0; --j) if (rows[j].depth < rows[i].depth) return rows[j].id;
        return "";
    }

    ColorDialog {
        id: boardColorDialog
        title: qsTr("Corkboard Colour")
        onAccepted: cb.setBoardColor(cb.hex(selectedColor))
    }
    Menu {
        id: colorMenu
        // Presets and a custom colour set this board; "Same as Other Boards"
        // follows the project's colour; the last item copies this board's
        // colour to every board.
        MenuItem {
            text: qsTr("Same as Other Boards")
            checkable: true
            checked: !cb.board.own_color
            indicator: Rectangle {
                x: 8; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 3
                color: cb.colorFor(cb.board.default_color); border.color: Theme.border; border.width: parent.checked ? 2 : 1
            }
            onTriggered: cb.setBoardColor("")
        }
        MenuSeparator {}
        Repeater {
            model: cb.boardColors
            delegate: MenuItem {
                required property var modelData
                text: modelData.name
                checkable: true
                checked: cb.board.own_color === modelData.c
                indicator: Rectangle {
                    x: 8; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 3
                    color: cb.colorFor(modelData.c); border.color: Theme.border; border.width: parent.checked ? 2 : 1
                }
                onTriggered: cb.setBoardColor(modelData.c)
            }
        }
        MenuItem { text: qsTr("Custom Colour…"); onTriggered: { boardColorDialog.selectedColor = cb.boardColor; boardColorDialog.open(); } }
        MenuSeparator {}
        MenuItem { text: qsTr("Use This Colour on All Boards"); onTriggered: cb.useColorEverywhere() }
    }
    Menu {
        id: arrangeMenu
        MenuItem { text: qsTr("Tidy Up"); onTriggered: Api.call("tidyBoard", cb.containerId) }
        MenuItem { text: qsTr("Order Binder by Board"); onTriggered: cb.orderBinder() }
        MenuSeparator {}
        MenuItem { text: qsTr("Snap to Grid"); checkable: true; checked: Theme.boardSnap; onTriggered: Theme.boardSnap = !Theme.boardSnap }
        MenuItem { text: qsTr("Select All (Ctrl+A)"); onTriggered: { cb.pickAll(); cb.focusBoard(); } }
    }
    // Right-click on the empty board.
    Menu {
        id: boardMenu
        property point at: Qt.point(0, 0)   // board units (freeform)
        MenuItem { text: qsTr("New Card"); enabled: cb.containerId !== ""; onTriggered: cb.addCard(cb.freeform ? boardMenu.at : null) }
        MenuItem { text: qsTr("New Note"); enabled: cb.containerId !== ""; onTriggered: cb.addNote(cb.freeform ? boardMenu.at : null) }
        MenuSeparator {}
        MenuItem { text: qsTr("Freeform"); checkable: true; checked: cb.freeform; onTriggered: cb.setFreeform(!cb.freeform) }
        MenuItem { visible: cb.freeform; height: visible ? implicitHeight : 0; text: qsTr("Tidy Up"); onTriggered: Api.call("tidyBoard", cb.containerId) }
        MenuItem { visible: cb.freeform; height: visible ? implicitHeight : 0; text: qsTr("Order Binder by Board"); onTriggered: cb.orderBinder() }
        MenuItem { text: qsTr("Board Colour…"); onTriggered: colorMenu.popup() }
    }
    // A new binder card; on a freeform board at `at` (board units).
    function addCard(at) {
        const id = Api.call("add", containerId, "", "", true);
        if (!id) return "";
        if (at) Api.call("placeOnBoard", containerId, id, snap(at.x), snap(at.y));
        selectRequested(id);
        return id;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: Qt.darker(cb.boardColor, 1.08)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 6
                Label { text: "▦  " + cb.containerTitle; font.bold: true; color: cb.boardText; elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 40 }
                // Grid / Freeform
                Row {
                    Repeater {
                        model: [{ free: false, label: qsTr("Grid"), tip: qsTr("Cards in binder order; drag to reorder") },
                                { free: true, label: qsTr("Freeform"), tip: qsTr("Put cards anywhere; the binder order stays as it is") }]
                        delegate: Button {
                            required property var modelData
                            text: modelData.label
                            checkable: true
                            checked: cb.freeform === modelData.free
                            highlighted: checked
                            enabled: cb.containerId !== ""
                            focusPolicy: Qt.NoFocus
                            onClicked: cb.setFreeform(modelData.free)
                            ToolTip.visible: hovered
                            ToolTip.text: modelData.tip
                        }
                    }
                }
                Button {
                    id: arrangeButton
                    visible: cb.freeform
                    text: qsTr("Arrange ▾")
                    focusPolicy: Qt.NoFocus
                    onClicked: arrangeMenu.popup(arrangeButton, 0, arrangeButton.height)
                }
                Label { visible: cb.width > 760; text: qsTr("Card size"); color: cb.boardText }
                Slider { visible: cb.width > 640; from: 170; to: 360; value: cb.cardWidth; onMoved: cb.setCardWidth(value); Layout.preferredWidth: 110; focusPolicy: Qt.NoFocus }
                Button {
                    text: qsTr("+ Card")
                    enabled: cb.containerId !== ""
                    focusPolicy: Qt.NoFocus
                    onClicked: cb.addCard(null)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("A new document in this folder")
                }
                Button {
                    text: qsTr("+ Note")
                    enabled: cb.containerId !== ""
                    focusPolicy: Qt.NoFocus
                    onClicked: cb.addNote(null)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("A sticky note on this board only (not in the binder)")
                }
                Button {
                    id: colorButton
                    focusPolicy: Qt.NoFocus
                    implicitWidth: 34
                    onClicked: colorMenu.popup(colorButton, 0, colorButton.height)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Board colour")
                    contentItem: Item {
                        Rectangle { anchors.centerIn: parent; width: 16; height: 16; radius: 3; color: cb.boardColor; border.color: cb.boardText; border.width: 1 }
                    }
                }
            }
        }

        // ---- grid ----
        GridView {
            id: grid
            visible: !cb.freeform
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            clip: true
            cellWidth: cb.cardWidth + 16
            cellHeight: cb.cardHeight + 16
            model: cb.freeform ? [] : cb.items
            ScrollBar.vertical: ScrollBar {}
            activeFocusOnTab: !cb.freeform
            Keys.onPressed: (e) => { if (cb.handleKey(e)) e.accepted = true; }
            WheelHandler { acceptedModifiers: Qt.ControlModifier; onWheel: (e) => cb.zoomWheel(e) }
            // Shows that the keys go to the board.
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: grid.activeFocus ? 2 : 0
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                radius: 4
                z: -1
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: (ep) => { if (grid.indexAt(ep.position.x + grid.contentX, ep.position.y + grid.contentY) < 0) boardMenu.popup(); }
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                property alias face: cardFace
                width: grid.cellWidth
                height: grid.cellHeight
                CardFace {
                    id: cardFace
                    anchors.fill: parent
                    anchors.margins: 8
                    modelData: cell.modelData
                    cardIndex: cell.index
                    focusView: grid
                }
            }
        }

        // ---- freeform ----
        Flickable {
            id: freeView
            visible: cb.freeform
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // Room for every card, plus space to drag one further out.
            contentWidth: Math.max(width, freeContent.extentX + cb.cardWidth)
            contentHeight: Math.max(height, freeContent.extentY + cb.cardHeight)
            ScrollBar.vertical: ScrollBar {}
            ScrollBar.horizontal: ScrollBar {}
            activeFocusOnTab: cb.freeform
            interactive: false   // the mouse is for moving cards; wheel and scroll bars scroll
            Keys.onPressed: (e) => { if (cb.handleKey(e)) e.accepted = true; }
            WheelHandler {
                acceptedModifiers: Qt.NoModifier
                onWheel: (e) => {
                    const d = e.pixelDelta.y !== 0 ? e.pixelDelta.y : e.angleDelta.y / 2;
                    const dx = e.pixelDelta.x !== 0 ? e.pixelDelta.x : e.angleDelta.x / 2;
                    freeView.contentY = Math.max(0, Math.min(freeView.contentHeight - freeView.height, freeView.contentY - d));
                    freeView.contentX = Math.max(0, Math.min(freeView.contentWidth - freeView.width, freeView.contentX - dx));
                }
            }
            WheelHandler { acceptedModifiers: Qt.ControlModifier; onWheel: (e) => cb.zoomWheel(e) }
            WheelHandler {
                acceptedModifiers: Qt.ShiftModifier
                onWheel: (e) => freeView.contentX = Math.max(0, Math.min(freeView.contentWidth - freeView.width, freeView.contentX - e.angleDelta.y / 2))
            }

            Item {
                id: freeContent
                width: freeView.contentWidth
                height: freeView.contentHeight
                readonly property real extentX: { let m = 0; for (const id in cb.spots) m = Math.max(m, cb.toView(cb.spots[id].x) + cb.cardWidth); return m + cb.margin; }
                readonly property real extentY: { let m = 0; for (const id in cb.spots) m = Math.max(m, cb.toView(cb.spots[id].y) + cb.cardHeight); return m + cb.margin; }
                // Shows that the keys go to the board.
                Rectangle {
                    x: freeView.contentX + 2; y: freeView.contentY + 2
                    width: freeView.width - 4; height: freeView.height - 4
                    color: "transparent"
                    border.width: freeView.activeFocus ? 2 : 0
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                    radius: 4
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: freeView.forceActiveFocus()
                    onDoubleTapped: (ep) => { if (!cb.idAtBoard(ep.position.x, ep.position.y)) cb.addNote({ x: cb.toUnits(ep.position.x), y: cb.toUnits(ep.position.y) }); }
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: (ep) => {
                        if (cb.idAtBoard(ep.position.x, ep.position.y)) return;   // the card's own menu
                        boardMenu.at = Qt.point(cb.toUnits(ep.position.x), cb.toUnits(ep.position.y));
                        boardMenu.popup();
                    }
                }
                // Drag on the empty board: pick what's inside the box.
                HoverHandler { id: boardHover }
                DragHandler {
                    id: bandDrag
                    target: null
                    // Only from the empty board (where the pointer last was
                    // before the press), so cards keep their own drags.
                    enabled: active || !cb.idAtBoard(boardHover.point.position.x, boardHover.point.position.y)
                    acceptedButtons: Qt.LeftButton
                    property bool live: false
                    property var base: []
                    onActiveChanged: {
                        if (active) {
                            const p = centroid.pressPosition;
                            live = !cb.idAtBoard(p.x, p.y);
                            base = live && (centroid.modifiers & Qt.ControlModifier) ? cb.picked.slice() : [];
                            if (live) freeView.forceActiveFocus();
                        } else live = false;
                    }
                    onCentroidChanged: if (active && live) cb.pickInBox(centroid.pressPosition, centroid.position, base)
                }
                Rectangle {
                    visible: bandDrag.active && bandDrag.live
                    x: Math.min(bandDrag.centroid.pressPosition.x, bandDrag.centroid.position.x)
                    y: Math.min(bandDrag.centroid.pressPosition.y, bandDrag.centroid.position.y)
                    width: Math.abs(bandDrag.centroid.position.x - bandDrag.centroid.pressPosition.x)
                    height: Math.abs(bandDrag.centroid.position.y - bandDrag.centroid.pressPosition.y)
                    z: 20
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                    border.color: Theme.accent
                    border.width: 1
                }

                Repeater {
                    id: freeRep
                    model: cb.freeform ? cb.items : []
                    delegate: Item {
                        id: spot
                        required property var modelData
                        required property int index
                        property alias face: freeFace
                        readonly property var at: cb.spots[modelData.id] || { x: 0, y: 0 }
                        // Picked ones follow the one being dragged.
                        readonly property bool follows: cb.groupLead !== "" && cb.groupLead !== modelData.id && cb.isPicked(modelData.id)
                        x: cb.toView(at.x) + (follows ? cb.groupDx : 0)
                        y: cb.toView(at.y) + (follows ? cb.groupDy : 0)
                        // Dragging sets x and y directly; afterwards they
                        // follow the board again (so Undo moves it back).
                        function rebind() {
                            x = Qt.binding(() => cb.toView(at.x) + (follows ? cb.groupDx : 0));
                            y = Qt.binding(() => cb.toView(at.y) + (follows ? cb.groupDy : 0));
                        }
                        width: cb.cardWidth
                        height: cb.cardHeight
                        // The one being moved, and the highlighted one, on top.
                        z: freeFace.moving ? 10 : follows ? 9 : cb.keyId === modelData.id ? 2 : 1
                        CardFace {
                            id: freeFace
                            anchors.fill: parent
                            modelData: spot.modelData
                            cardIndex: spot.index
                            mover: spot
                            focusView: freeView
                        }
                    }
                }
            }
        }
    }

    // A card or a note. In the grid, dragging reorders (cards among cards in
    // the binder, notes among notes); on a freeform board it moves `mover`,
    // and dropping saves the spot.
    component CardFace: Rectangle {
        id: face
        required property var modelData
        property int cardIndex: 0
        property Item mover: null            // set on a freeform board
        property Item focusView: null
        readonly property bool isNote: !!modelData.note
        readonly property bool moving: dragger.active
        readonly property alias textEditor: synopsis
        color: isNote ? cb.noteColor(modelData.color) : Theme.card
        radius: 3
        border.width: !isNote && modelData.id === cb.nodeId ? 2 : 1
        border.color: !isNote && modelData.id === cb.nodeId ? Theme.accent : Qt.rgba(0, 0, 0, 0.18)
        opacity: modelData.id === cb.dragId ? 0.35 : (isNote || modelData.include_in_compile) ? 1 : 0.7

        // A shadow while it's lifted.
        Rectangle {
            visible: face.moving
            anchors.fill: parent
            anchors.margins: -1
            anchors.topMargin: 3
            anchors.leftMargin: 3
            z: -1
            radius: 4
            color: Qt.rgba(0, 0, 0, 0.25)
        }
        // Label colour strip (cards), or a pin (notes)
        Rectangle {
            visible: !face.isNote
            width: parent.width; height: 5; radius: 2
            color: face.modelData.label_color || "transparent"
        }
        Rectangle {
            visible: face.isNote
            anchors.horizontalCenter: parent.horizontalCenter
            y: -4
            width: 10; height: 10; radius: 5
            color: "#c0392b"
            border.color: Qt.rgba(0, 0, 0, 0.3)
        }
        // Ruled lines like an index card
        Repeater {
            model: face.isNote ? 0 : Math.max(0, Math.floor((face.height - 40) / 20))
            Rectangle { x: 8; width: face.width - 16; height: 1; y: 40 + index * 20; color: Theme.cardLine; required property int index }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            anchors.topMargin: 10
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                KindIcon { visible: !face.isNote; kind: face.modelData.kind || ""; size: 14 }
                TextField {
                    id: titleEdit
                    Layout.fillWidth: true
                    text: face.modelData.title
                    placeholderText: face.isNote ? qsTr("Note") : ""
                    font.bold: true
                    color: Theme.ink
                    background: null
                    padding: 0
                    selectByMouse: true
                    onEditingFinished: {
                        if (text === face.modelData.title) return;
                        if (face.isNote) Api.call("updateBoardNote", cb.containerId, face.modelData.id, text, synopsis.text);
                        else if (text.trim().length) Api.call("setField", face.modelData.id, "title", text);
                    }
                }
            }
            TextArea {
                id: synopsis
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property string saved: face.isNote ? face.modelData.text : face.modelData.synopsis
                text: saved
                placeholderText: face.isNote ? qsTr("Write a note…") : qsTr("Synopsis…")
                wrapMode: TextEdit.Wrap
                font.family: Theme.editorFont
                font.pixelSize: 13
                color: Theme.ink
                background: null
                padding: 0
                selectByMouse: true
                onActiveFocusChanged: {
                    if (activeFocus) { cb.keyId = face.modelData.id; return; }
                    if (text === saved) return;
                    if (face.isNote) Api.call("updateBoardNote", cb.containerId, face.modelData.id, titleEdit.text, text);
                    else Api.call("setField", face.modelData.id, "synopsis", text);
                }
                Keys.onEscapePressed: if (face.focusView) face.focusView.forceActiveFocus()
            }
            RowLayout {
                Layout.fillWidth: true
                visible: !face.isNote
                Label { text: face.modelData.status_name || ""; color: Theme.accent; font.pixelSize: 10; font.bold: true; font.capitalization: Font.AllUppercase }
                Item { Layout.fillWidth: true }
                Label {
                    text: face.isNote ? "" : Api.fmtNumber(face.modelData.total_words) + (face.modelData.target_words ? "/" + Api.fmtNumber(face.modelData.target_words) : "") + qsTr(" w")
                    color: Theme.subtext; font.pixelSize: 10
                }
                Label { visible: face.modelData.child_count > 0; text: "▤ " + face.modelData.child_count; color: Theme.subtext; font.pixelSize: 10 }
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: cb.tapCard(face.modelData.id, point.modifiers, face)
            onDoubleTapped: { if (face.isNote) synopsis.forceActiveFocus(); else cb.openRequested(face.modelData.id); }
        }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { cb.keyId = face.modelData.id; (face.isNote ? noteMenu : cardMenu).popup(); } }
        // Drag from anywhere that isn't text (the edges, the ruled area,
        // the footer, the icon); the title and text keep the mouse for
        // selecting text.
        DragHandler {
            id: dragger
            target: face.mover
            acceptedButtons: Qt.LeftButton
            cursorShape: active ? Qt.ClosedHandCursor : Qt.ArrowCursor
            xAxis.minimum: 0
            yAxis.minimum: 0
            onActiveChanged: {
                if (face.mover) {
                    if (active) { cb.keyId = face.modelData.id; cb.startGroupDrag(face.modelData.id); return; }
                    const m = face.mover;
                    cb.finishFreeDrag(face.modelData.id, m.x, m.y);
                    if (m) m.rebind();
                } else if (active) cb.startDrag(face.modelData.id, face.modelData.title || (face.isNote ? (face.modelData.text.split("\n")[0] || qsTr("Note")) : ""));
                else cb.finishDrag();
            }
            onCentroidChanged: {
                if (!active) return;
                if (!face.mover) cb.updateDrag(centroid.scenePosition);
                else {
                    if (cb.groupLead === face.modelData.id) {
                        const at = cb.spots[face.modelData.id];
                        cb.groupDx = face.mover.x - cb.toView(at.x);
                        cb.groupDy = face.mover.y - cb.toView(at.y);
                    }
                    cb.updateFreeDrag(face.modelData.id, centroid.scenePosition);
                }
            }
        }
        // The keyboard highlight.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            visible: cb.boardFocused && cb.keyId === face.modelData.id
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            radius: 5
        }
        // Picked (freeform, several at once).
        Rectangle {
            anchors.fill: parent
            visible: !!face.mover && cb.isPicked(face.modelData.id)
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
            border.width: 2
            border.color: Theme.accent
            radius: 3
        }
        // "Drop inside this folder" highlight.
        Rectangle {
            anchors.fill: parent
            visible: face.mover ? cb.freeDropFolder === face.modelData.id
                                : cb.dropMode === "inside" && cb.dropIndex === face.cardIndex
            color: "transparent"
            border.width: 3
            border.color: Theme.accent
            radius: 3
        }
        Menu {
            id: cardMenu
            MenuItem { text: qsTr("Open in Editor"); onTriggered: cb.openRequested(face.modelData.id) }
            MenuItem { text: qsTr("Move Earlier"); onTriggered: Api.call("shift", face.modelData.id, -1) }
            MenuItem { text: qsTr("Move Later"); onTriggered: Api.call("shift", face.modelData.id, 1) }
            MenuItem { text: qsTr("Duplicate"); onTriggered: Api.call("duplicate", face.modelData.id) }
            MenuItem { text: face.modelData.include_in_compile ? qsTr("Exclude from Compile") : qsTr("Include in Compile"); onTriggered: Api.call("setField", face.modelData.id, "include_in_compile", !face.modelData.include_in_compile) }
            MenuSeparator {}
            MenuItem { text: qsTr("Move to Trash"); onTriggered: Api.call("trash", face.modelData.id) }
        }
        Menu {
            id: noteMenu
            Repeater {
                model: cb.noteColors
                delegate: MenuItem {
                    required property var modelData
                    text: modelData.name
                    checkable: true
                    checked: face.modelData.color === modelData.id
                    indicator: Rectangle {
                        x: 8; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 3
                        color: Theme.dark ? modelData.dark : modelData.light; border.color: Theme.border; border.width: parent.checked ? 2 : 1
                    }
                    onTriggered: Api.call("colorBoardNote", cb.containerId, face.modelData.id, modelData.id)
                }
            }
            MenuSeparator {}
            MenuItem {
                text: qsTr("Make into Document")
                onTriggered: { synopsis.focus = false; cb.noteToDocument(face.modelData.id); }
            }
            MenuItem { text: qsTr("Delete Note"); onTriggered: Api.call("removeBoardNote", cb.containerId, face.modelData.id) }
        }
    }

    // Where the dragged card will land: a bar between cards.
    Rectangle {
        readonly property var item: cb.dropIndex >= 0 && (cb.dropMode === "before" || cb.dropMode === "after") ? grid.itemAtIndex(cb.dropIndex) : null
        visible: item !== null
        width: 4
        radius: 2
        color: Theme.accent
        // mapToItem isn't a live binding: read contentY so scrolling moves it.
        x: { grid.contentY; return item ? grid.contentItem.mapToItem(cb, item.x + (cb.dropMode === "after" ? item.width : 0), 0).x - 2 : 0; }
        y: { grid.contentY; return item ? grid.contentItem.mapToItem(cb, 0, item.y).y + 8 : 0; }
        height: item ? item.height - 16 : 0
        z: 5
    }
    // The card under the pointer while dragging.
    Rectangle {
        visible: cb.dragId !== ""
        // Beside the pointer, kept inside the board.
        x: Math.max(4, Math.min(cb.width - width - 4, cb.dragPos.x + 14))
        y: Math.max(4, Math.min(cb.height - height - 4, cb.dragPos.y + 10))
        width: Math.min(cb.cardWidth, 220)
        height: 28
        radius: 3
        color: Theme.card
        border.color: Theme.accent
        opacity: 0.9
        z: 6
        Label { anchors.fill: parent; anchors.margins: 6; text: cb.dragTitle; elide: Text.ElideRight; font.bold: true; color: Theme.ink; verticalAlignment: Text.AlignVCenter }
    }

    Label {
        anchors.centerIn: parent
        visible: cb.items.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: cb.containerId ? qsTr("No cards here yet — add one with + Card, or a note with + Note.") : qsTr("Select a folder to see its cards.")
        color: cb.boardText
    }
}
