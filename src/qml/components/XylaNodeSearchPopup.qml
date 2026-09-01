import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: popup
    width: 230
    height: 250
    padding: 6
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property real spawnX: 0
    property real spawnY: 0
    property string linkFromNodeId: ""
    property string linkFromSocketId: ""

    signal nodeSelected(string typeName, real x, real y, string fromNode, string fromSocket)

    background: Rectangle {
        color: "#181818"
        border.color: "#2d2d2d"
        border.width: 1
        radius: 6
    }

    onOpened: {
        searchInput.text = "";
        searchInput.forceActiveFocus();
        nodeListView.currentIndex = 0;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Search Input Bar
        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: "#121212"
            border.color: searchInput.activeFocus ? "#3B82F6" : "#2d2d2d"
            border.width: 1
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Image {
                    source: "qrc:/assets/icons/search.svg"
                    sourceSize.width: 12
                    sourceSize.height: 12
                    opacity: 0.5
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#ffffff"
                    font.pixelSize: 11
                    selectByMouse: true

                    Keys.onDownPressed: {
                        if (nodeListView.currentIndex < filteredModel.count - 1) {
                            nodeListView.currentIndex++;
                        }
                    }
                    Keys.onUpPressed: {
                        if (nodeListView.currentIndex > 0) {
                            nodeListView.currentIndex--;
                        }
                    }
                    Keys.onReturnPressed: {
                        if (nodeListView.currentItem) {
                            nodeListView.currentItem.trigger();
                        }
                    }
                }
            }
        }

        ListModel {
            id: allNodesModel
            ListElement {
                name: "Color Grade"
                typeName: "ColorGrade"
                category: "Color"
                iconSource: "qrc:/assets/icons/palette.svg"
            }
            ListElement {
                name: "Transform"
                typeName: "Transform"
                category: "Spatial"
                iconSource: "qrc:/assets/icons/crop-landscape.svg"
            }
            ListElement {
                name: "Video Out"
                typeName: "VideoOut"
                category: "Output"
                iconSource: "qrc:/assets/icons/layout-grid.svg"
            }
            ListElement {
                name: "Video In"
                typeName: "VideoIn"
                category: "Source"
                iconSource: "qrc:/assets/icons/video.svg"
            }
        }

        ListModel {
            id: filteredModel
        }

        function filterNodes() {
            filteredModel.clear();
            var query = searchInput.text.toLowerCase().trim();
            for (var i = 0; i < allNodesModel.count; ++i) {
                var item = allNodesModel.get(i);
                if (query === "" || item.name.toLowerCase().indexOf(query) !== -1 || item.category.toLowerCase().indexOf(query) !== -1) {
                    filteredModel.append(item);
                }
            }
        }

        Component.onCompleted: filterNodes()

        Connections {
            target: searchInput
            function onTextChanged() {
                popup.filterNodes();
                nodeListView.currentIndex = 0;
            }
        }

        ListView {
            id: nodeListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: filteredModel

            delegate: Rectangle {
                id: rowDelegate
                width: nodeListView.width
                height: 30
                color: (nodeListView.currentIndex === index || rowMouse.containsMouse) ? "#252526" : "transparent"
                border.color: (nodeListView.currentIndex === index || rowMouse.containsMouse) ? "#2d2d2d" : "transparent"
                border.width: 1
                radius: 4

                function trigger() {
                    popup.nodeSelected(model.typeName, popup.spawnX, popup.spawnY, popup.linkFromNodeId, popup.linkFromSocketId);
                    popup.close();
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Image {
                        source: model.iconSource
                        sourceSize.width: 14
                        sourceSize.height: 14
                        visible: source != ""
                    }

                    Text {
                        text: model.name
                        color: (nodeListView.currentIndex === index || rowMouse.containsMouse) ? "#ffffff" : "#cccccc"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }

                    Text {
                        text: model.category
                        color: "#666666"
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: rowDelegate.trigger()
                }
            }
        }
    }
}
