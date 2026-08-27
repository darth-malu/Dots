pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property color barBg: 'transparent'

    property bool borderShadow: false

    // readonly property color activeWorkspaceIdColor: "#5c0099"

    // readonly property color inactiveTextColor: Qt.rgba(0.67, 0.55, 0.93, 0.88)

    // readonly property color activeWorkspaceColor: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1)

    readonly property color activeTextColor: "#C4E4FF" //#bd93f9" //"#00CAFF"// "#3BF4FB" //, C2CAE8, 3BF4FB, B8B8FF, 5DFDCB, 23C9FF,#9CFFFA, 9400FF, 9CFF2E,00FFAB, 06FF00//Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1)

    // readonly property color glassTintActiveHasClients: Qt.rgba(1, 1, 1, 0.25)

    // readonly property color borderActive: Qt.rgba(1, 1, 1, 0.25)

    readonly property color activeHasClientsBorder: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 0.65)//Qt.rgba(1, 1, 1, 0.25) //"#99000000"

    readonly property color activeBg: "#282a36" // "#2d353b"//Qt.rgba(1, 1, 1, 0.1)

    readonly property color inactiveBg: "#2d353b"//Qt.rgba(1, 1, 1, 0.1)

    readonly property color inactiveTextColor: Qt.color("grey")

    // readonly property color currentMonitorNotActiveColor: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1)

    readonly property color dropShadow: "#000000"

    readonly property color toxicGreen: "#88FF00"

    // MPRIS
    readonly property color mprisTextColor: "#FAAB8DED"

    readonly property color mprisVolumeColor: "#ff79c6"

    readonly property color mprisIndicatorColor: "#88FF00"//"#ff79c6"

    // Rofi / Launcher
    readonly property color launcherBg: Qt.rgba(12 / 255, 44 / 255, 44 / 255, 0.9)
    readonly property color rofiBorder: Qt.rgba(63 / 255, 167 / 255, 197 / 255, 0.42)
    readonly property color rofiAccent: Qt.rgba(63 / 255, 167 / 255, 197 / 255, 0.82)
    readonly property color rofiHighlightBg: Qt.rgba(72 / 255, 191 / 255, 227 / 255, 0.2)
    readonly property color rofiDelegateText: Qt.rgba(196 / 255, 203 / 255, 212 / 255, 1)
    readonly property font rofiFont: Qt.font({
        family: "Mononoki Nerd Font",
        pointSize: 11
    })

    // Calendar (dracula)
    readonly property color calendarHeader: '#bd93f9'
    readonly property color calendarDayRow: '#8be9fd'
    readonly property color calendarInactiveMonth: "#6272a4"
    readonly property color calendarActiveMonth: '#f8f8f2'
    readonly property color calendarToday: '#bd93f9'
    readonly property color clockColor: '#ff79c6'

    // Soft organic inactive state (Everforest 'Background Soft')
    property Gradient inactiveGradientV: Gradient {
        GradientStop {
            position: 0.0
            color: Qt.rgba(51 / 255, 59 / 255, 66 / 255, 0.4)
        }
        GradientStop {
            position: 0.7
            color: Qt.rgba(51 / 255, 59 / 255, 66 / 255, 0.9) // Deep charcoal body
        }
        GradientStop {
            position: 1.0
            color: Qt.rgba(45 / 255, 53 / 255, 59 / 255, 0.6)
        }
    }

    property Gradient inactiveGradientH: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
            position: 0.0
            color: "#2d353b"
        }
        GradientStop {
            position: 0.4
            color: "transparent"
        }
    }

    property Gradient activeGradient: Gradient {
        GradientStop {
            position: 0.0
            color: "#282a36"//Qt.rgba(167 / 255, 192 / 255, 128 / 255, 0.2) // Subtle green tint at top
        }
        GradientStop {
            position: 0.7
            color: Qt.rgba(51 / 255, 59 / 255, 66 / 255, 0.9) // Deep charcoal body
        }
        GradientStop {
            position: 1.0
            color: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 0.85)
        }
    }

    // From Colors.qml
    property color bgBar: Qt.rgba(0, 0, 0, 0.21)
    // property color bgBlur: Qt.rgba(0, 0, 0, 0.5)
    property color bgBlur: Qt.rgba(0, 0, 0, 0.8)
    /* property color blueText: "#900000FF" */
    property color foreground: 'white'//Qt.rgba(171 / 255, 141 / 255, 237 / 255, 0.88)
    //property list<color> monitorColors: ["#e06c75", "#e5c07b", "#98c379", "#61afef"]

    property color surface: Qt.rgba(255, 255, 255, 0.15)
    property color overlay: Qt.rgba(255, 255, 255, 0.7)

    property color accent: "#e06c75"

    property color buttonEnabled: accent
    property color buttonEnabledHover: Qt.lighter(accent, 0.9)
    property color buttonDisabled: surface
    property color buttonDisabledHover: Qt.rgba(surface.r, surface.g, surface.b, surface.a + 0.1)

    // Fonts
    readonly property font quicksand_medium: Qt.font({
        family: "Quicksand Medium",
        pixelSize: 13,
        bold: false
    })

    readonly property font zedMono: Qt.font({
        family: "ZedMono Nerd Font",
        pixelSize: 12,
        bold: true
    })

    readonly property font quicksand: Qt.font({
        family: "quicksand",
        pixelSize: 12,
        bold: true
    })

    readonly property font lato: Qt.font({
        pixelSize: 13,
        family: 'lato',
        bold: true
    })

    readonly property font monofur: Qt.font({
        pixelSize: 15,
        family: 'Monofur Nerd Font',
        bold: true
    })

    readonly property color windowTextColor: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1) //#8390FA

    readonly property color glassColor: Qt.rgba(1, 1, 1, 0.35)

    readonly property font windowTextFont: ({
            family: "Quicksand medium",
            pixelSize: 12,
            bold: true
        })

    // Boxy design theme — nearly square corners, stronger active bg
    readonly property real boxyRadius: 2
    readonly property color boxyActiveBg: Qt.rgba(0.74, 0.58, 0.98, 0.25)
    readonly property color boxyHoverBg: Qt.rgba(1, 1, 1, 0.08)
    readonly property color boxyActiveBorder: Qt.rgba(0.74, 0.58, 0.98, 0.45)
    readonly property int boxyBorderWidth: 1

    // Rounded design theme — pill/circle shapes, softer active bg
    readonly property real roundedRadius: 999
    readonly property color roundedActiveBg: Qt.rgba(0.741, 0.576, 0.976, 0.18)
    readonly property color roundedHoverBg: Qt.rgba(1, 1, 1, 0.06)
    readonly property color roundedActiveBorder: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 0.65)
    readonly property int roundedBorderWidth: 1
    readonly property color roundedUrgentBg: Qt.rgba(1, 0.33, 0.33, 0.15)
    readonly property color roundedBadgeBg: Qt.rgba(0.741, 0.576, 0.976, 0.25)
    readonly property color roundedBadgeText: Qt.rgba(1, 1, 1, 0.5)
}
