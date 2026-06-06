import QtQuick
import QtQuick.Controls

ProgressBar {
    id: root
    property int valueBarWidth: 23
    property int valueBarHeight: 12
    property color highlightColor: "yellow"
    property color trackColor: "#313244"
    property alias radius: barBg.radius
    property string text

    default property Item textMask: Item {}

    text: Math.round(value * 100)

    font {
        pixelSize: 11
        family: "VictorMono Nerd Font"
        weight: Font.Bold
    }

    background: Item {
        implicitHeight: valueBarHeight
        implicitWidth: valueBarWidth
    }

    contentItem: Item {
        id: contentItem
        anchors.fill: parent

        Rectangle {
            id: barBg
            anchors.fill: parent
            radius: 2
            color: root.trackColor
        }

        Rectangle {
            id: barFill
            width: parent.width * root.visualPosition
            height: parent.height
            radius: 2
            color: root.highlightColor
        }

        ShaderEffect {
            anchors.fill: parent
            property var source: ShaderEffectSource {
                sourceItem: contentItem
                live: true
                hideSource: true
            }
            property var mask: ShaderEffectSource {
                sourceItem: root.textMask
                live: true
                hideSource: true
            }

            fragmentShader: "varying highp vec2 qt_TexCoord0;
                uniform sampler2D source;
                uniform sampler2D mask;
                uniform highp float qt_Opacity;
                void main() {
                    highp vec4 col = texture2D(source, qt_TexCoord0);
                    highp vec4 msk = texture2D(mask, qt_TexCoord0);
                    gl_FragColor = vec4(col.rgb, col.a * (1.0 - msk.a)) * qt_Opacity;
                }"
        }
    }
}
