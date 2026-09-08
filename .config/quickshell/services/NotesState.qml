pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Sticky notes state — a ListModel (granular, so editing one note doesn't
// recreate every note window) persisted to notes.json. Each note row:
// { id, text, x, y, w, h, color, visible } where x/y are 0..1 screen
// fractions that survive resolution changes.
Singleton {
    id: root

    ListModel {
        id: notesModel
    }

    readonly property alias model: notesModel

    function count(): int {
        return notesModel.count;
    }

    // ── CRUD ──
    function addNote() {
        notesModel.append({
            id: "n" + Date.now() + Math.floor(Math.random() * 1000),
            text: "",
            x: 0.3,
            y: 0.25,
            w: 240,
            h: 160,
            color: 0,
            visible: true
        });
        root.persist();
    }

    function setText(idx, t) {
        if (idx < 0 || idx >= notesModel.count)
            return;
        notesModel.setProperty(idx, "text", t);
        root.persist();
    }

    function setPos(idx, x, y) {
        if (idx < 0 || idx >= notesModel.count)
            return;
        notesModel.setProperty(idx, "x", x);
        notesModel.setProperty(idx, "y", y);
        root.persist();
    }

    function setSize(idx, w, h) {
        if (idx < 0 || idx >= notesModel.count)
            return;
        notesModel.setProperty(idx, "w", w);
        notesModel.setProperty(idx, "h", h);
        root.persist();
    }

    function setColor(idx, c) {
        if (idx < 0 || idx >= notesModel.count)
            return;
        notesModel.setProperty(idx, "color", c);
        root.persist();
    }

    function removeById(id) {
        for (let i = 0; i < notesModel.count; i++)
            if (notesModel.get(i).id === id)
                notesModel.remove(i);
        root.persist();
    }

    function clear() {
        notesModel.clear();
        root.persist();
    }

    // ── persistence ──
    function persist() {
        const arr = [];
        for (let i = 0; i < notesModel.count; i++) {
            const r = notesModel.get(i);
            arr.push({
                id: r.id,
                text: r.text,
                x: r.x,
                y: r.y,
                w: r.w,
                h: r.h,
                color: r.color,
                visible: r.visible
            });
        }
        prefs.notes = arr;
        noteStore.writeAdapter();
    }

    function _seed() {
        const src = prefs.notes ?? [];
        for (let i = 0; i < src.length; i++) {
            const r = src[i];
            notesModel.append({
                id: r.id ?? "n" + i,
                text: r.text ?? "",
                x: r.x ?? 0.3,
                y: r.y ?? 0.25,
                w: r.w ?? 240,
                h: r.h ?? 160,
                color: r.color ?? 0,
                visible: r.visible ?? true
            });
        }
    }

    FileView {
        id: noteStore
        path: Quickshell.env("HOME") + "/.config/quickshell/notes.json"
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: prefs
            property var notes: []
        }
    }

    Component.onCompleted: {
        root._seed();
    }
}