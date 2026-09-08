import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

ColumnLayout {
    id: root
    spacing: 6

    property real posX: 0.0
    property real posY: 0.0
    property real scaleX: 1.0
    property real scaleY: 1.0
    property real rotationVal: 0.0
    property bool uniformScale: true

    property bool posXKeyed: false
    property bool posYKeyed: false
    property bool scaleXKeyed: false
    property bool scaleYKeyed: false
    property bool rotationKeyed: false

    signal valueCommitted(string key, real value)
    signal keyframeToggled(string key, real currentValue)
    signal uniformScaleToggled

    readonly property int gutter: 20

    // Position
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Position"
            color: "#888888"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }

        XylaFloatInput {
            label: "X"
            accentColor: "#EF4444"
            Layout.fillWidth: true
            decimals: 3
            stepSize: 0.005
            value: root.posX
            keyframeable: true
            hasKeyframe: root.posXKeyed
            onKeyframeToggled: root.keyframeToggled("positionX", root.posX)
            onValueCommitted: val => root.valueCommitted("positionX", val)
        }

        XylaFloatInput {
            label: "Y"
            accentColor: "#22C55E"
            Layout.fillWidth: true
            decimals: 3
            stepSize: 0.005
            value: root.posY
            keyframeable: true
            hasKeyframe: root.posYKeyed
            onKeyframeToggled: root.keyframeToggled("positionY", root.posY)
            onValueCommitted: val => root.valueCommitted("positionY", val)
        }

        Item {
            Layout.preferredWidth: root.gutter
        }
    }

    // Scale
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Scale"
            color: "#888888"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }

        XylaFloatInput {
            label: "X"
            accentColor: "#EF4444"
            Layout.fillWidth: true
            decimals: 2
            stepSize: 0.01
            value: root.scaleX
            keyframeable: true
            hasKeyframe: root.scaleXKeyed
            onKeyframeToggled: root.keyframeToggled("scaleX", root.scaleX)
            onValueCommitted: val => {
                root.valueCommitted("scaleX", val);
                if (root.uniformScale) {
                    root.valueCommitted("scaleY", val);
                    if (root.scaleXKeyed && !root.scaleYKeyed)
                        root.keyframeToggled("scaleY", val);
                }
            }
        }

        XylaFloatInput {
            label: "Y"
            accentColor: "#22C55E"
            Layout.fillWidth: true
            decimals: 2
            stepSize: 0.01
            enabled: !root.uniformScale
            opacity: root.uniformScale ? 0.35 : 1.0
            value: root.scaleY
            keyframeable: true
            hasKeyframe: root.scaleYKeyed
            onKeyframeToggled: root.keyframeToggled("scaleY", root.scaleY)
            onValueCommitted: val => root.valueCommitted("scaleY", val)
        }

        XylaIconButton {
            iconSource: root.uniformScale ? "qrc:/assets/icons/link.svg" : "qrc:/assets/icons/unlink.svg"
            Layout.preferredWidth: root.gutter
            Layout.preferredHeight: root.gutter
            iconWidth: 14
            iconHeight: 14
            onClicked: root.uniformScaleToggled()
        }
    }

    // Rotation
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Rotation"
            color: "#888888"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }

        XylaFloatInput {
            label: "°"
            Layout.fillWidth: true
            decimals: 1
            stepSize: 1.0
            value: root.rotationVal
            keyframeable: true
            hasKeyframe: root.rotationKeyed
            onKeyframeToggled: root.keyframeToggled("rotation", root.rotationVal)
            onValueCommitted: val => root.valueCommitted("rotation", val)
        }

        Item {
            Layout.preferredWidth: root.gutter
        }
    }
}
