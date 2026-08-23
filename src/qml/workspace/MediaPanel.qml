import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Xyla 1.0
import "../components"

Item {
    id: root

    // Fall back gracefully to the C++ rootContext property
    property var activeMediaPool: typeof mediaPool !== "undefined" ? mediaPool : null
    property var activeMediaBinModel: typeof mediaBinModel !== "undefined" ? mediaBinModel : null

    // Helper function to convert QML file:// URLs to valid OS file paths
    function urlToLocalPath(urlVal) {
        if (!urlVal)
            return "";
        var str = urlVal.toString().trim();

        // Reject code comments starting with '//'
        if (str.startsWith("//"))
            return "";

        if (str.startsWith("file://")) {
            var path = str.replace(/^file:\/\//, "");
            path = decodeURIComponent(path);
            // On Windows, file:///C:/path becomes /C:/path, strip leading slash
            if (/^\/[a-zA-Z]:/.test(path)) {
                path = path.substring(1);
            }
            return path;
        }

        // Single '/' absolute Unix path (e.g. /home/user/video.mp4)
        if (str.startsWith("/") && !str.startsWith("//")) {
            return decodeURIComponent(str);
        }

        // Windows drive path (e.g. C:\path or C:/path)
        if (/^[a-zA-Z]:[/\\]/.test(str)) {
            return decodeURIComponent(str);
        }

        return "";
    }

    // Custom Folder Dialog replacing native FolderDialog
    XylaFolderDialog {
        id: folderDialog
        onFolderSelected: function (path) {
            if (!root.activeMediaPool)
                return;

            if (path && path.length > 0) {
                root.activeMediaPool.importFilesAsync([path], "root");
            }
        }
    }

    // Panel Background
    Rectangle {
        anchors.fill: parent
        color: "#191919"
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Header / Search Bar area
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                color: "#252526"
                radius: 4
                border.color: "#333333"
                border.width: 1

                TextInput {

                    // FIX PART 1: Prevent internal text-drag mechanics from hijacking window focus
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    color: "#CCCCCC"
                    font.pixelSize: 12
                    selectByMouse: true

                    // FIX PART 2: Block drop events specifically over the input element
                    DropArea {
                        anchors.fill: parent
                        onEntered: drag => drag.accepted = false
                    }

                    Text {
                        text: "Search media..."
                        color: "#666666"
                        font.pixelSize: 12
                        visible: parent.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Button {
                implicitWidth: 80
                implicitHeight: 32
                text: "Import"

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 12
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.down ? "#005fb8" : (parent.hovered ? "#0078d4" : "#0066b8")
                    radius: 4
                }

                onClicked: {
                    folderDialog.open();
                }
            }
        }

        // Drop Area Container
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            DropArea {
                id: dropArea
                anchors.fill: parent

                onEntered: function (drag) {
                    drag.acceptProposedAction();
                }
                keys: ["text/uri-list"]
                onPositionChanged: function (drag) {
                    drag.acceptProposedAction();
                }

                onDropped: function (drop) {
                    drop.acceptProposedAction();

                    console.log("[MediaPanel DEBUG] Drop event triggered. hasUrls:", drop.hasUrls, "count:", drop.urls ? drop.urls.length : 0);

                    if (!drop.hasUrls || drop.urls.length === 0 || !root.activeMediaPool) {
                        console.log("[MediaPanel DEBUG] Drop ignored: No URLs present or activeMediaPool is null.");
                        return;
                    }

                    var pathsToImport = [];
                    for (var i = 0; i < drop.urls.length; i++) {
                        var rawUrl = drop.urls[i];
                        var rawStr = rawUrl ? rawUrl.toString() : "";
                        var localPath = root.urlToLocalPath(rawUrl);

                        console.log("[MediaPanel DEBUG] Item [" + i + "]: raw='" + rawStr + "' -> localPath='" + localPath + "'");

                        if (localPath && localPath.length > 0) {
                            pathsToImport.push(localPath);
                        }
                    }

                    if (pathsToImport.length > 0) {
                        console.log("[MediaPanel] Dispatching files to MediaPool:", JSON.stringify(pathsToImport));
                        root.activeMediaPool.importFilesAsync(pathsToImport, "root");
                    } else {
                        console.log("[MediaPanel] Drop ignored: No valid media file paths found in payload.");
                    }
                }

                // Drop Overlay Highlight
                Rectangle {
                    anchors.fill: parent
                    color: dropArea.containsDrag ? "#200078d4" : "transparent"
                    border.color: dropArea.containsDrag ? "#0078d4" : "transparent"
                    border.width: 2
                    radius: 4
                    z: 10
                }

                // Media Grid View
                GridView {
                    id: gridView
                    anchors.fill: parent
                    clip: true

                    cellWidth: 120
                    cellHeight: 100

                    model: root.activeMediaBinModel

                    delegate: Item {
                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "#2d2d2d"
                                radius: 4
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: model.path ? "image://thumbnails/" + model.path + "?width=120" : ""
                                    asynchronous: true
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                    width: durationText.implicitWidth + 6
                                    height: durationText.implicitHeight + 2
                                    color: "#cc000000"
                                    radius: 2
                                    visible: model.duration !== undefined && model.duration !== ""

                                    Text {
                                        id: durationText
                                        anchors.centerIn: parent
                                        text: model.duration || ""
                                        color: "#ffffff"
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: model.name || ""
                                color: "#cccccc"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No Media Assets Loaded\n(Drag & Drop files here)"
                        horizontalAlignment: Text.AlignHCenter
                        color: "#555555"
                        font.pixelSize: 13
                        visible: gridView.count === 0
                    }
                }
            }
        }
    }
}
