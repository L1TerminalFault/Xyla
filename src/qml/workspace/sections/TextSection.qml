import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: textSecRoot

    property string textContent: ""
    property string fontFamily: "Inter"
    property real fontSize: 72.0
    property real tracking: 0.0
    property real lineSpacing: 1.2
    property string fontWeight: "Regular"

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
    readonly property real controlHeight: 32

    signal valueCommitted(string key, var value)
    signal keyframeToggled(string key, var value)

    spacing: 0
    Layout.fillWidth: true
    Layout.rightMargin: 8

    // =========================================================================
    // FIGMA-STYLE FLAT SECTION COMPONENT
    // =========================================================================
    component FigmaSection: ColumnLayout {
        id: secRoot
        property string title: ""
        property bool showTopBorder: true
        default property alias content: secContent.data

        Layout.fillWidth: true
        spacing: 0

        // Subtle Top Hairline Separator
        Rectangle {
            visible: secRoot.showTopBorder
            Layout.fillWidth: true
            height: 1
            color: "#242424"
        }

        // Taller Section Header with Pure Typography (No chevrons, no middle lines)
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 38

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: secRoot.title
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        // Section Content
        ColumnLayout {
            id: secContent
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            spacing: 8
        }
    }

    // =========================================================================
    // 1. TYPOGRAPHY SECTION
    // =========================================================================
    FigmaSection {
        title: "Typography"
        showTopBorder: false

        // Text Content Input Area with Bottom Resizer
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
                    color: "#121212"
                    radius: 7
                    border.color: "#262626"
                    border.width: 1
                }

                onTextEdited: {
                    textSecRoot.valueCommitted("text", text);
                }

                onEditingFinished: {
                    textSecRoot.valueCommitted("text", text);
                }
            }

            // Bottom Resize Handle
            Item {
                id: resizeBar
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 10

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: "qrc:/assets/icons/grip-horizontal.svg"
                    sourceSize: Qt.size(14, 14)
                    opacity: resizeMouse.containsMouse || resizeMouse.pressed ? 0.8 : 0.3
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
                        return mouse.globalPosition !== undefined ? mouse.globalPosition.y : mapToItem(null, 0, mouse.y).y;
                    }

                    onPressed: mouse => {
                        startGlobalY = getGlobalY(mouse);
                        startHeight = textSecRoot.inputAreaHeight;
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            var delta = getGlobalY(mouse) - startGlobalY;
                            textSecRoot.inputAreaHeight = Math.max(48, Math.min(380, startHeight + delta));
                        }
                    }
                }
            }
        }

        // Font Family (Full Width Row)
        XylaFontPicker {
            Layout.fillWidth: true
            Layout.preferredHeight: textSecRoot.controlHeight
            currentFont: textSecRoot.fontFamily
            onFontSelected: function (family) {
                textSecRoot.valueCommitted("fontFamily", family);
            }
        }

        // Font Weight + Font Size (Split 50/50 Equal Widths)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Weight selector
            XylaSelect {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: textSecRoot.controlHeight
                model: ["Regular", "Medium", "Semi Bold", "Bold", "Black"]
                currentIndex: 0
                onActivated: index => {
                    textSecRoot.fontWeight = model[index];
                }
            }

            // Font Size
            XylaFloatInput {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: textSecRoot.controlHeight
                label: "A"
                value: textSecRoot.fontSize
                minValue: 1
                maxValue: 1000
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

        // Line Spacing + Tracking (Split 50/50 Equal Widths)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Line Spacing
            XylaFloatInput {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: textSecRoot.controlHeight
                icon: "qrc:/assets/icons/line-height.svg"
                value: textSecRoot.lineSpacing
                minValue: 0.1
                maxValue: 5.0
                stepSize: 0.05
                decimals: 2
                keyframeable: false
                onValueCommitted: function (newVal) {
                    textSecRoot.valueCommitted("lineSpacing", newVal);
                }
            }

            // Tracking
            XylaFloatInput {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: textSecRoot.controlHeight
                icon: "qrc:/assets/icons/letter-spacing.svg"
                value: textSecRoot.tracking
                minValue: -100
                maxValue: 300
                stepSize: 1.0
                decimals: 0
                unit: "%"
                keyframeable: true
                hasKeyframe: textSecRoot.trackingKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("tracking", textSecRoot.tracking)
                onValueCommitted: function (newVal) {
                    textSecRoot.valueCommitted("tracking", newVal);
                }
            }
        }
    }

    // =========================================================================
    // 2. FILL SECTION
    // =========================================================================
    FigmaSection {
        title: "Fill"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            XylaColorPicker {
                Layout.fillWidth: true
                Layout.preferredHeight: textSecRoot.controlHeight
                selectedColor: textSecRoot.fillColor
                onColorCommitted: newCol => {
                    textSecRoot.valueCommitted("fillColor", newCol);
                }
            }
        }
    }

    // =========================================================================
    // 3. STROKE SECTION
    // =========================================================================
    FigmaSection {
        title: "Stroke"

        // Stroke Color
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            XylaColorPicker {
                Layout.fillWidth: true
                Layout.preferredHeight: textSecRoot.controlHeight
                selectedColor: textSecRoot.strokeColor
                onColorCommitted: newCol => {
                    textSecRoot.valueCommitted("strokeColor", newCol);
                }
            }
        }

        // Stroke Position & Stroke Width (50/50 Split)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            XylaSelect {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: textSecRoot.controlHeight
                model: ["Center", "Outside", "Inside"]
                currentIndex: textSecRoot.strokePosition === 1 ? 1 : (textSecRoot.strokePosition === 2 ? 2 : 0)
                onActivated: index => {
                    var val = index === 1 ? 1 : (index === 2 ? 2 : 0);
                    textSecRoot.strokePosition = val;
                    textSecRoot.valueCommitted("strokePosition", val);
                }
            }

            // Stroke Width
            XylaFloatInput {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: textSecRoot.controlHeight
                icon: "qrc:/assets/icons/border-outer.svg"
                value: textSecRoot.strokeWidth
                minValue: 0
                maxValue: 100
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

        // Trim Path Keyframing Controls (Start / End 50/50 Split)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Trim Start
            XylaFloatInput {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: textSecRoot.controlHeight
                label: "Start"
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

            // Trim End
            XylaFloatInput {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: textSecRoot.controlHeight
                label: "End"
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

        // Trim Offset (Full Width)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            XylaFloatInput {
                Layout.fillWidth: true
                Layout.preferredHeight: textSecRoot.controlHeight
                icon: "qrc:/assets/icons/arrows-left-right.svg"
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
