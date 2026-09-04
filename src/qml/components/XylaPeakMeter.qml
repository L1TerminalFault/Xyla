import QtQuick
import QtQuick.Layouts

Item {
    id: root
    enabled: false

    property real peakLeft: 0.0
    property real peakRight: 0.0
    property real minDb: -60.0
    property real maxDb: 6.0
    property real itemWidth: 6

    Layout.fillHeight: true
    Layout.preferredWidth: (itemWidth * 2) + 38
    Layout.alignment: Qt.AlignHCenter

    property real peakHoldLeft: 0.0
    property real peakHoldRight: 0.0
    property bool leftClipped: false
    property bool rightClipped: false

    function dbToNormalized(db) {
        var clamped = Math.max(root.minDb, Math.min(root.maxDb, db))
        return (clamped - root.minDb) / (root.maxDb - root.minDb)
    }

    function linearToNormalized(linear) {
        if (linear <= 0.00001)
            return 0.0
        var db = 20.0 * (Math.log(linear) / Math.LN10)
        return dbToNormalized(db)
    }

    readonly property real availableHeight: ruler.height > 0 ? ruler.height : 220

    readonly property int stepSizeDb: {
        if (availableHeight > 300) return 6
        if (availableHeight > 150) return 12
        return 24
    }

    readonly property var dynamicTicks: {
        var ticks = []
        for (var d = Math.floor(root.maxDb); d >= Math.floor(root.minDb); d--) {
            var isMajor = (d === 0
                           || d === Math.floor(root.maxDb)
                           || d === Math.floor(root.minDb)
                           || d % stepSizeDb === 0)
            var isMinor = (d % 2 === 0)
            if (isMajor || isMinor)
                ticks.push({ dbValue: d, isTextLabel: isMajor })
        }
        return ticks
    }

    Timer {
        id: decayTimer
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            var normL = root.linearToNormalized(root.peakLeft)
            var normR = root.linearToNormalized(root.peakRight)

            if (normL >= root.peakHoldLeft)
                root.peakHoldLeft = normL
            else
                root.peakHoldLeft = Math.max(0.0, root.peakHoldLeft - 0.005)

            if (normR >= root.peakHoldRight)
                root.peakHoldRight = normR
            else
                root.peakHoldRight = Math.max(0.0, root.peakHoldRight - 0.005)

            if (normL >= root.dbToNormalized(0.0)) {
                root.leftClipped = true
                clipHoldTimer.restart()
            }
            if (normR >= root.dbToNormalized(0.0)) {
                root.rightClipped = true
                clipHoldTimer.restart()
            }
        }
    }

    Timer {
        id: clipHoldTimer
        interval: 2000
        repeat: false
        onTriggered: {
            root.leftClipped = false
            root.rightClipped = false
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 4

        // DYNAMIC RULER
        Item {
            id: ruler
            Layout.fillHeight: true
            Layout.preferredWidth: 28
            // Use Layout margins instead of anchors (fixes the warning)
            Layout.topMargin: 7
            Layout.bottomMargin: 1

            Repeater {
                model: root.dynamicTicks
                delegate: Item {
                    required property var modelData
                    readonly property real normY: 1.0 - root.dbToNormalized(modelData.dbValue)

                    y: Math.round(normY * (ruler.height - 1))
                    width: ruler.width
                    height: 1

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: modelData.dbValue === 0 ? 6 : (modelData.isTextLabel ? 5 : 2)
                        height: 1
                        color: modelData.dbValue === 0 ? "#ef4444"
                             : (modelData.dbValue > 0 ? "#f59e0b"
                             : (modelData.isTextLabel ? "#666666" : "#333333"))
                    }

                    Text {
                        visible: modelData.isTextLabel
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: {
                            if (modelData.dbValue === Math.floor(root.maxDb)) return 3
                            if (modelData.dbValue === Math.floor(root.minDb)) return -3
                            return 0
                        }
                        text: modelData.dbValue > 0 ? ("+" + modelData.dbValue)
                                                   : modelData.dbValue.toString()
                        color: modelData.dbValue === 0 ? "#ef4444"
                             : (modelData.dbValue > 0 ? "#f59e0b" : "#888888")
                        font.pixelSize: 8
                        font.weight: modelData.dbValue === 0 ? Font.Bold : Font.Normal
                        font.family: "Monospace"
                    }
                }
            }
        }

        // L / R METERS
        Repeater {
            model: [
                { name: "L", peak: root.peakLeft,  hold: root.peakHoldLeft,  clipped: root.leftClipped  },
                { name: "R", peak: root.peakRight, hold: root.peakHoldRight, clipped: root.rightClipped }
            ]
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillHeight: true
                Layout.preferredWidth: root.itemWidth
                spacing: 2

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 1
                    color: modelData.clipped ? "#ef4444" : "#111111"
                    border.color: modelData.clipped ? "#f87171" : "#222222"
                    border.width: 1
                }

                Item {
                    id: meterTrack
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        border.color: "#1a1a1a"
                        border.width: 1
                        radius: 1
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * root.linearToNormalized(modelData.peak)
                        clip: true

                        Rectangle {
                            width: meterTrack.width
                            height: meterTrack.height
                            anchors.bottom: parent.bottom
                            radius: 1
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: "#ef4444" }
                                GradientStop { position: 1.0 - root.dbToNormalized(0.0);  color: "#ef4444" }
                                GradientStop { position: 1.0 - root.dbToNormalized(-6.0); color: "#f59e0b" }
                                GradientStop { position: 1.0 - root.dbToNormalized(-18.0); color: "#10b981" }
                                GradientStop { position: 1.0; color: "#047857" }
                            }
                        }
                    }

                    Rectangle {
                        visible: modelData.hold > 0.01
                        width: parent.width
                        height: 2
                        y: Math.round((1.0 - modelData.hold) * (parent.height - height))
                        color: modelData.hold >= root.dbToNormalized(0.0) ? "#ef4444" : "#ffffff"
                        z: 10
                    }
                }
            }
        }
    }
}
