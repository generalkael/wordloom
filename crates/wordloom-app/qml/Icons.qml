pragma Singleton
import QtQuick

// The binder's icon set, drawn as SVG so any icon can take any colour
// (Icon & Colour… in the binder). Each icon is 16×16 and uses up to four
// colours: {F} the main one, {D} a darker one for outlines, {L} a lighter
// one and {P} a pale one for paper and backgrounds. Uncoloured, an icon
// uses its own; coloured, all four come from the chosen colour.
QtObject {
    id: icons

    readonly property var set: ({
        folder: { name: qsTr("Folder"), F: "#e0a23c", D: "#a8701d", L: "#f3c770", P: "#fdf3df",
            svg: '<path d="M1.5 3.5h4.5l1.5 1.5h7v8.5h-13z" fill="{F}" stroke="{D}" stroke-linejoin="round"/><path d="M1.5 6.5h13" stroke="{L}"/>' },
        document: { name: qsTr("Document"), F: "#9aa4b1", D: "#7d8794", L: "#c9ced6", P: "#f7f4ec",
            svg: '<path d="M3.5 1.5h6l3 3v10h-9z" fill="{P}" stroke="{D}" stroke-linejoin="round"/><path d="M9.5 1.5v3h3" fill="none" stroke="{D}" stroke-linejoin="round"/><path d="M5.5 7.5h5M5.5 9.5h5M5.5 11.5h3.5" stroke="{F}"/>' },
        note: { name: qsTr("Note"), F: "#f2d35b", D: "#b8972a", L: "#e3bf3f", P: "#fdf6dc",
            svg: '<path d="M2.5 2.5h11v7l-4 4h-7z" fill="{F}" stroke="{D}" stroke-linejoin="round"/><path d="M13.5 9.5h-4v4" fill="{L}" stroke="{D}" stroke-linejoin="round"/>' },
        notebook: { name: qsTr("Notebook"), F: "#f2d35b", D: "#b8972a", L: "#e3bf3f", P: "#fdf6dc",
            svg: '<rect x="3" y="2.5" width="10" height="12" rx="1" fill="{F}" stroke="{D}"/><path d="M5.5 1.5v2.5M8 1.5v2.5M10.5 1.5v2.5" stroke="#7a6a4f" stroke-linecap="round"/><path d="M5 7.5h6M5 10h6M5 12.5h4" stroke="{D}"/>' },
        book: { name: qsTr("Book"), F: "#8a63b8", D: "#5e3f86", L: "#b498d6", P: "#efe8f7",
            svg: '<path d="M3 2.5h9.5v11H4a1 1 0 0 1-1-1z" fill="{F}" stroke="{D}" stroke-linejoin="round"/><path d="M3 12.5a1 1 0 0 1 1-1h8.5" fill="none" stroke="{P}"/><path d="M5.5 5h5" stroke="{P}" stroke-linecap="round"/>' },
        manuscript: { name: qsTr("Books"), F: "#c0703a", D: "#6aa36a", L: "#5b8fc7", P: "#f3e3d6",
            svg: '<rect x="2" y="2.5" width="3" height="11" rx=".5" fill="{F}"/><rect x="5.5" y="1.5" width="3" height="12" rx=".5" fill="{L}"/><rect x="9.2" y="3" width="3" height="10.5" rx=".5" fill="{D}" transform="rotate(-12 10.7 8.2)"/><path d="M1.5 14h13" stroke="#7a6a4f" stroke-linecap="round"/>' },
        pen: { name: qsTr("Pen"), F: "#c0703a", D: "#8a4d24", L: "#e0a27a", P: "#f7e6da",
            svg: '<path d="M11 2l3 3-8 8-3.7.7.7-3.7z" fill="{F}" stroke="{D}" stroke-linejoin="round"/><path d="M9.5 3.5l3 3" stroke="{D}"/>' },
        character: { name: qsTr("Person"), F: "#5b8fc7", D: "#3d6a9c", L: "#8bb2dc", P: "#e6eef8",
            svg: '<circle cx="8" cy="5" r="3" fill="{F}"/><path d="M2.5 14.5c0-3.3 2.5-5.5 5.5-5.5s5.5 2.2 5.5 5.5z" fill="{F}"/>' },
        group: { name: qsTr("People"), F: "#5b8fc7", D: "#3d6a9c", L: "#8bb2dc", P: "#e6eef8",
            svg: '<circle cx="5.5" cy="5.5" r="2.5" fill="{F}"/><path d="M1 14c0-2.8 2-4.7 4.5-4.7S10 11.2 10 14z" fill="{F}"/><circle cx="11" cy="4.5" r="2.2" fill="{L}"/><path d="M8.8 8.7c.7-.3 1.4-.5 2.2-.5 2.3 0 4 1.8 4 4.5h-3.4" fill="{L}"/>' },
        crown: { name: qsTr("Crown"), F: "#e0b62c", D: "#a8801d", L: "#f0d77a", P: "#fbf3d6",
            svg: '<path d="M2 5l3 3 3-5 3 5 3-3-1.2 8H3.2z" fill="{F}" stroke="{D}" stroke-linejoin="round"/>' },
        place: { name: qsTr("Pin"), F: "#d0533f", D: "#9a3a2b", L: "#e48a7b", P: "#ffffff",
            svg: '<path d="M8 15s-4.5-4.6-4.5-8.2a4.5 4.5 0 0 1 9 0C12.5 10.4 8 15 8 15z" fill="{F}"/><circle cx="8" cy="6.8" r="1.7" fill="#fff"/>' },
        map: { name: qsTr("Map"), F: "#7fb07a", D: "#4f7d4a", L: "#a9cba5", P: "#eaf3e9",
            svg: '<path d="M1.5 3.5l4-1.5 5 1.5 4-1.5v10.5l-4 1.5-5-1.5-4 1.5z" fill="{F}" stroke="{D}" stroke-linejoin="round"/><path d="M5.5 2v10.5M10.5 3.5V14" stroke="{D}"/>' },
        globe: { name: qsTr("Globe"), F: "#3f8f8f", D: "#2b6666", L: "#7dbaba", P: "#dff0ee",
            svg: '<circle cx="8" cy="8" r="6.3" fill="{P}" stroke="{F}" stroke-width="1.3"/><path d="M1.8 8h12.4M8 1.7c-2 2-2.8 4-2.8 6.3s.8 4.3 2.8 6.3M8 1.7c2 2 2.8 4 2.8 6.3s-.8 4.3-2.8 6.3" fill="none" stroke="{F}"/>' },
        research: { name: qsTr("Magnifier"), F: "#3f8f8f", D: "#2b6666", L: "#7dbaba", P: "#cfe6e6",
            svg: '<circle cx="6.5" cy="6.5" r="4" fill="{P}" stroke="{F}" stroke-width="1.6"/><path d="M9.5 9.5l4.5 4.5" stroke="{F}" stroke-width="2.2" stroke-linecap="round"/>' },
        attachment: { name: qsTr("Paper Clip"), F: "#3f8f8f", D: "#2b6666", L: "#7dbaba", P: "#cfe6e6",
            svg: '<path d="M11 5.5l-5 5a1.6 1.6 0 0 1-2.3-2.3l5.6-5.6a2.8 2.8 0 0 1 4 4L7.8 12a4 4 0 0 1-5.7-5.7L7 1.5" fill="none" stroke="{F}" stroke-width="1.4" stroke-linecap="round"/>' },
        image: { name: qsTr("Picture"), F: "#6aa36a", D: "#4f7d4a", L: "#9cc69c", P: "#eef6ee",
            svg: '<rect x="1.5" y="2.5" width="13" height="11" rx="1.2" fill="{P}" stroke="{D}"/><circle cx="5.5" cy="6" r="1.4" fill="{F}"/><path d="M2 13l4-4.5 3 3 2-2 3.5 3.5z" fill="{F}"/>' },
        chat: { name: qsTr("Dialogue"), F: "#4aa3a3", D: "#2f7676", L: "#8ac7c7", P: "#e3f3f3",
            svg: '<path d="M2 3.5A1.5 1.5 0 0 1 3.5 2h9A1.5 1.5 0 0 1 14 3.5v6a1.5 1.5 0 0 1-1.5 1.5H7l-3 3v-3h-.5A1.5 1.5 0 0 1 2 9.5z" fill="{F}" stroke="{D}" stroke-linejoin="round"/><path d="M5 5.5h6M5 8h4" stroke="{P}" stroke-linecap="round"/>' },
        plotline: { name: qsTr("Plotline"), F: "#8a63b8", D: "#5e3f86", L: "#b498d6", P: "#efe8f7",
            svg: '<path d="M1.5 11c2.5-6 4.5 2 7-3s3.5-4 6-3" fill="none" stroke="{F}" stroke-width="2" stroke-linecap="round"/><circle cx="1.8" cy="11" r="1.4" fill="{F}"/><circle cx="14.2" cy="5" r="1.4" fill="{F}"/>' },
        clock: { name: qsTr("Clock"), F: "#5b8fc7", D: "#2f5a94", L: "#8bb2dc", P: "#e6eef8",
            svg: '<circle cx="8" cy="8" r="6.3" fill="{P}" stroke="{F}" stroke-width="1.4"/><path d="M8 4.2V8l2.6 1.6" fill="none" stroke="{D}" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>' },
        calendar: { name: qsTr("Calendar"), F: "#d64545", D: "#7d8794", L: "#e88a8a", P: "#ffffff",
            svg: '<rect x="2" y="3" width="12" height="11" rx="1.2" fill="{P}" stroke="{D}"/><rect x="2" y="3" width="12" height="3.5" rx="1" fill="{F}"/><path d="M5 1.8v2.4M11 1.8v2.4" stroke="{D}" stroke-width="1.3" stroke-linecap="round"/><path d="M5 9h1.5M7.3 9h1.5M9.6 9H11M5 11.5h1.5M7.3 11.5h1.5" stroke="{D}"/>' },
        star: { name: qsTr("Star"), F: "#f2c14e", D: "#b8902a", L: "#f7d98d", P: "#fdf4dc",
            svg: '<path d="M8 1.5l1.9 4.1 4.4.5-3.3 3 .9 4.4L8 11.3l-3.9 2.2.9-4.4-3.3-3 4.4-.5z" fill="{F}" stroke="{D}" stroke-linejoin="round"/>' },
        heart: { name: qsTr("Heart"), F: "#e05a6f", D: "#a8384a", L: "#ec95a2", P: "#fbe3e7",
            svg: '<path d="M8 14S1.5 10 1.5 5.6A3.3 3.3 0 0 1 8 4.2a3.3 3.3 0 0 1 6.5 1.4C14.5 10 8 14 8 14z" fill="{F}" stroke="{D}" stroke-linejoin="round"/>' },
        flag: { name: qsTr("Flag"), F: "#d64545", D: "#9a2e2e", L: "#e88a8a", P: "#fae3e3",
            svg: '<path d="M3.5 14.5V2" stroke="{D}" stroke-width="1.4" stroke-linecap="round"/><path d="M4 2.5h9l-2 3 2 3H4z" fill="{F}" stroke="{D}" stroke-linejoin="round"/>' },
        bookmark: { name: qsTr("Bookmark"), F: "#4a7fc7", D: "#2f5a94", L: "#86aadc", P: "#e3ecf8",
            svg: '<path d="M4 1.5h8v13l-4-3-4 3z" fill="{F}" stroke="{D}" stroke-linejoin="round"/>' },
        idea: { name: qsTr("Idea"), F: "#f2d35b", D: "#b8972a", L: "#f7e39a", P: "#fdf6dc",
            svg: '<path d="M8 1.5a4.5 4.5 0 0 0-2.6 8.2c.4.3.6.8.6 1.3v.5h4V11c0-.5.2-1 .6-1.3A4.5 4.5 0 0 0 8 1.5z" fill="{F}" stroke="{D}" stroke-linejoin="round"/><path d="M6 13h4M6.8 14.6h2.4" stroke="#6b7078" stroke-linecap="round"/>' },
        key: { name: qsTr("Key"), F: "#c9a227", D: "#8f7319", L: "#dfc46c", P: "#f7efd2",
            svg: '<circle cx="5" cy="8" r="3" fill="none" stroke="{F}" stroke-width="2"/><path d="M8 8h6.5M12 8v2.5M14 8v2" stroke="{F}" stroke-width="2" stroke-linecap="round"/>' },
        sword: { name: qsTr("Sword"), F: "#8b6a45", D: "#6b7078", L: "#b39673", P: "#dfe3e8",
            svg: '<path d="M13.5 2.5l-1 3.5-6 6-2.5-2.5 6-6z" fill="{P}" stroke="{D}" stroke-linejoin="round"/><path d="M3 9.5l3.5 3.5M4.6 11.4l-2.6 2.6" stroke="{F}" stroke-width="1.6" stroke-linecap="round"/>' },
        question: { name: qsTr("Question"), F: "#8a63b8", D: "#5e3f86", L: "#b498d6", P: "#efe8f7",
            svg: '<circle cx="8" cy="8" r="6.5" fill="{F}"/><path d="M6 6.2a2 2 0 1 1 2.8 1.8c-.5.3-.8.7-.8 1.3v.4" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round"/><circle cx="8" cy="11.8" r=".9" fill="#fff"/>' },
        warning: { name: qsTr("Warning"), F: "#e08a2e", D: "#a85f1a", L: "#ecb57a", P: "#fbeedf",
            svg: '<path d="M8 1.8l6.6 11.7H1.4z" fill="{F}" stroke="{D}" stroke-linejoin="round"/><path d="M8 6v3.6" stroke="#fff" stroke-width="1.6" stroke-linecap="round"/><circle cx="8" cy="11.6" r=".9" fill="#fff"/>' },
        check: { name: qsTr("Done"), F: "#5a9e5a", D: "#3f753f", L: "#93c493", P: "#e6f2e6",
            svg: '<circle cx="8" cy="8" r="6.5" fill="{F}"/><path d="M4.8 8.2l2.2 2.2 4.2-4.6" fill="none" stroke="#fff" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>' },
        trash: { name: qsTr("Bin"), F: "#a3a7ad", D: "#6b7078", L: "#c8cbcf", P: "#eef0f2",
            svg: '<path d="M3.5 4.5h9l-.8 10h-7.4z" fill="{F}" stroke="{D}" stroke-linejoin="round"/><path d="M2 4.5h12M6 2.5h4" stroke="{D}" stroke-width="1.4" stroke-linecap="round"/><path d="M6.5 6.5v6M9.5 6.5v6" stroke="{P}"/>' }
    })

    // The order Icon & Colour… offers them in.
    readonly property var choices: ["folder", "document", "note", "notebook", "book", "manuscript", "pen",
        "character", "group", "crown", "place", "map", "globe", "research", "attachment", "image",
        "chat", "plotline", "clock", "calendar", "star", "heart", "flag", "bookmark", "idea", "key",
        "sword", "question", "warning", "check"]

    // Colours to pick from (Icon & Colour…): clear enough on light and dark.
    readonly property var swatches: [
        { name: qsTr("Red"), c: "#d64545" }, { name: qsTr("Orange"), c: "#e08a2e" },
        { name: qsTr("Yellow"), c: "#e0b62c" }, { name: qsTr("Green"), c: "#5a9e5a" },
        { name: qsTr("Teal"), c: "#2f9e9e" }, { name: qsTr("Blue"), c: "#4a7fc7" },
        { name: qsTr("Purple"), c: "#8a63b8" }, { name: qsTr("Pink"), c: "#d1609a" },
        { name: qsTr("Brown"), c: "#8b6a45" }, { name: qsTr("Grey"), c: "#7d8794" }
    ]
    // Row backgrounds: the same colours, see-through so the title stays
    // readable in either theme.
    function rowSwatch(c) { return "#4d" + String(c).slice(1); }

    // The icon an item kind or section uses when none is chosen.
    function defaultFor(kind, role) {
        const roles = { manuscript: "manuscript", characters: "group", places: "map", research: "research", notes: "notebook", trash: "trash" };
        const kinds = { folder: "folder", text: "document", note: "note", character: "character", place: "place", research: "attachment", plotline: "plotline" };
        return roles[role] || kinds[kind] || "document";
    }

    function hex2(v) { return ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2); }
    function hex(c) { return "#" + hex2(c.r) + hex2(c.g) + hex2(c.b); }
    // `c` moved `t` of the way toward `to`.
    function mix(c, to, t) { return Qt.rgba(c.r + (to.r - c.r) * t, c.g + (to.g - c.g) * t, c.b + (to.b - c.b) * t, 1); }

    // An icon's image, in its own colours or (with `tint`) in shades of one.
    function url(name, tint) {
        const icon = set[name] || set.document;
        let cs = { F: icon.F, D: icon.D, L: icon.L, P: icon.P };
        if (tint) {
            const c = Qt.color(tint), black = Qt.rgba(0, 0, 0, 1), white = Qt.rgba(1, 1, 1, 1);
            cs = { F: hex(c), D: hex(mix(c, black, 0.32)), L: hex(mix(c, white, 0.4)), P: hex(mix(c, white, 0.82)) };
        }
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">'
            + icon.svg.replace(/\{([FDLP])\}/g, (m, k) => cs[k]) + '</svg>';
        return "data:image/svg+xml;base64," + Qt.btoa(svg);
    }
}
