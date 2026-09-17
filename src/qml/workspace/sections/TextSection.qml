import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

ColumnLayout {
    id: textSecRoot

    property string textContent: ""
    property string fontFamily: "Inter"
    property real fontSize: 72.0
    property real tracking: 0.0
    property real lineSpacing: 1.2

    // Stroke & Trim properties
    property int strokePosition: 0 // 0: Center, 1: Outer, 2: Inner
    property real strokeWidth: 0.0
    property color strokeColor: "#000000"
    property real trimStart: 0.0
    property real trimEnd: 1.0
    property real trimOffset: 0.0

    property color fillColor: "#ffffff"

    property bool fontSizeKeyed: false
    property bool trackingKeyed: false
    property bool strokeWidthKeyed: false
    property bool trimStartKeyed: false
    property bool trimEndKeyed: false
    property bool trimOffsetKeyed: false

    // Resizable TextArea height
    property real inputAreaHeight: 74
    readonly property real labelColumnWidth: 78

    signal valueCommitted(string key, var value)
    signal keyframeToggled(string key, var value)

    spacing: 10
    Layout.fillWidth: true

    // =========================================================================
    // REUSABLE UNBOXED COLLAPSIBLE SECTION COMPONENT
    // =========================================================================
    component CollapsibleSection: ColumnLayout {
        id: sectionRoot
        property string title: ""
        property bool expanded: true
        default property alias content: sectionContent.data

        Layout.fillWidth: true
        spacing: 8

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 22

            RowLayout {
                anchors.fill: parent
                spacing: 6

                Image {
                    width: 12
                    height: 12
                    source: "qrc:/assets/icons/chevron-right.svg"
                    sourceSize: Qt.size(12, 12)
                    rotation: sectionRoot.expanded ? 90 : 0
                    opacity: headerMouse.containsMouse ? 1.0 : 0.7

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Text {
                    text: sectionRoot.title
                    color: headerMouse.containsMouse ? "#ffffff" : "#dddddd"
                    font.pixelSize: 11
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: headerMouse.containsMouse ? "#3a3a3a" : "#242424"
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sectionRoot.expanded = !sectionRoot.expanded
            }
        }

        ColumnLayout {
            id: sectionContent
            Layout.fillWidth: true
            spacing: 8
            visible: sectionRoot.expanded
        }
    }

    // =========================================================================
    // 1. TYPOGRAPHY SECTION
    // =========================================================================
    CollapsibleSection {
        title: "Typography"
        expanded: true

        // Resizable TextArea Container
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: textSecRoot.inputAreaHeight

            TextArea {
                id: textInput
                anchors.fill: parent
                anchors.bottomMargin: 10
                text: textSecRoot.textContent
                color: "#ffffff"
                font.pixelSize: 12
                wrapMode: Text.Wrap
                padding: 8

                background: Rectangle {
                    color: "#101010"
                    radius: 4
                    border.color: textInput.activeFocus ? "#3b82f6" : "#242424"
                    border.width: 1
                }

                // Live update while typing in real time
                onTextEdited: {
                    textSecRoot.valueCommitted("text", text);
                }

                onEditingFinished: {
                    textSecRoot.valueCommitted("text", text);
                }
            }

            // Bottom Resize Drag Handle
            Item {
                id: resizeBar
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 10

                Image {
                    id: gripIcon
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: "qrc:/assets/icons/grip-horizontal.svg"
                    sourceSize: Qt.size(14, 14)
                    opacity: resizeMouse.containsMouse || resizeMouse.pressed ? 0.9 : 0.35
                }

                MouseArea {
                    id: resizeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeVerCursor
                    preventStealing: true

                    property real startGlobalY: 0
                    property real startHeight: 0

                    function getGlobalY(mouse) {
                        if (mouse.globalPosition !== undefined && mouse.globalPosition !== null) {
                            return mouse.globalPosition.y;
                        }
                        return mapToItem(null, 0, mouse.y).y;
                    }

                    onPressed: mouse => {
                        startGlobalY = getGlobalY(mouse);
                        startHeight = textSecRoot.inputAreaHeight;
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            var currentGlobalY = getGlobalY(mouse);
                            var delta = currentGlobalY - startGlobalY;
                            textSecRoot.inputAreaHeight = Math.max(48, Math.min(380, startHeight + delta));
                        }
                    }
                }
            }
        }

        // Font Family Selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Font"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaFontPicker {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                currentFont: textSecRoot.fontFamily
                onFontSelected: function (family) {
                    textSecRoot.valueCommitted("fontFamily", family);
                }
            }
        }

        // Fill Color
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Fill Color"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaColorPicker {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                selectedColor: textSecRoot.fillColor
                onColorCommitted: newCol => {
                    textSecRoot.valueCommitted("fillColor", newCol);
                }
            }
        }

        // Font Size
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Size"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaFloatInput {
                Layout.fillWidth: true
                value: textSecRoot.fontSize
                minValue: 10
                maxValue: 900
                stepSize: 1.0
                decimals: 0
                unit: "px"
                keyframeable: true
                hasKeyframe: textSecRoot.fontSizeKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("fontSize", textSecRoot.fontSize)
                onValueCommitted: function (newVal) {
                    textSecRoot.valueCommitted("fontSize", newVal);
                }
            }
        }

        // Tracking
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Tracking"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaFloatInput {
                Layout.fillWidth: true
                value: textSecRoot.tracking
                minValue: -50
                maxValue: 200
                stepSize: 1.0
                decimals: 0
                keyframeable: true
                hasKeyframe: textSecRoot.trackingKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("tracking", textSecRoot.tracking)
                onValueCommitted: function (newVal) {
                    textSecRoot.valueCommitted("tracking", newVal);
                }
            }
        }

        // Line Spacing
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Line Spacing"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaFloatInput {
                Layout.fillWidth: true
                value: textSecRoot.lineSpacing
                minValue: 0.5
                maxValue: 3.0
                stepSize: 0.05
                decimals: 2
                keyframeable: false
                onValueCommitted: function (newVal) {
                    textSecRoot.valueCommitted("lineSpacing", newVal);
                }
            }
        }
    }

    // =========================================================================
    // 2. STROKE & TRIM PATHS SECTION
    // =========================================================================
    CollapsibleSection {
        title: "Stroke"
        expanded: true

        // Stroke Position (Center / Outer / Inner)
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Position"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaSegmentedToggle {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                options: [
                    {
                        text: "Center",
                        value: 0
                    },
                    {
                        text: "Outer",
                        value: 1
                    },
                    {
                        text: "Inner",
                        value: 2
                    }
                ]
                currentIndex: textSecRoot.strokePosition
                onOptionSelected: (idx, val) => {
                    textSecRoot.strokePosition = val;
                    textSecRoot.valueCommitted("strokePosition", val);
                }
            }
        }

        // Stroke Width
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Width"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaFloatInput {
                Layout.fillWidth: true
                value: textSecRoot.strokeWidth
                minValue: 0
                maxValue: 40
                stepSize: 1.0
                decimals: 0
                unit: "px"
                keyframeable: true
                hasKeyframe: textSecRoot.strokeWidthKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("strokeWidth", textSecRoot.strokeWidth)
                onValueCommitted: function (newVal) {
                    textSecRoot.valueCommitted("strokeWidth", newVal);
                }
            }
        }

        // Stroke Color
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Color"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaColorPicker {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                selectedColor: textSecRoot.strokeColor
                onColorCommitted: newCol => {
                    textSecRoot.valueCommitted("strokeColor", newCol);
                }
            }
        }

        // Trim Start
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Trim Start"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaFloatInput {
                Layout.fillWidth: true
                value: textSecRoot.trimStart
                minValue: 0.0
                maxValue: 1.0
                stepSize: 0.01
                decimals: 2
                keyframeable: true
                hasKeyframe: textSecRoot.trimStartKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("trimStart", textSecRoot.trimStart)
                onValueCommitted: function (newVal) {
                    textSecRoot.valueCommitted("trimStart", newVal);
                }
            }
        }

        // Trim End
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Trim End"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaFloatInput {
                Layout.fillWidth: true
                value: textSecRoot.trimEnd
                minValue: 0.0
                maxValue: 1.0
                stepSize: 0.01
                decimals: 2
                keyframeable: true
                hasKeyframe: textSecRoot.trimEndKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("trimEnd", textSecRoot.trimEnd)
                onValueCommitted: function (newVal) {
                    textSecRoot.valueCommitted("trimEnd", newVal);
                }
            }
        }

        // Trim Offset
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Trim Offset"
                color: "#888888"
                font.pixelSize: 11
                Layout.preferredWidth: textSecRoot.labelColumnWidth
            }

            XylaFloatInput {
                Layout.fillWidth: true
                value: textSecRoot.trimOffset
                minValue: -10.0
                maxValue: 10.0
                stepSize: 0.01
                decimals: 2
                keyframeable: true
                hasKeyframe: textSecRoot.trimOffsetKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("trimOffset", textSecRoot.trimOffset)
                onValueCommitted: function (newVal) {
                    textSecRoot.valueCommitted("trimOffset", newVal);
                }
            }
        }
    }
}
