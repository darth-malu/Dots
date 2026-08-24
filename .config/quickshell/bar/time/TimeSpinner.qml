import QtQuick
import QtQuick.Layouts

// HH:MM entry with individually scrollable hour / minute segments.
// Defaults to the current time (minutes snapped to 5) and reports it
// through timeString; dirty flips once the user touches a segment.
RowLayout {
    id: root

    property string hours: "00"
    property string minutes: "00"
    // becomes true after the first wheel step / edit of either segment
    property bool dirty: false

    readonly property string timeString: hours + ":" + minutes

    Component.onCompleted: root.reset()

    function reset() {
        const now = new Date();
        const hh = String(now.getHours()).padStart(2, "0");
        // snap minutes to the 5-minute wheel grid
        const mm = String(Math.round(now.getMinutes() / 5) * 5 % 60).padStart(2, "0");
        hours = hh;
        minutes = mm;
        dirty = false;
        hhSeg.input.text = hh;
        mmSeg.input.text = mm;
    }

    function _setHours(v) {
        hours = String(((Math.round(v) % 24) + 24) % 24).padStart(2, "0");
        dirty = true;
    }

    function _setMinutes(v) {
        minutes = String(((Math.round(v) % 60) + 60) % 60).padStart(2, "0");
        dirty = true;
    }

    component Segment: Rectangle {
        id: seg

        property string label
        property alias input: segInput
        property int step // wheel delta per notch
        signal stepped(int delta)
        signal edited(string text)

        function commitEdit() {
            const v = parseInt(segInput.text);
            if (!isNaN(v))
                edited(v);
            else
                segInput.text = label;
        }

        implicitWidth: 22
        implicitHeight: 24
        radius: 6
        readonly property bool focused: segInput.activeFocus
        color: focused ? Qt.rgba(0.741, 0.576, 0.976, 0.16) : "#44475a"
        border.width: 1
        border.color: segHover.hovered || focused ? "#bd93f9" : "#6272a4"

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }
        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        TextInput {
            id: segInput

            anchors.centerIn: parent
            width: parent.width + 6
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            // plain initial value — the Connections blocks below keep it in
            // sync with root state without fighting manual edits
            text: parent.label
            color: "#bd93f9"
            font { pixelSize: 11; bold: true; family: "ZedMono Nerd Font" }
            maximumLength: 2
            validator: RegularExpressionValidator { regularExpression: /[0-9]{0,2}/ }
            selectByMouse: true
            activeFocusOnTab: true
            cursorVisible: activeFocus

            // click anywhere on the chip focuses and selects for typing
            TapHandler {
                onTapped: {
                    segInput.forceActiveFocus();
                    segInput.selectAll();
                }
            }

            onAccepted: parent.commitEdit()
            Keys.onReturnPressed: segInput.focus = false
            Keys.onEnterPressed: segInput.focus = false
            Keys.onEscapePressed: {
                segInput.text = parent.label;
                segInput.focus = false;
            }
            Keys.onUpPressed: parent.stepped(parent.step)
            Keys.onDownPressed: parent.stepped(-parent.step)
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => parent.stepped(ev.angleDelta.y > 0 ? parent.step : -parent.step)
        }

        HoverHandler {
            id: segHover
        }
    }

    Segment {
        id: hhSeg

        label: root.hours
        step: 1
        onStepped: d => root._setHours(parseInt(root.hours) + d)
        onEdited: t => root._setHours(parseInt(t))

        Connections {
            target: root

            function onHoursChanged() {
                if (!hhSeg.input.activeFocus)
                    hhSeg.input.text = root.hours;
            }
        }
    }

    Text {
        text: ":"
        color: "#6272a4"
        font { pixelSize: 12; bold: true; family: "ZedMono Nerd Font" }
    }

    Segment {
        id: mmSeg

        label: root.minutes
        step: 5
        onStepped: d => root._setMinutes(parseInt(root.minutes) + d)
        onEdited: t => {
            let v = parseInt(t);
            if (v > 59)
                v = 59;
            root._setMinutes(v);
        }

        Connections {
            target: root

            function onMinutesChanged() {
                if (!mmSeg.input.activeFocus)
                    mmSeg.input.text = root.minutes;
            }
        }
    }
}
