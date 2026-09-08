import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

ColumnLayout {
    id: root
    spacing: 6

    property real opacityValue: 1.0
    property int blendMode: 0
    property bool opacityKeyed: false

    signal valueCommitted(string key, var value)
    signal keyframeToggled(string key, real currentValue)

    readonly property int gutter: 20

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Opacity"
            color: "#888888"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }

        XylaFloatInput {
            Layout.fillWidth: true
            decimals: 2
            stepSize: 0.01
            minValue: 0.0
            maxValue: 1.0
            value: root.opacityValue
            keyframeable: true
            hasKeyframe: root.opacityKeyed
            onKeyframeToggled: root.keyframeToggled("opacity", root.opacityValue)
            onValueCommitted: val => root.valueCommitted("opacity", val)
        }

        Item {
            Layout.preferredWidth: root.gutter
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Blend"
            color: "#888888"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }

        XylaSelect {
            Layout.fillWidth: true
            implicitHeight: 22
            currentIndex: root.blendMode
            model: ["Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten", "Add", "Difference"]
            onActivated: index => root.valueCommitted("blendMode", index)
        }

        Item {
            Layout.preferredWidth: root.gutter
        }
    }
}
