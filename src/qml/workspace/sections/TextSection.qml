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
    property int fontWeight: 400

    // Alignment & Formatting
    property int horizontalAlignment: 1 // 0: Left, 1: Center, 2: Right, 3: Justify
    property bool italic: false
    property bool underline: false
    property bool strikethrough: false
    property bool isLinked: false
    property bool isList: false

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

    // ── Rich Text Selection State ────────────────────────────────
    readonly property bool hasTextSelection: textInput.selectionStart !== textInput.selectionEnd
    readonly property int textSelectionStart: Math.min(textInput.selectionStart, textInput.selectionEnd)
    readonly property int textSelectionLength: Math.abs(textInput.selectionEnd - textInput.selectionStart)

    // Resizable TextArea height
    property real inputAreaHeight: 74
    readonly property real controlHeight: 32

    // Emitted for Whole-Text Base Property changes
    signal valueCommitted(string key, var value)
    // Emitted when text is highlighted for Rich-Text Span formatting
    signal spanCommitted(int start, int length, string key, var value)
    signal keyframeToggled(string key, var value)

    // Helper to dispatch either a Rich Text Span or a Base Property
    function dispatchTextChange(key, val) {
        if (textSecRoot.hasTextSelection) {
            textSecRoot.spanCommitted(textSecRoot.textSelectionStart, textSecRoot.textSelectionLength, key, val);
        } else {
            textSecRoot.valueCommitted(key, val);
        }
    }

    spacing: 0
    Layout.fillWidth: true

    component FigmaSection: ColumnLayout {
        id: secRoot
        property string title: ""
        property bool showTopBorder: true
        default property alias content: secContent.data

        Layout.fillWidth: true
        spacing: 0

        Rectangle {
            visible: secRoot.showTopBorder
            Layout.fillWidth: true
            height: 1
            color: "#242424"
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 38

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 2

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

                // Rich Text indicator badge
                Rectangle {
                    visible: textSecRoot.hasTextSelection
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 4
                    height: 18
                    radius: 4
                    color: "#2563EB"
                    implicitWidth: selBadgeText.implicitWidth + 10

                    Text {
                        id: selBadgeText
                        anchors.centerIn: parent
                        text: "Selection: " + textSecRoot.textSelectionLength + " chars"
                        color: "#ffffff"
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }
        }

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
                selectByMouse: true
                selectedTextColor: "#ffffff"
                selectionColor: "#3B82F6"

                background: Rectangle {
                    color: "#121212"
                    radius: 7
                    border.color: textSecRoot.hasTextSelection ? "#3B82F6" : "#262626"
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
                textSecRoot.dispatchTextChange("fontFamily", family);
            }
        }

        // Font Weight + Font Size (Split 50/50 Equal Widths)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            XylaSelect {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: textSecRoot.controlHeight
                model: ["Regular", "Medium", "Semi Bold", "Bold", "Black"]
                currentIndex: {
                    var w = textSecRoot.fontWeight;
                    if (w >= 900)
                        return 4;
                    if (w >= 700)
                        return 3;
                    if (w >= 600)
                        return 2;
                    if (w >= 500)
                        return 1;
                    return 0; // 400 Regular
                }
                onActivated: index => {
                    var weights = [400, 500, 600, 700, 900];
                    var val = weights[index];
                    textSecRoot.fontWeight = val;
                    textSecRoot.dispatchTextChange("fontWeight", val);
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
                keyframeable: !textSecRoot.hasTextSelection
                hasKeyframe: textSecRoot.fontSizeKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("fontSize", textSecRoot.fontSize)
                onValueCommitted: function (newVal) {
                    textSecRoot.dispatchTextChange("fontSize", newVal);
                }
            }
        }

        // Line Spacing + Tracking
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

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
                keyframeable: !textSecRoot.hasTextSelection
                hasKeyframe: textSecRoot.trackingKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("tracking", textSecRoot.tracking)
                onValueCommitted: function (newVal) {
                    textSecRoot.dispatchTextChange("tracking", newVal);
                }
            }
        }

        // =====================================================================
        // ALIGNMENT & FORMATTING TOOLBAR
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 2

            // 1. Align Left
            ToolbarButton {
                iconSource: "qrc:/assets/icons/align-left.svg"
                isActive: textSecRoot.horizontalAlignment === 0
                onTriggered: {
                    textSecRoot.horizontalAlignment = 0;
                    textSecRoot.valueCommitted("horizontalAlignment", 0);
                }
            }

            // 2. Align Center
            ToolbarButton {
                iconSource: "qrc:/assets/icons/align-center.svg"
                isActive: textSecRoot.horizontalAlignment === 1
                onTriggered: {
                    textSecRoot.horizontalAlignment = 1;
                    textSecRoot.valueCommitted("horizontalAlignment", 1);
                }
            }

            // 3. Align Right
            ToolbarButton {
                iconSource: "qrc:/assets/icons/align-right.svg"
                isActive: textSecRoot.horizontalAlignment === 2
                onTriggered: {
                    textSecRoot.horizontalAlignment = 2;
                    textSecRoot.valueCommitted("horizontalAlignment", 2);
                }
            }

            // 4. Align Justified
            ToolbarButton {
                iconSource: "qrc:/assets/icons/align-justified.svg"
                isActive: textSecRoot.horizontalAlignment === 3
                onTriggered: {
                    textSecRoot.horizontalAlignment = 3;
                    textSecRoot.valueCommitted("horizontalAlignment", 3);
                }
            }

            // 5. Italic (Added)
            ToolbarButton {
                iconSource: "qrc:/assets/icons/italic.svg"
                isActive: textSecRoot.italic
                onTriggered: {
                    textSecRoot.italic = !textSecRoot.italic;
                    textSecRoot.dispatchTextChange("italic", textSecRoot.italic);
                }
            }

            // 6. Underline
            ToolbarButton {
                iconSource: "qrc:/assets/icons/underline.svg"
                isActive: textSecRoot.underline
                onTriggered: {
                    textSecRoot.underline = !textSecRoot.underline;
                    textSecRoot.dispatchTextChange("underline", textSecRoot.underline);
                }
            }

            // 7. Strikethrough
            ToolbarButton {
                iconSource: "qrc:/assets/icons/strikethrough.svg"
                isActive: textSecRoot.strikethrough
                onTriggered: {
                    textSecRoot.strikethrough = !textSecRoot.strikethrough;
                    textSecRoot.dispatchTextChange("strikethrough", textSecRoot.strikethrough);
                }
            }

            // 8. Link
            ToolbarButton {
                iconSource: "qrc:/assets/icons/link.svg"
                isActive: textSecRoot.isLinked
                onTriggered: {
                    textSecRoot.isLinked = true;
                    textSecRoot.valueCommitted("link", true);
                }
            }

            // 9. Unlink
            ToolbarButton {
                iconSource: "qrc:/assets/icons/unlink.svg"
                isActive: !textSecRoot.isLinked
                onTriggered: {
                    textSecRoot.isLinked = false;
                    textSecRoot.valueCommitted("link", false);
                }
            }

            // 10. List
            ToolbarButton {
                iconSource: "qrc:/assets/icons/list.svg"
                isActive: textSecRoot.isList
                onTriggered: {
                    textSecRoot.isList = !textSecRoot.isList;
                    textSecRoot.valueCommitted("list", textSecRoot.isList);
                }
            }
        }
    }

    component ToolbarButton: Rectangle {
        id: tbBtn
        property string iconSource: ""
        property bool isActive: false
        property string tooltipText: ""
        signal triggered

        Layout.fillWidth: true
        Layout.preferredHeight: 28
        radius: 5
        color: isActive ? "#262626" : (tbMouse.containsMouse ? "#1c1c1c" : "transparent")
        border.color: isActive ? "#333333" : "transparent"
        border.width: 1

        Image {
            anchors.centerIn: parent
            width: 14
            height: 14
            source: tbBtn.iconSource
            sourceSize.width: 14
            sourceSize.height: 14
            opacity: tbBtn.isActive ? 1.0 : (tbMouse.containsMouse ? 0.85 : 0.45)
        }

        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tbBtn.triggered()
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
                    textSecRoot.dispatchTextChange("fillColor", newCol);
                }
                onGradientCommitted: gradData => {
                    textSecRoot.valueCommitted("fillGradient", gradData);
                }
            }
        }
    }

    // =========================================================================
    // 3. STROKE SECTION
    // =========================================================================
    FigmaSection {
        title: "Stroke"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            XylaColorPicker {
                Layout.fillWidth: true
                Layout.preferredHeight: textSecRoot.controlHeight
                selectedColor: textSecRoot.strokeColor
                onColorCommitted: newCol => {
                    textSecRoot.dispatchTextChange("strokeColor", newCol);
                }
                onGradientCommitted: gradData => {
                    textSecRoot.valueCommitted("strokeGradient", gradData);
                }
            }
        }

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
                keyframeable: !textSecRoot.hasTextSelection
                hasKeyframe: textSecRoot.strokeWidthKeyed
                onKeyframeToggled: textSecRoot.keyframeToggled("strokeWidth", textSecRoot.strokeWidth)
                onValueCommitted: function (newVal) {
                    textSecRoot.dispatchTextChange("strokeWidth", newVal);
                }
            }
        }

        // Trim Path Keyframing Controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

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
