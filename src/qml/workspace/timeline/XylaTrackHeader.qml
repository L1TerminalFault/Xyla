import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

Item {
    id: root

    // Supplied from Model / Parent
    property string trackId: ""
    property string trackName: ""
    property int trackKind: 0 // 0 = Video, 1 = Audio
    property bool isVideo: trackKind === 0

    // Dynamic Sizing
    implicitWidth: 350
    property int expandedHeight: 150
    property int collapsedHeight: 49
    property int minHeight: 90
    property int maxHeight: 800
    property bool isCollapsed: false

    implicitHeight: isCollapsed ? collapsedHeight : expandedHeight

    // Track States
    property bool isLocked: false
    property bool isVideoDisabled: false
    property bool isAudioDisabled: false
    property bool isFxDisabled: false

    // Signals
    signal trackRenamed(string newName)
    signal lockToggled(bool locked)
    signal trackHeightChanged(int newHeight)

    // Smooth Collapse/Expand Height Animation (DISABLED DURING MOUSE DRAGGING FOR 0ms LATENCY)
    Behavior on implicitHeight {
        enabled: !resizeMouse.pressed
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    // Main Header Container Frame
    Rectangle {
        anchors.fill: parent
        color: "#181818"
        border.color: "#2d2d2d"
        border.width: 1
        clip: false

        Rectangle {
            id: accentStrip
            width: 4
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: root.isLocked ? "#e81123" : (root.isVideo ? "#00bcd4" : "#107c41")
            z: 2
        }

        RowLayout {
            id: topRow
            anchors.left: accentStrip.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 8
            height: 28
            spacing: 6
            z: 2

            Item {
                width: 24
                height: 24

                Image {
                    id: chevronIcon
                    anchors.centerIn: parent
                    source: "qrc:/assets/icons/chevron-down.svg"
                    sourceSize.width: 14
                    sourceSize.height: 14
                    rotation: root.isCollapsed ? -90 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isCollapsed = !root.isCollapsed;
                    }
                }
            }

            Text {
                id: collapsedTitleText
                text: root.trackName
                color: root.isLocked ? "#666666" : "#ffffff"
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                visible: root.isCollapsed
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 120
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 4
                enabled: !root.isLocked
                opacity: root.isLocked ? 0.3 : 1.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }

                XylaIconButton {
                    width: 24
                    height: 24
                    iconSource: "qrc:/assets/icons/sparkles.svg"
                    primary: root.isFxDisabled
                    onClicked: root.isFxDisabled = !root.isFxDisabled
                }

                XylaIconButton {
                    width: 24
                    height: 24
                    visible: root.isVideo
                    iconSource: root.isVideoDisabled ? "qrc:/assets/icons/eye-off.svg" : "qrc:/assets/icons/eye.svg"
                    primary: root.isVideoDisabled
                    onClicked: root.isVideoDisabled = !root.isVideoDisabled
                }

                XylaIconButton {
                    width: 24
                    height: 24
                    visible: !root.isVideo
                    iconSource: root.isAudioDisabled ? "qrc:/assets/icons/volume-off.svg" : "qrc:/assets/icons/volume.svg"
                    primary: root.isAudioDisabled
                    onClicked: root.isAudioDisabled = !root.isAudioDisabled
                }
            }

            XylaIconButton {
                width: 24
                height: 24
                iconSource: root.isLocked ? "qrc:/assets/icons/lock.svg" : "qrc:/assets/icons/lock-open.svg"
                primary: root.isLocked
                onClicked: {
                    root.isLocked = !root.isLocked;
                    root.lockToggled(root.isLocked);
                }
            }
        }

        Item {
            anchors.left: accentStrip.right
            anchors.leftMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: parent.width - 40
            height: 32
            z: 2
            visible: !root.isCollapsed

            Text {
                id: nameText
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: root.trackName
                color: root.isLocked ? "#666666" : "#ffffff"
                font.pixelSize: 18
                font.bold: true
                elide: Text.ElideRight
                visible: !nameInputWrapper.visible
            }

            Rectangle {
                id: nameInputWrapper
                anchors.fill: parent
                color: "#121212"
                border.color: "#2555D3"
                border.width: 1
                radius: 4
                visible: false

                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: root.trackName
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                    selectByMouse: true

                    onAccepted: submitRename()
                    onEditingFinished: submitRename()

                    function submitRename() {
                        if (!nameInputWrapper.visible)
                            return;
                        nameInputWrapper.visible = false;
                        var trimmed = text.trim();
                        if (trimmed.length > 0) {
                            root.trackName = trimmed;
                            root.trackRenamed(trimmed);
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                enabled: !root.isLocked && !nameInputWrapper.visible
                cursorShape: Qt.IBeamCursor
                onDoubleClicked: {
                    nameInput.text = root.trackName;
                    nameInputWrapper.visible = true;
                    nameInput.forceActiveFocus();
                    nameInput.selectAll();
                }
            }
        }

        Item {
            id: resizeHandleArea
            height: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.bottom
            z: 10
            visible: !root.isCollapsed

            Rectangle {
                id: resizeThumb
                height: 2
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: resizeMouse.containsMouse ? "#2555D3" : "transparent"
            }

            MouseArea {
                id: resizeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeVerCursor
                preventStealing: true

                property int startMouseY: 0
                property int startHeight: 0

                onPressed: function (mouse) {
                    var pt = mapToItem(root, mouse.x, mouse.y);
                    startMouseY = pt.y;
                    startHeight = root.expandedHeight;
                }

                onPositionChanged: function (mouse) {
                    if (pressed && !root.isCollapsed) {
                        var pt = mapToItem(root, mouse.x, mouse.y);
                        var deltaY = pt.y - startMouseY;
                        var newH = Math.max(root.minHeight, Math.min(root.maxHeight, startHeight + deltaY));
                        root.expandedHeight = newH;
                        root.trackHeightChanged(newH);
                    }
                }
            }
        }
    }
}
