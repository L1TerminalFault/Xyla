import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: root

    // ============================================================
    // NEW ASSIGNED DATA PROPERTIES
    // ============================================================

    property string assetName: ""
    property string assetPath: ""
    property string assetDuration: "-"
    property string assetResolution: "-"
    property string assetType: "Media Clip"
    property bool isFolder: false

    // Internal fallback bindings to match original logic seamlessly
    property string fileName: root.assetName
    property string filePath: root.assetPath
    property bool isDir: root.isFolder
    property real fileSize: 0
    property int itemCount: 0
    property var lastModified: null

    // ============================================================
    // POPUP SETTINGS & FOCUS MANAGEMENT
    // ============================================================

    width: 400
    // Dynamic height calculation: Header (36) + Margins (12) + Preview Height. 
    // It expands and contracts dynamically based on what content is inside.
    height: 88 + (previewImage.status === Image.Ready ? Math.min(300, previewImage.paintedHeight) : 300)

    modal: true
    dim: true
    focus: true
    padding: 0

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onOpened: root.forceActiveFocus()
    // onOpened: surfaceContentLayout.forceActiveFocus()

    // Catch the key event at the root popup layer before focus shifts down
    // Keys.onPressed: (event) => {
    //     if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
    //         root.close()
    //         event.accepted = true
    //     }
    // }

    function openAt(px, py) {
        root.x = px;
        root.y = py;
        root.open();
    }

    function openWith(item) {
        assetName = item.name || item.fileName || "";
        assetPath = item.path || item.filePath || "";
        assetDuration = item.duration || "-";
        assetResolution = item.resolution || "-";
        isFolder = item.isFolder !== undefined ? item.isFolder : (item.isDir || false);
        assetType = item.assetType || (isFolder ? "Folder Bin" : "Media Clip");
        
        fileSize = item.fileSize || 0;
        itemCount = item.itemCount || 0;
        lastModified = item.lastModified || null;

        open();
    }

    function humanSize(bytes) {
        if (!bytes || bytes <= 0)
            return "-";

        if (bytes < 1024)
            return bytes + " B";

        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KB";

        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MB";

        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
    }

    function formatDate(dt) {
        if (!dt)
            return "-";

        return Qt.formatDateTime(dt, "yyyy-MM-dd  HH:mm");
    }

    // ============================================================
    // ANIMATION
    // ============================================================

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 150
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            property: "scale"
            from: 0.95
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 120
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            property: "scale"
            from: 1.0
            to: 0.95
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    // ============================================================
    // BACKGROUND
    // ============================================================

    background: Rectangle {
        id: surface

        anchors.fill: parent
        radius: 12

        color: "#161616"

        border.width: 1
        border.color: "#2d2d2d"

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#90000000"
            shadowBlur: 0.65
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
        }

        // ========================================================
        // CONTENT
        // ========================================================

        ColumnLayout {
            anchors.fill: parent

            spacing: 0

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }

            // ====================================================
            // HEADER
            // ====================================================

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14

                    anchors.verticalCenter: parent.verticalCenter

                    text: "Properties"

                    color: "#fff"

                    font.pixelSize: 12
                    // font.weight: Font.DemiBold
                }

                // XylaIconButton {
                //     anchors.right: parent.right
                //     anchors.rightMargin: 8
                //
                //     anchors.verticalCenter: parent.verticalCenter
                //
                //     width: 24
                //     height: 24
                //
                //     ghost: true
                //
                //     iconSource: "qrc:/assets/icons/x.svg"
                //
                //     tooltip: "Close"
                //     // ToolTip.visible: hovered
                //     // ToolTip.text: "Close"
                //
                //     onClicked: root.close()
                // }
            }

            // ====================================================
            // BODY
            // ====================================================

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: 0
                Layout.bottomMargin: 12

                spacing: 8

                // =================================================
                // PREVIEW
                // =================================================

Item {
    Layout.fillWidth: true
    // Automatically wraps to the exact image size, drops to 80 for folders, and caps at 140 max so it fits perfectly in a 200px popup
    Layout.preferredHeight: previewImage.status === Image.Ready ? Math.min(200, previewImage.paintedHeight) : 200

    Rectangle {
        id: previewClip
        anchors.fill: parent
        radius: 8
        color: "#0d0d0d"
        clip: true

        // Move Image & overlays down here so text overlays are drawn on top layer
        Image {
            id: previewImage
            anchors.fill: parent
            source: root.isDir ? "" : (root.filePath ? "image://thumbnails/" + root.filePath + "?width=600" : "")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            smooth: true
            visible: !root.isDir && status === Image.Ready
            layer.enabled: true
            layer.smooth: true
        }

        Rectangle {
            anchors.fill: parent
            visible: !root.isDir && previewImage.status === Image.Ready
            color: "#000000"
            opacity: 0.10
        }

        Item {
            anchors.fill: parent
            visible: root.isDir || previewImage.status !== Image.Ready
            Rectangle {
                anchors.centerIn: parent
                width: root.isDir ? 52 : 44
                height: root.isDir ? 52 : 44
                radius: root.isDir ? 14 : 10
                color: root.isDir ? "#282519" : "#202020"
                Image {
                    anchors.centerIn: parent
                    width: root.isDir ? 28 : 22
                    height: root.isDir ? 28 : 22
                    source: root.isDir ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/file.svg"
                    opacity: root.isDir ? 0.75 : 0.35
                }
            }
        }

        Rectangle {
            id: resolutionOverlay
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 8
            visible: !root.isDir && root.assetResolution !== "" && root.assetResolution !== "-"
            height: 18
            width: resText.implicitWidth + 12
            radius: 6
            color: "#181818"
            Text {
                id: resText
                anchors.centerIn: parent
                text: root.assetResolution
                color: "#fff"
                font.pixelSize: 10
                // font.bold: true
            }
        }

        Rectangle {
            id: durationOverlay
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            visible: !root.isDir && root.assetDuration !== "" && root.assetDuration !== "-"
            height: 18
            width: durationText.implicitWidth + 12
            radius: 6
            color: "#181818"
            Text {
                id: durationText
                anchors.centerIn: parent
                text: root.assetDuration
                color: "#fff"
                font.pixelSize: 10
                // font.bold: true
            }
        }

                        // Image {
                        //     id: previewImage
                        //
                        //     anchors.fill: parent
                        //
                        //     source: root.isDir
                        //             ? ""
                        //             : (root.filePath
                        //                ? "image://thumbnails/"
                        //                  + root.filePath
                        //                  + "?width=600"
                        //                : "")
                        //
                        //     fillMode: Image.PreserveAspectFit
                        //
                        //     asynchronous: true
                        //     cache: true
                        //     smooth: true
                        //
                        //     visible: !root.isDir &&
                        //              status === Image.Ready
                        //
                        //     layer.enabled: true
                        //     layer.smooth: true
                        // }

                        // Rectangle {
                        //     anchors.fill: parent
                        //
                        //     visible: !root.isDir &&
                        //              previewImage.status === Image.Ready
                        //
                        //     color: "#000000"
                        //
                        //     opacity: 0.10
                        // }

                        // Item {
                        //     anchors.fill: parent
                        //
                        //     visible: root.isDir ||
                        //              previewImage.status !== Image.Ready
                        //
                        //     Rectangle {
                        //         anchors.centerIn: parent
                        //
                        //         width: root.isDir ? 52 : 44
                        //         height: root.isDir ? 52 : 44
                        //
                        //         radius: root.isDir ? 14 : 10
                        //
                        //         color: root.isDir
                        //                ? "#282519"
                        //                : "#202020"
                        //
                        //         Image {
                        //             anchors.centerIn: parent
                        //
                        //             width: root.isDir ? 28 : 22
                        //             height: root.isDir ? 28 : 22
                        //
                        //             source: root.isDir
                        //                     ? "qrc:/assets/icons/folder.svg"
                        //                     : "qrc:/assets/icons/file.svg"
                        //
                        //             opacity: root.isDir ? 0.75 : 0.35
                        //         }
                        //     }
                        // }
                    }
                }

                // =================================================
                // FILE IDENTITY
                // =================================================

                // ColumnLayout {
                //     Layout.fillWidth: true
                //
                //     spacing: 1
                //
                //     Text {
                //         Layout.fillWidth: true
                //
                //         text: root.fileName || "Unnamed"
                //
                //         color: "#f1f1f1"
                //
                //         font.pixelSize: 14
                //         // font.weight: Font.DemiBold
                //
                //         horizontalAlignment: Text.AlignHCenter
                //
                //         elide: Text.ElideMiddle
                //
                //         maximumLineCount: 1
                //     }
                //
                //     Text {
                //         Layout.fillWidth: true
                //
                //         text: root.assetType
                //
                //         color: "#777777"
                //
                //         font.pixelSize: 10
                //
                //         horizontalAlignment: Text.AlignHCenter
                //     }
                // }

                // =================================================
                // METADATA
                // =================================================

                // RowLayout {
                //     Layout.fillWidth: true
                //
                //     spacing: 6
                //
                //     MetadataPill {
                //         Layout.fillWidth: true
                //
                //         iconSource: root.isDir
                //                     ? "qrc:/assets/icons/folder.svg"
                //                     : "qrc:/assets/icons/file.svg"
                //
                //         label: "TYPE"
                //
                //         value: root.assetType
                //     }
                //
                //     MetadataPill {
                //         Layout.fillWidth: true
                //
                //         iconSource: root.isDir
                //                     ? "qrc:/assets/icons/layers.svg"
                //                     : "qrc:/assets/icons/size.svg"
                //
                //         label: root.isDir
                //                ? "CONTENTS"
                //                : "SIZE"
                //
                //         value: root.isDir
                //                ? root.itemCount
                //                  + " item"
                //                  + (root.itemCount === 1 ? "" : "s")
                //                : (root.fileSize > 0 ? root.humanSize(root.fileSize) : root.assetResolution)
                //     }
                //
                //     MetadataPill {
                //         Layout.fillWidth: true
                //
                //         iconSource: "qrc:/assets/icons/duration.svg"
                //
                //         label: root.lastModified ? "MODIFIED" : "DURATION"
                //
                //         value: root.lastModified ? root.formatDate(root.lastModified) : root.assetDuration
                //     }
                // }

                // =================================================
                // LOCATION (HIDDEN IF ISFOLDER)
                // =================================================

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 3

                    visible: !root.isDir

                    // Text {
                    //     text: "Location"
                    //
                    //     color: "#666666"
                    //
                    //     font.pixelSize: 9
                    //     // font.weight: Font.DemiBold
                    // }

                    Rectangle {
                        Layout.fillWidth: true

                        Layout.preferredHeight: 32

                        radius: 8

                        color: "#111111"

                        // border.width: 1
                        // border.color: "#292929"

                        Text {
                            id: locationText

                            anchors.left: parent.left
                            anchors.right: copyButton.left

                            anchors.leftMargin: 10
                            anchors.rightMargin: 4

                            anchors.verticalCenter: parent.verticalCenter

                            text: root.filePath || "—"

                            color: "#dddddd"

                            font.pixelSize: 12

                            elide: Text.ElideMiddle

                            wrapMode: Text.NoWrap
                        }

                        XylaIconButton {
                            id: copyButton

                            anchors.right: parent.right
                            anchors.rightMargin: 4

                            anchors.verticalCenter: parent.verticalCenter

                            width: 24
                            height: 24

                            ghost: true

                            iconSource: "qrc:/assets/icons/copy.svg"

                            tooltip: "Copy location"

                            onClicked: {
                                if (typeof clipboardManager !== "undefined")
                                    clipboardManager.setText(root.filePath);
                            }
                        }
                    }
                }

                // =================================================
                // BOTTOM SPACE
                // =================================================

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    // ============================================================
    // METADATA PILL
    // ============================================================

    // component MetadataPill: Rectangle {
    //     id: metadataPill
    //
    //     property string iconSource: ""
    //     property string label: ""
    //     property string value: ""
    //
    //     Layout.preferredHeight: 46
    //
    //     radius: 8
    //
    //     color: "#1d1d1d"
    //
    //     border.width: 0
    //
    //     ColumnLayout {
    //         anchors.fill: parent
    //
    //         anchors.leftMargin: 8
    //         anchors.rightMargin: 8
    //
    //         anchors.topMargin: 5
    //         anchors.bottomMargin: 5
    //
    //         spacing: 2
    //
    //         RowLayout {
    //             Layout.fillWidth: true
    //
    //             spacing: 4
    //
    //             Image {
    //                 Layout.preferredWidth: 10
    //                 Layout.preferredHeight: 10
    //
    //                 source: metadataPill.iconSource
    //
    //                 opacity: 0.45
    //             }
    //
    //             Text {
    //                 Layout.fillWidth: true
    //
    //                 text: metadataPill.label
    //
    //                 color: "#5f5f5f"
    //
    //                 font.pixelSize: 8
    //                 // font.weight: Font.DemiBold
    //                 font.letterSpacing: 0.5
    //             }
    //         }
    //
    //         Text {
    //             Layout.fillWidth: true
    //
    //             text: metadataPill.value
    //
    //             color: "#c8c8c8"
    //
    //             font.pixelSize: 10
    //             // font.weight: Font.Medium
    //
    //             elide: Text.ElideMiddle
    //         }
    //     }
    // }
}
