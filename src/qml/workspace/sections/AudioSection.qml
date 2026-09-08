import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

ColumnLayout {
    id: root
    spacing: 6

    property real volume: 1.0
    property real pan: 0.0
    property bool volumeKeyed: false
    property bool panKeyed: false

    signal valueCommitted(string key, real value)
    signal keyframeToggled(string key, real currentValue)

    readonly property int gutter: 20

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Volume"
            color: "#888888"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }

        XylaFloatInput {
            label: "dB"
            Layout.fillWidth: true
            decimals: 2
            stepSize: 0.05
            minValue: 0.0
            maxValue: 4.0
            value: root.volume
            keyframeable: true
            hasKeyframe: root.volumeKeyed
            onKeyframeToggled: root.keyframeToggled("volume", root.volume)
            onValueCommitted: val => root.valueCommitted("volume", val)
        }

        Item {
            Layout.preferredWidth: root.gutter
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Pan"
            color: "#888888"
            font.pixelSize: 11
            Layout.preferredWidth: 55
        }

        XylaFloatInput {
            Layout.fillWidth: true
            decimals: 2
            stepSize: 0.02
            minValue: -1.0
            maxValue: 1.0
            value: root.pan
            keyframeable: true
            hasKeyframe: root.panKeyed
            onKeyframeToggled: root.keyframeToggled("pan", root.pan)
            onValueCommitted: val => root.valueCommitted("pan", val)
        }

        Item {
            Layout.preferredWidth: root.gutter
        }
    }
}
