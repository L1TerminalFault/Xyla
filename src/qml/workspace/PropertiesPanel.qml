import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: propRoot

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property string activeClipId: (activeTimelineModel && activeTimelineModel.selectedClipId !== undefined) ? activeTimelineModel.selectedClipId : ""
    property var activeClipData: (activeTimelineModel && activeTimelineModel.selectedClipData !== undefined) ? activeTimelineModel.selectedClipData : null

    property var clipTransform: (activeClipData && activeClipData.transform) ? activeClipData.transform : null
    property var clipAudio: (activeClipData && activeClipData.audio) ? activeClipData.audio : null

    property bool hasClip: activeClipId !== "" && activeClipData !== null
    property int currentTab: 0

    // Local Transform State
    property real clipPosX: 0.0
    property real clipPosY: 0.0
    property real clipScaleX: 1.0
    property real clipScaleY: 1.0
    property bool uniformScale: true
    property real clipRotation: 0.0
    property real clipOpacity: 1.0
    property int clipBlendMode: 0

    // Local Audio State
    property real clipVolume: 1.0
    property real clipPan: 0.0

    readonly property int trailingGutterWidth: 20

    onActiveClipDataChanged: {
        if (!activeClipData) {
            clipPosX = 0.0;
            clipPosY = 0.0;
            clipScaleX = 1.0;
            clipScaleY = 1.0;
            clipRotation = 0.0;
            clipOpacity = 1.0;
            clipBlendMode = 0;
            clipVolume = 1.0;
            clipPan = 0.0;
            return;
        }

        if (clipTransform) {
            clipPosX = clipTransform.positionX ?? 0.0;
            clipPosY = clipTransform.positionY ?? 0.0;
            clipScaleX = clipTransform.scaleX ?? 1.0;
            clipScaleY = clipTransform.scaleY ?? 1.0;
            clipRotation = clipTransform.rotation ?? 0.0;
            clipOpacity = clipTransform.opacity ?? 1.0;
            clipBlendMode = activeClipData.blendMode ?? 0;
        }

        if (clipAudio) {
            clipVolume = clipAudio.volume ?? 1.0;
            clipPan = clipAudio.pan ?? 0.0;
        }
    }

    function commitTransform(key, val) {
        if (activeTimelineModel && hasClip) {
            activeTimelineModel.updateClipTransformProperty(activeClipId, key, val);
        }
    }

    function commitAudio(key, val) {
        if (activeTimelineModel && hasClip) {
            activeTimelineModel.updateClipAudioProperty(activeClipId, key, val);
        }
    }

    function resetTransforms() {
        clipPosX = 0.0;
        clipPosY = 0.0;
        clipScaleX = 1.0;
        clipScaleY = 1.0;
        clipRotation = 0.0;
        clipOpacity = 1.0;
        clipBlendMode = 0;
        commitTransform("positionX", 0.0);
        commitTransform("positionY", 0.0);
        commitTransform("scaleX", 1.0);
        commitTransform("scaleY", 1.0);
        commitTransform("rotation", 0.0);
        commitTransform("opacity", 1.0);
        commitTransform("blendMode", 0);
    }

    function resetAudio() {
        clipVolume = 1.0;
        clipPan = 0.0;
        commitAudio("volume", 1.0);
        commitAudio("pan", 0.0);
    }

    // =========================================================
    // MODULAR COMPONENT: Collapsible Accordion Section
    // =========================================================
    component XylaCollapsibleSection: ColumnLayout {
        id: sectionRoot
        property string title: "Section"
        property bool expanded: true
        default property alias contentData: contentSlot.data

        Layout.fillWidth: true
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 24
            radius: 3
            color: headerMouse.containsMouse ? "#222222" : "#191919"

            Behavior on color {
                ColorAnimation {
                    duration: 100
                    easing.type: Easing.OutCubic
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: sectionRoot.title
                    color: "#bbbbbb"
                    font.pixelSize: 10
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    Layout.fillWidth: true
                }

                Image {
                    source: "qrc:/assets/icons/chevron-down.svg"
                    sourceSize.width: 14
                    sourceSize.height: 14
                    opacity: headerMouse.containsMouse ? 1.0 : 0.55
                    rotation: sectionRoot.expanded ? 0 : -90

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
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

        Item {
            id: contentContainer
            Layout.fillWidth: true
            clip: true
            visible: implicitHeight > 0
            implicitHeight: sectionRoot.expanded ? contentSlot.implicitHeight + 16 : 0
            opacity: sectionRoot.expanded ? 1.0 : 0.0

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                id: contentSlot
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                spacing: 6
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#161616"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        opacity: propRoot.hasClip ? 1.0 : 0.18
        enabled: propRoot.hasClip

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        // =========================================================
        // 1. BLENDER-STYLE VERTICAL SIDEBAR (Left)
        // =========================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 38
            color: "#181818"

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: "#242424"
            }

            Column {
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: [
                        {
                            icon: "qrc:/assets/icons/video.svg",
                            tooltip: "Video"
                        },
                        {
                            icon: "qrc:/assets/icons/volume.svg",
                            tooltip: "Audio"
                        },
                        {
                            icon: "qrc:/assets/icons/info-circle.svg",
                            tooltip: "Metadata"
                        }
                    ]

                    delegate: Rectangle {
                        id: tabButton
                        width: 28
                        height: 28
                        radius: 5
                        color: propRoot.currentTab === index ? "#282828" : (tabBtnMouse.containsMouse ? "#202020" : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: -4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: 16
                            radius: 1
                            color: "#3b82f6"
                            visible: propRoot.currentTab === index
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 15
                            height: 15
                            source: modelData.icon
                            opacity: propRoot.currentTab === index ? 1.0 : (tabBtnMouse.containsMouse ? 0.75 : 0.4)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                        }

                        MouseArea {
                            id: tabBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: propRoot.currentTab = index
                        }
                    }
                }
            }
        }

        // =========================================================
        // 2. MAIN PROPERTIES CONTENT AREA
        // =========================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Header Strip
            Rectangle {
                Layout.fillWidth: true
                height: 32
                color: "#181818"

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: "#242424"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8

                    Text {
                        text: propRoot.currentTab === 0 ? "Video Properties" : (propRoot.currentTab === 1 ? "Audio Properties" : "Clip Information")
                        color: "#dddddd"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    XylaIconButton {
                        iconSource: "qrc:/assets/icons/rotate.svg"
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        tooltip: "Reset All Parameters"
                        onClicked: {
                            if (propRoot.currentTab === 0)
                                propRoot.resetTransforms();
                            else if (propRoot.currentTab === 1)
                                propRoot.resetAudio();
                        }
                    }
                }
            }

            ScrollView {
                id: propScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                StackLayout {
                    width: propScroll.availableWidth
                    currentIndex: propRoot.currentTab

                    // ==========================================
                    // TAB 0: VIDEO INTRINSICS
                    // ==========================================
                    ColumnLayout {
                        width: propScroll.availableWidth
                        spacing: 2
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8

                        XylaCollapsibleSection {
                            title: "Transform"

                            // Position Row: Label + X + Y + Gutter Spacer
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
                                    value: propRoot.clipPosX
                                    onValueCommitted: val => {
                                        propRoot.clipPosX = val;
                                        propRoot.commitTransform("positionX", val);
                                    }
                                }

                                XylaFloatInput {
                                    label: "Y"
                                    accentColor: "#22C55E"
                                    Layout.fillWidth: true
                                    decimals: 3
                                    stepSize: 0.005
                                    value: propRoot.clipPosY
                                    onValueCommitted: val => {
                                        propRoot.clipPosY = val;
                                        propRoot.commitTransform("positionY", val);
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: propRoot.trailingGutterWidth
                                }
                            }

                            // Scale Row: Label + X + Y + Link Toggle Button
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
                                    value: propRoot.clipScaleX
                                    onValueCommitted: val => {
                                        propRoot.clipScaleX = val;
                                        propRoot.commitTransform("scaleX", val);
                                        if (propRoot.uniformScale) {
                                            propRoot.clipScaleY = val;
                                            propRoot.commitTransform("scaleY", val);
                                        }
                                    }
                                }

                                XylaFloatInput {
                                    label: "Y"
                                    accentColor: "#22C55E"
                                    Layout.fillWidth: true
                                    decimals: 2
                                    stepSize: 0.01
                                    enabled: !propRoot.uniformScale
                                    opacity: propRoot.uniformScale ? 0.35 : 1.0
                                    value: propRoot.clipScaleY
                                    onValueCommitted: val => {
                                        propRoot.clipScaleY = val;
                                        propRoot.commitTransform("scaleY", val);
                                    }
                                }

                                XylaIconButton {
                                    iconSource: propRoot.uniformScale ? "qrc:/assets/icons/link.svg" : "qrc:/assets/icons/unlink.svg"
                                    Layout.preferredWidth: propRoot.trailingGutterWidth
                                    Layout.preferredHeight: propRoot.trailingGutterWidth
                                    iconWidth: 14
                                    iconHeight: 14
                                    onClicked: propRoot.uniformScale = !propRoot.uniformScale
                                }
                            }

                            // Rotation Row: Label + Input + Gutter Spacer
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
                                    unit: "°"
                                    Layout.fillWidth: true
                                    decimals: 1
                                    stepSize: 1.0
                                    value: propRoot.clipRotation
                                    onValueCommitted: val => {
                                        propRoot.clipRotation = val;
                                        propRoot.commitTransform("rotation", val);
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: propRoot.trailingGutterWidth
                                }
                            }
                        }

                        // SECTION 2: COMPOSITING
                        XylaCollapsibleSection {
                            title: "Compositing"

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
                                    value: propRoot.clipOpacity
                                    onValueCommitted: val => {
                                        propRoot.clipOpacity = val;
                                        propRoot.commitTransform("opacity", val);
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: propRoot.trailingGutterWidth
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
                                    currentIndex: propRoot.clipBlendMode
                                    model: ["Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten", "Add", "Difference"]
                                    onActivated: index => {
                                        propRoot.clipBlendMode = index;
                                        propRoot.commitTransform("blendMode", index);
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: propRoot.trailingGutterWidth
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    // ==========================================
                    // TAB 1: AUDIO INTRINSICS
                    // ==========================================
                    ColumnLayout {
                        width: propScroll.availableWidth
                        spacing: 2
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8

                        XylaCollapsibleSection {
                            title: "Audio Controls"

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
                                    value: propRoot.clipVolume
                                    onValueCommitted: val => {
                                        propRoot.clipVolume = val;
                                        propRoot.commitAudio("volume", val);
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: propRoot.trailingGutterWidth
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
                                    value: propRoot.clipPan
                                    onValueCommitted: val => {
                                        propRoot.clipPan = val;
                                        propRoot.commitAudio("pan", val);
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: propRoot.trailingGutterWidth
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    // ==========================================
                    // TAB 2: METADATA
                    // ==========================================
                    ColumnLayout {
                        width: propScroll.availableWidth
                        spacing: 2
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8

                        XylaCollapsibleSection {
                            title: "File Information"

                            RowLayout {
                                Text {
                                    text: "Name:"
                                    color: "#666666"
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 55
                                }
                                Text {
                                    text: propRoot.activeClipData ? propRoot.activeClipData.name : ""
                                    color: "#cccccc"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                Text {
                                    text: "Duration:"
                                    color: "#666666"
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 55
                                }
                                Text {
                                    text: propRoot.activeClipData ? (propRoot.activeClipData.durationFrames + " frames") : ""
                                    color: "#cccccc"
                                    font.pixelSize: 11
                                }
                            }

                            RowLayout {
                                Text {
                                    text: "Asset ID:"
                                    color: "#666666"
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 55
                                }
                                Text {
                                    text: propRoot.activeClipData ? propRoot.activeClipData.assetId : ""
                                    color: "#888888"
                                    font.pixelSize: 10
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }
        }
    }
}
