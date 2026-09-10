pragma Singleton
import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    // ── Color scheme selection ──────────────────────────────────────────
    // 0 = Pyrple (Dracula-ish, default), 1 = Gron teal/cyan,
    // 2 = Gruvbox retro warm, 3 = Rose warm pink, 4 = Everforest calm green,
    // 5 = Soramane sky/celestial (caelestia lockscreen + frame + bar styling)
    readonly property int scheme: MiscState.themeScheme
    function pick(p, g, n, r, a, s): color {
        var v = scheme === 0 ? p : scheme === 1 ? g : scheme === 2 ? n : scheme === 3 ? r : scheme === 4 ? a : s;
        return v || g;
    }
    // explicit-scheme picker for the launcher roster (MiscState.rofiTheme):
    // pass -1 to fall back to the currently active scheme
    function pickScheme(sel, p, g, n, r, a, s): color {
        var i = sel >= 0 ? sel : root.scheme;
        return i === 0 ? p : i === 1 ? g : i === 2 ? n : i === 3 ? r : i === 4 ? a : (s || g);
    }

    // Core identity tokens (themed)
    readonly property color accent2: pick("#8be9fd", "#48bfe3", "#8ec07c", "#f2b0cd", "#83c092", "#a6d8ff")  // cyan secondary → everforest aqua / soramane pale sky
    readonly property color pink: pick("#ff79c6", "#e5a8cf", "#b16286", "#ff6b9d", "#d699b6", "#ffa7cd")
    readonly property color fg: pick("#f8f8f2", "#eef4f7", "#ebdbb2", "#f6eaf1", "#d3c6aa", "#eaf3ff")
    readonly property color dim: pick("#b8bfcb", "#aebbc4", "#a89984", "#b8a8b4", "#9da9a0", "#b7c4de")
    readonly property color muted: pick("#6272a4", "#5f6f7d", "#928374", "#8a647a", "#859289", "#8fa2c9")
    readonly property color cardBg: pick("#21222c", "#1f2b31", "#282828", "#2a1f27", "#343f44", "#1c2334")
    readonly property color cardBgHover: pick("#2a2c3a", "#28343b", "#3c3836", "#372a32", "#3d484d", "#252e44")
    readonly property color panelBg: pick("#282a36", "#24313a", "#282828", "#2f222c", "#2d353b", "#222a3f")
    readonly property color separator: pick("#343746", "#2e3f47", "#3c3836", "#3a2d33", "#3f4a4f", "#34405c")
    readonly property color borderColor: pick("#313244", "#293a43", "#3c3836", "#3a2b32", "#475258", "#2c3750")
    readonly property color borderMuted: pick("#44475a", "#3a4a52", "#504945", "#57434e", "#4f585e", "#415181")
    readonly property color barSolidBg: pick("#181825", "#1b252c", "#1d2021", "#191217", "#2b3338", "#161d2e")  // solid/full bar slab background
    readonly property color accentSoft: pick("#e2d6fb", "#c9eaf5", "#ebdbb2", "#f5d5e5", "#e5e3d4", "#e6eeff")  // light accent (active glyphs/hover text)
    readonly property color mutedSoft: pick("#8b93b8", "#7d93a0", "#a89984", "#a98fa0", "#8a9a8f", "#93a8d6")   // muted lavender inactive -> teal-grey / periwinkle-grey
    readonly property color mauve: pick("#c6a0f6", "#5fc3d9", "#8ec07c", "#d98bb0", "#7fbbb3", "#a5b4ff")       // medium-tier accent (mauve -> teal / periwinkle)
    readonly property color brightnessAccent: pick("#f1fa8c", "#d0e56a", "#fabd2f", "#ffcf6b", "#dbbc7f", "#ffd98a")  // brightness slider (sun yellow -> soft sky sun)

    // Audio sliders — distinct hue for the input sink so sink volume reads
    // apart from the output slider (which stays on the primary accent). In
    // Gron the default cyan is too close to the teal accent, so it becomes a
    // distinct green for visible variance.
    readonly property color audioInputAccent: pick("#8be9fd", "#2ec4a5", "#8ec07c", "#f2b0cd", "#83c092", "#8fdcff")

    // Semantic status tokens (scheme-aware — shared success/error/warn hues)
    readonly property color green: pick("#50fa7b", "#3fd8a0", "#b8bb26", "#9defb0", "#a7c080", "#7cf2a8")
    readonly property color red: pick("#ff5555", "#ff6b6b", "#fb4934", "#f16a7e", "#e67e80", "#ff8080")
    readonly property color orange: pick("#ffb86c", "#ffab5c", "#d65d0e", "#f5a97f", "#e69875", "#ffc07a")
    readonly property color yellow: pick("#f1fa8c", "#ffe066", "#fabd2f", "#f7c948", "#dbbc7f", "#ffe08a")

    // Git severity shades (the grey/aqua/warm-yellow of the pill + popup)
    readonly property color sevNoUpstream: pick("#8a8fa1", "#8a9aa4", "#928374", "#b8a8b4", "#9da9a0", "#8fa2c9")
    readonly property color sevUnpushed: pick("#8be9fd", "#48bfe3", "#8ec07c", "#f2b0cd", "#7fbbb3", "#a6d8ff")
    readonly property color sevDiverged: pick("#ffd866", "#ffd166", "#fe8019", "#ffb35c", "#dbbc7f", "#ffd07a")

    // Temperature bands — soft mint for the mild tier (was bright neon
    // green, too shouty); hotter tiers keep their existing orange/red hues
    readonly property color tempMild: pick("#b5ead7", "#a5e6cf", "#a9b665", "#bfe6d8", "#9da9a0", "#b9ecd9")

    // Popup/card background — solid (opaque) or glass variant
    readonly property color popupCardBg: MiscState.popupSolidBg ? panelBg : Qt.rgba(panelBg.r, panelBg.g, panelBg.b, 0.82)

    // ── bar text — wallpaper-aware ──
    // bar text must stay legible on any wallpaper. The three-way toggle picks
    // the wallpaper domain: "auto" (default) follows each wallpaper's detected
    // tone — dark walls → light glyphs, bright walls → dark glyphs — so glyphs
    // are always legible; "light" pins to a light wallpaper (dark glyphs);
    // "dark" pins to a dark wallpaper (light glyphs).
    // _barLightWall === true means "light wallpaper → dark text".
    readonly property bool _barLightWall: {
        const t = WallpaperService.barTextTone;
        if (t === "light")
            return true;
        if (t === "dark")
            return false;
        return WallpaperService.lightWallpaper;
    }
    readonly property color barText: root._barLightWall ? "#1a1a24" : root.fg
    readonly property color barMuted: root._barLightWall ? "#5a5a68" : root.muted
    readonly property color barDim: root._barLightWall ? "#8a8a96" : root.dim

    property color barBg: 'transparent'

    property bool borderShadow: false

    // readonly property color activeWorkspaceIdColor: "#5c0099"

    // readonly property color inactiveTextColor: Qt.rgba(0.67, 0.55, 0.93, 0.88)

    // readonly property color activeWorkspaceColor: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1)

    readonly property color activeTextColor: pick("#C4E4FF", "#c5e6f2", "#ebdbb2", "#f5d5e5", "#d3c6aa", "#d0e2ff")

    // readonly property color glassTintActiveHasClients: Qt.rgba(1, 1, 1, 0.25)

    // readonly property color borderActive: Qt.rgba(1, 1, 1, 0.25)

    readonly property color activeHasClientsBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.65)//Qt.rgba(1, 1, 1, 0.25) //"#99000000"

    readonly property color activeBg: panelBg // "#2d353b"//Qt.rgba(1, 1, 1, 0.1)

    readonly property color inactiveBg: "#2d353b"//Qt.rgba(1, 1, 1, 0.1)

    readonly property color inactiveTextColor: Qt.color("grey")

    // readonly property color currentMonitorNotActiveColor: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1)

    readonly property color dropShadow: "#000000"

    readonly property color toxicGreen: pick("#88FF00", "#2ec4a5", "#b8bb26", "#9defb0", "#a7c080", "#8dffa8")

    // MPRIS
    readonly property color mprisTextColor: pick("#FAAB8DED", "#cde6f0", "#ebdbb2", "#f5d5e5", "#d3c6aa", "#d5e5ff")

    readonly property color mprisVolumeColor: root.pink

    readonly property color mprisIndicatorColor: root.green

    // Rofi / Launcher — scheme-aware glass rosters. Every panel (launcher,
    // calc, pickers) reads these shared tokens. The bg respects the blur
    // pref: with backdrop blur enabled it drops to rofiOpacity so the
    // wallpaper shows through; disabled it stays ≥ 0.85 to keep text legible.
    readonly property color rofiBgBase: pickScheme(MiscState.rofiTheme, "#282a36", // pyrple
    "#0f2f2f", // gron — the classic teal glass
    "#1d2021", // gruvbox
    "#2a1c26", // rose
    "#27322c", // everforest
    "#18223e") // soramane
    readonly property real rofiBgOpacity: MiscState.rofiBlur ? MiscState.rofiOpacity : Math.max(MiscState.rofiOpacity, 0.85)
    readonly property color launcherBg: Qt.rgba(rofiBgBase.r, rofiBgBase.g, rofiBgBase.b, rofiBgOpacity)
    readonly property color rofiBorder: pickScheme(MiscState.rofiTheme, Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.42), Qt.rgba(63 / 255, 167 / 255, 197 / 255, 0.42), Qt.rgba(254 / 255, 128 / 255, 25 / 255, 0.42), Qt.rgba(229 / 255, 122 / 255, 167 / 255, 0.42), Qt.rgba(167 / 255, 192 / 255, 128 / 255, 0.42), Qt.rgba(138 / 255, 180 / 255, 255 / 255, 0.42))
    readonly property color rofiAccent: pickScheme(MiscState.rofiTheme, Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.82), Qt.rgba(63 / 255, 167 / 255, 197 / 255, 0.82), Qt.rgba(254 / 255, 128 / 255, 25 / 255, 0.82), Qt.rgba(229 / 255, 122 / 255, 167 / 255, 0.82), Qt.rgba(167 / 255, 192 / 255, 128 / 255, 0.82), Qt.rgba(138 / 255, 180 / 255, 255 / 255, 0.82))
    readonly property color rofiHighlightBg: pickScheme(MiscState.rofiTheme, Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.2), Qt.rgba(72 / 255, 191 / 255, 227 / 255, 0.2), Qt.rgba(254 / 255, 128 / 255, 25 / 255, 0.2), Qt.rgba(229 / 255, 122 / 255, 167 / 255, 0.2), Qt.rgba(167 / 255, 192 / 255, 128 / 255, 0.2), Qt.rgba(138 / 255, 180 / 255, 255 / 255, 0.2))
    readonly property color rofiDelegateText: pickScheme(MiscState.rofiTheme, "#f8f8f2", // pyrple
    "#c4cbd4", // gron
    "#ebdbb2", // gruvbox
    "#f6eaf1", // rose
    "#d3c6aa", // everforest
    "#eaf3ff") // soramane
    readonly property int rofiBlurRadius: MiscState.rofiRadius
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

    property color accent: pick("#bd93f9", "#3fa7c5", "#fe8019", "#e57aa7", "#a7c080", "#8ab4ff")

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
