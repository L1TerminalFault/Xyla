import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
    // POPUP
    // ============================================================

    width: 440
    height: root.isDir ? 340 : 500

    modal: true
    dim: true

    padding: 0

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

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
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                from: 0
                to: 1
                duration: 150
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: surface
                property: "scale"
                from: 0.94
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                from: 1
                to: 0
                duration: 100
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: surface
                property: "scale"
                from: 1
                to: 0.96
                duration: 100
                easing.type: Easing.InCubic
            }
        }
    }

    // ============================================================
    // BACKGROUND
    // ============================================================

    background: Rectangle {
        id: surface

        radius: 14

        color: "#161616"

        border.width: 1
        border.color: "#303030"

        scale: 1

        // ========================================================
        // CONTENT
        // ========================================================

        ColumnLayout {
            anchors.fill: parent

            spacing: 0

            // ====================================================
            // HEADER
            // ====================================================

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18

                    anchors.verticalCenter: parent.verticalCenter

                    text: "Properties"

                    color: "#ededed"

                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                XylaIconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 10

                    anchors.verticalCenter: parent.verticalCenter

                    width: 28
                    height: 28

                    ghost: true

                    iconSource: "qrc:/assets/icons/x.svg"

                    ToolTip.visible: hovered
                    ToolTip.text: "Close"

                    onClicked: root.close()
                }
            }

            // ====================================================
            // BODY
            // ====================================================

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 2
                Layout.bottomMargin: 16

                spacing: 12

                // =================================================
                // PREVIEW
                // =================================================

                Item {
                    Layout.fillWidth: true

                    Layout.preferredHeight: root.isDir ? 110 : 196

                    // ------------------------------------------------
                    // OUTER CLIP
                    // ------------------------------------------------

                    Rectangle {
                        id: previewClip

                        anchors.fill: parent

                        radius: 12

                        color: "#0d0d0d"

                        clip: true

                        border.width: 1
                        border.color: "#303030"

                        // ------------------------------------------------
                        // IMAGE
                        // ------------------------------------------------

                        Image {
                            id: previewImage

                            anchors.fill: parent

                            source: root.isDir
                                    ? ""
                                    : (root.filePath
                                       ? "image://thumbnails/"
                                         + root.filePath
                                         + "?width=900"
                                       : "")

                            fillMode: Image.PreserveAspectFit

                            asynchronous: true
                            cache: true
                            smooth: true

                            visible: !root.isDir &&
                                     status === Image.Ready

                            layer.enabled: true
                            layer.smooth: true
                        }

                        // ------------------------------------------------
                        // IMAGE BACKDROP
                        // ------------------------------------------------

                        Rectangle {
                            anchors.fill: parent

                            visible: !root.isDir &&
                                     previewImage.status === Image.Ready

                            color: "#000000"

                            opacity: 0.10
                        }

                        // ------------------------------------------------
                        // FOLDER / NO PREVIEW
                        // ------------------------------------------------

                        Item {
                            anchors.fill: parent

                            visible: root.isDir ||
                                     previewImage.status !== Image.Ready

                            Rectangle {
                                anchors.centerIn: parent

                                width: root.isDir ? 68 : 58
                                height: root.isDir ? 68 : 58

                                radius: root.isDir ? 20 : 16

                                color: root.isDir
                                       ? "#282519"
                                       : "#202020"

                                Image {
                                    anchors.centerIn: parent

                                    width: root.isDir ? 36 : 28
                                    height: root.isDir ? 36 : 28

                                    source: root.isDir
                                            ? "qrc:/assets/icons/folder.svg"
                                            : "qrc:/assets/icons/file.svg"

                                    opacity: root.isDir ? 0.75 : 0.35
                                }
                            }
                        }
                    }
                }

                // =================================================
                // FILE IDENTITY
                // =================================================

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 3

                    Text {
                        Layout.fillWidth: true

                        text: root.fileName || "Unnamed"

                        color: "#f1f1f1"

                        font.pixelSize: 16
                        font.weight: Font.DemiBold

                        horizontalAlignment: Text.AlignHCenter

                        elide: Text.ElideMiddle

                        maximumLineCount: 2
                    }

                    Text {
                        Layout.fillWidth: true

                        text: root.assetType

                        color: "#777777"

                        font.pixelSize: 10

                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // =================================================
                // METADATA
                // =================================================

                RowLayout {
                    Layout.fillWidth: true

                    spacing: 8

                    // ------------------------------------------------
                    // TYPE
                    // ------------------------------------------------

                    MetadataPill {
                        Layout.fillWidth: true

                        iconSource: root.isDir
                                    ? "qrc:/assets/icons/folder.svg"
                                    : "qrc:/assets/icons/file.svg"

                        label: "TYPE"

                        value: root.assetType
                    }

                    // ------------------------------------------------
                    // SIZE / CONTENTS
                    // ------------------------------------------------

                    MetadataPill {
                        Layout.fillWidth: true

                        iconSource: root.isDir
                                    ? "qrc:/assets/icons/layers.svg"
                                    : "qrc:/assets/icons/size.svg"

                        label: root.isDir
                               ? "CONTENTS"
                               : "SIZE"

                        value: root.isDir
                               ? root.itemCount
                                 + " item"
                                 + (root.itemCount === 1 ? "" : "s")
                               : (root.fileSize > 0 ? root.humanSize(root.fileSize) : root.assetResolution)
                    }

                    // ------------------------------------------------
                    // MODIFIED / DURATION
                    // ------------------------------------------------

                    MetadataPill {
                        Layout.fillWidth: true

                        iconSource: "qrc:/assets/icons/duration.svg"

                        label: root.lastModified ? "MODIFIED" : "DURATION"

                        value: root.lastModified ? root.formatDate(root.lastModified) : root.assetDuration
                    }
                }

                // =================================================
                // LOCATION
                // =================================================

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 5

                    Text {
                        text: "Location"

                        color: "#666666"

                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        Layout.fillWidth: true

                        Layout.preferredHeight: 40

                        radius: 10

                        color: "#111111"

                        border.width: 1
                        border.color: "#292929"

                        Text {
                            id: locationText

                            anchors.left: parent.left
                            anchors.right: copyButton.left

                            anchors.leftMargin: 12

                            anchors.rightMargin: 6

                            anchors.verticalCenter: parent.verticalCenter

                            text: root.filePath || "—"

                            color: "#9d9d9d"

                            font.pixelSize: 11

                            elide: Text.ElideMiddle

                            wrapMode: Text.NoWrap
                        }

                        XylaIconButton {
                            id: copyButton

                            anchors.right: parent.right
                            anchors.rightMargin: 5

                            anchors.verticalCenter: parent.verticalCenter

                            width: 32
                            height: 32

                            ghost: true

                            iconSource: "qrc:/assets/icons/copy.svg"

                            ToolTip.visible: hovered
                            ToolTip.text: "Copy location"

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

    component MetadataPill: Rectangle {
        id: metadataPill

        property string iconSource: ""
        property string label: ""
        property string value: ""

        Layout.preferredHeight: 54

        radius: 11

        color: "#1d1d1d"

        border.width: 0

        ColumnLayout {
            anchors.fill: parent

            anchors.leftMargin: 10
            anchors.rightMargin: 10

            anchors.topMargin: 8
            anchors.bottomMargin: 8

            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                spacing: 5

                Image {
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12

                    source: metadataPill.iconSource

                    opacity: 0.45
                }

                Text {
                    Layout.fillWidth: true

                    text: metadataPill.label

                    color: "#5f5f5f"

                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                }
            }

            Text {
                Layout.fillWidth: true

                text: metadataPill.value

                color: "#c8c8c8"

                font.pixelSize: 11
                font.weight: Font.Medium

                elide: Text.ElideMiddle
            }
        }
    }
}
