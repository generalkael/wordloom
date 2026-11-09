import QtQuick
import QtCore

// A Settings that writes every change to disk as it happens. Plain Settings
// keeps a change in memory for half a second, and QSettings writes it later
// still (at the latest when Wordloom quits), so a crash or a forced quit
// could lose preferences just changed. Declare properties (usually aliases)
// as on Settings.
Settings {
    id: ss

    // The properties declared on top of Settings. (A function, not a
    // property: Settings would store a property as a setting too.)
    function savedKeys() {
        const keys = [];
        for (const k in ss) {
            if (k === "objectName" || k === "category" || k === "location" || typeof ss[k] === "function") continue;
            const changed = ss[k + "Changed"];
            if (changed && typeof changed.connect === "function") keys.push(k);
        }
        return keys;
    }
    function saveNow() {
        for (const k of savedKeys()) setValue(k, ss[k]);
        sync();
    }

    // Settings has loaded the saved values by now, so loading them doesn't
    // write them straight back.
    Component.onCompleted: { for (const k of savedKeys()) ss[k + "Changed"].connect(ss.saveNow); }
}
