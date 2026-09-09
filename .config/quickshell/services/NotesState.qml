pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Sticky notes state — a ListModel (granular, so editing one note doesn't
// recreate every note window) persisted to notes.json. Each note row:
// { id, text, x, y, w, h, color, visible, kind, items } where x/y are 0..1
// screen fractions that survive resolution changes. kind is "note" (free text
// in `text`) or "todo" (a checklist in `items`: [{ t, d }]).
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
    function addNote(kind) {
        notesModel.append({
            id: "n" + Date.now() + Math.floor(Math.random() * 1000),
            text: "",
            items: [],
            x: 0.3,
            y: 0.25,
            w: 240,
            h: 160,
            color: 0,
            visible: true,
            kind: kind === "todo" ? "todo" : "note"
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

    function setKind(idx, k) {
        if (idx < 0 || idx >= notesModel.count)
            return;
        notesModel.setProperty(idx, "kind", k === "todo" ? "todo" : "note");
        root.persist();
    }

    // ── todo items ──
    function addTodoItem(idx) {
        if (idx < 0 || idx >= notesModel.count)
            return;
        const items = [...(notesModel.get(idx).items ?? [])];
        items.push({ t: "", d: false });
        notesModel.setProperty(idx, "items", items);
        root.persist();
    }

    function setTodoText(idx, iidx, t) {
        if (idx < 0 || idx >= notesModel.count)
            return;
        const items = [...(notesModel.get(idx).items ?? [])];
        if (iidx < 0 || iidx >= items.length)
            return;
        items[iidx] = { t: String(t ?? ""), d: !!items[iidx].d };
        notesModel.setProperty(idx, "items", items);
        root.persist();
    }

    function toggleTodoItem(idx, iidx, d) {
        if (idx < 0 || idx >= notesModel.count)
            return;
        const items = [...(notesModel.get(idx).items ?? [])];
        if (iidx < 0 || iidx >= items.length)
            return;
        items[iidx] = { t: items[iidx].t, d: !!d };
        notesModel.setProperty(idx, "items", items);
        root.persist();
    }

    function removeTodoItem(idx, iidx) {
        if (idx < 0 || idx >= notesModel.count)
            return;
        const items = [...(notesModel.get(idx).items ?? [])];
        if (iidx < 0 || iidx >= items.length)
            return;
        items.splice(iidx, 1);
        notesModel.setProperty(idx, "items", items);
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
                visible: r.visible,
                kind: r.kind,
                items: r.items
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
                visible: r.visible ?? true,
                kind: r.kind ?? "note",
                items: r.items ?? []
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