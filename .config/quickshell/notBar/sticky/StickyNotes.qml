import QtQuick
import qs.services
import qs.notBar.sticky

// Mounts every sticky note from NotesState as its own desktop surface.
// Added notes appear instantly; deleting a note drops its window.
Item {
    Repeater {
        id: noteRepeater
        model: NotesState.model

        StickyNote {
            required property int index
        }
    }
}