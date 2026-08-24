import QtQuick
// import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root

    property string fileName: ""
    property string filePath: ""
    property bool isDir: false
    property real fileSize: 0
    property int itemCount: 0
    property string extension: ""
    property var lastModified: null

    width: 420
    height: 380
    minimumWidth: 420
    maximumWidth: 480
    minimumHeight: 360

    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    color: "transparent"

    function openWith(item) {
        fileName = item.fileName || "";
        filePath = item.filePath || "";
        isDir = item.isDir || false;
        fileSize = item.fileSize || 0;
        itemCount = item.itemCount || 0;
        extension = item.extension || "";
        lastModified = item.lastModified || null;
        show();
        requestActivate();
    }

    function close() {
        hide();
    }

    function humanSize(bytes) {
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
            return "—";
        return Qt.formatDateTime(dt, "yyyy-MM-dd  HH:mm");
    }

    Rectangle {
        anchors.fill: parent
        color: "#121212"
        border.color: "#2d2d2d"
        border.width: 1
        radius: 10

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------- Title bar ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: "#181818"
                topLeftRadius: 10
                topRightRadius: 10

                Image {
                    id: titleIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    source: root.isDir ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/file.svg"
                    sourceSize: Qt.size(18, 18)
                }

                Text {
                    anchors.left: titleIcon.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Properties"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }

                XylaIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    ghost: true
                    iconSource: "qrc:/assets/icons/x.svg"
                    onClicked: root.close()
                }
            }

            // ---------- Content ----------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 20
                spacing: 14

                // Name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "Name"
                        color: "#888888"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.fileName
                        color: "#ffffff"
                        font.pixelSize: 14
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#2d2d2d"
                }

                // Type
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Type"
                        color: "#888888"
                        font.pixelSize: 12
                        Layout.preferredWidth: 110
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.isDir ? "Folder" : (root.extension !== "" ? root.extension.toUpperCase() + " File" : "File")
                        color: "#e0e0e0"
                        font.pixelSize: 13
                    }
                }

                // Size
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Size"
                        color: "#888888"
                        font.pixelSize: 12
                        Layout.preferredWidth: 110
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.isDir ? (root.itemCount + " item" + (root.itemCount === 1 ? "" : "s")) : root.humanSize(root.fileSize)
                        color: "#e0e0e0"
                        font.pixelSize: 13
                    }
                }

                // Location
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Location"
                        color: "#888888"
                        font.pixelSize: 12
                        Layout.preferredWidth: 110
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.filePath
                        color: "#e0e0e0"
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                        wrapMode: Text.NoWrap
                    }
                }

                // Modified
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Modified"
                        color: "#888888"
                        font.pixelSize: 12
                        Layout.preferredWidth: 110
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.formatDate(root.lastModified)
                        color: "#e0e0e0"
                        font.pixelSize: 13
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                // Close button
                RowLayout {
                    Layout.fillWidth: true
                    Item {
                        Layout.fillWidth: true
                    }
                    XylaTextButton {
                        text: "Close"
                        primary: true
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 34
                        onClicked: root.close()
                    }
                }
            }
        }
    }
}
