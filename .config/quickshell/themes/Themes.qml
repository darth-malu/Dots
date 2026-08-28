pragma Singleton
import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    // ── Color scheme selection ──────────────────────────────────────────
    // 0 = Purple (Dracula-ish, default), 1 = Rofi teal/cyan
    readonly property int scheme: MiscState.themeScheme
    function pick(purple, rofi): color { return scheme === 0 ? purple : rofi }

    // Core identity tokens (themed)
    readonly property color accent2: pick("#8be9fd", "#48bfe3")  // cyan secondary
    readonly property color pink: pick("#ff79c6", "#e5a8cf")
    readonly property color fg: pick("#f8f8f2", "#eef4f7")
    readonly property color dim: pick("#b8bfcb", "#aebbc4")
    readonly property color muted: pick("#6272a4", "#5f6f7d")
    readonly property color cardBg: pick("#21222c", "#1f2b31")
    readonly property color cardBgHover: pick("#2a2c3a", "#28343b")
    readonly property color panelBg: pick("#282a36", "#24313a")
    readonly property color separator: pick("#343746", "#2e3f47")
    readonly property color borderColor: pick("#313244", "#293a43")
    readonly property color borderMuted: pick("#44475a", "#3a4a52")
    readonly property color barSolidBg: pick("#181825", "#1b252c")  // solid/full bar slab background
    readonly property color accentSoft: pick("#e2d6fb", "#c9eaf5")  // light accent (active glyphs/hover text)
    readonly property color mutedSoft: pick("#8b93b8", "#7d93a0")   // muted lavender inactive -> teal-grey
    readonly property color mauve: pick("#c6a0f6", "#5fc3d9")       // medium-tier accent (mauve -> teal)
    readonly property color brightnessAccent: pick("#f1fa8c", "#d0e56a")  // brightness slider (sun yellow -> warm teal-green)

    // Semantic status tokens (shared across schemes)
    readonly property color green: "#50fa7b"
    readonly property color red: "#ff5555"
    readonly property color orange: "#ffb86c"
    readonly property color yellow: "#f1fa8c"

    // Popup/card background — solid (opaque) or glass variant
    readonly property color popupCardBg: MiscState.popupSolidBg ? panelBg : Qt.rgba(panelBg.r, panelBg.g, panelBg.b, 0.82)

    property color barBg: 'transparent'

    property bool borderShadow: false

    // readonly property color activeWorkspaceIdColor: "#5c0099"

    // readonly property color inactiveTextColor: Qt.rgba(0.67, 0.55, 0.93, 0.88)

    // readonly property color activeWorkspaceColor: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1)

    readonly property color activeTextColor: "#C4E4FF" //#bd93f9" //"#00CAFF"// "#3BF4FB" //, C2CAE8, 3BF4FB, B8B8FF, 5DFDCB, 23C9FF,#9CFFFA, 9400FF, 9CFF2E,00FFAB, 06FF00//Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1)

    // readonly property color glassTintActiveHasClients: Qt.rgba(1, 1, 1, 0.25)

    // readonly property color borderActive: Qt.rgba(1, 1, 1, 0.25)

    readonly property color activeHasClientsBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.65)//Qt.rgba(1, 1, 1, 0.25) //"#99000000"

    readonly property color activeBg: panelBg // "#2d353b"//Qt.rgba(1, 1, 1, 0.1)

    readonly property color inactiveBg: "#2d353b"//Qt.rgba(1, 1, 1, 0.1)

    readonly property color inactiveTextColor: Qt.color("grey")

    // readonly property color currentMonitorNotActiveColor: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1)

    readonly property color dropShadow: "#000000"

    readonly property color toxicGreen: "#88FF00"

    // MPRIS
    readonly property color mprisTextColor: pick("#FAAB8DED", "#cde6f0")

    readonly property color mprisVolumeColor: root.pink

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
    readonly property color calendarHeader: root.accent
    readonly property color calendarDayRow: root.accent2
    readonly property color calendarInactiveMonth: root.muted
    readonly property color calendarActiveMonth: root.fg
    readonly property color calendarToday: root.accent
    readonly property color clockColor: root.pink

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

    property color accent: pick("#bd93f9", "#3fa7c5")

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

    readonly property color windowTextColor: Qt.rgba(accent.r, accent.g, accent.b, 1)

    readonly property color glassColor: Qt.rgba(1, 1, 1, 0.35)

    readonly property font windowTextFont: ({
            family: "Quicksand medium",
            pixelSize: 12,
            bold: true
        })

    // Boxy design theme — nearly square corners, stronger active bg
    readonly property real boxyRadius: 2
    readonly property color boxyActiveBg: Qt.rgba(accent.r, accent.g, accent.b, 0.25)
    readonly property color boxyHoverBg: Qt.rgba(1, 1, 1, 0.08)
    readonly property color boxyActiveBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.45)
    readonly property int boxyBorderWidth: 1

    // Rounded design theme — pill/circle shapes, softer active bg
    readonly property real roundedRadius: 999
    readonly property color roundedActiveBg: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color roundedHoverBg: Qt.rgba(1, 1, 1, 0.06)
    readonly property color roundedActiveBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.65)
    readonly property int roundedBorderWidth: 1
    readonly property color roundedUrgentBg: Qt.rgba(1, 0.33, 0.33, 0.15)
    readonly property color roundedBadgeBg: Qt.rgba(accent.r, accent.g, accent.b, 0.25)
    readonly property color roundedBadgeText: Qt.rgba(1, 1, 1, 0.5)
}
