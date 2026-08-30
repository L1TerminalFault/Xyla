import QtQuick

Item {
    id: emptyState
    anchors.fill: parent
    visible: viewContainer.currentCount === 0 && !fileSystemModel.loading
    z: 50

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: Math.min(280, parent.width - 48)

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72
            height: 72
            radius: 18
            color: "#1c1c1c"
            border.color: "#2a2a2a"
            border.width: 1

            Image {
                anchors.centerIn: parent
                source: fileSystemModel.nameFilter !== "" ? "qrc:/assets/icons/search.svg" : "qrc:/assets/icons/folder.svg"
                sourceSize: Qt.size(32, 32)
                opacity: 0.4
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: fileSystemModel.nameFilter !== "" ? "No results" : "This folder is empty"
            color: "#888888"
            font.pixelSize: 15
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: fileSystemModel.nameFilter !== "" ? "Nothing matches “" + fileSystemModel.nameFilter + "”" : "Drop files here or create a new folder"
            color: "#555555"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            lineHeight: 1.35
        }

        // Optional quick action when empty (not searching)
        XylaTextButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: fileSystemModel.nameFilter === ""
            text: "New Folder"
            // Layout.topMargin: 8
            onClicked: newFolderDialog.open()
        }
    }
}
