import QtQuick
import QtQuick.Layouts

// HH:MM entry with individually scrollable hour / minute segments.
// Defaults to 00:00 and only reports a time once the user actually
// touches it (dirty), so an untouched spinner means "no time set".
RowLayout {
    id: root

    property string hours: "00"
    property string minutes: "00"
    // becomes true after the first wheel step / edit of either segment
    property bool dirty: false

    readonly property string timeString: hours + ":" + minutes

    function reset() {
        hours = "00";
        minutes = "00";
        dirty = false;
        hhEdit.text = "00";
        mmEdit.text = "00";
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
            width: parent.width - 8
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            text: parent.label
            color: "#bd93f9"
            font { pixelSize: 11; bold: true; family: "ZedMono Nerd Font" }
            maximumLength: 2
            validator: RegularExpressionValidator { regularExpression: /\d{0,2}/ }
            selectByMouse: true

            onEditingFinished: {
                const v = parseInt(text);
                if (!isNaN(v))
                    parent.edited(text);
                else
                    text = parent.label;
            }

            Keys.onUpPressed: parent.stepped(parent.step)
            Keys.onDownPressed: parent.stepped(-parent.step)
            Keys.onReturnPressed: root.forceActiveFocus()
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
