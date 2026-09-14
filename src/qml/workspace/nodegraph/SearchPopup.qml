import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: searchPopup
    parent: Overlay.overlay
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 12 // (Line 13) Increased from 8 to 12 to clear the 12px corner radius clipping
    width: 240
    transformOrigin: Item.TopLeft

    // =====================================================================
    // State Input Properties (Dependencies from parent)
    // =====================================================================
    property var availableNodeTypes: []
    property bool isReadOnly: false

    // =====================================================================
    // Pure Action Signals (No internal business logic or root calls)
    // =====================================================================
    signal addNodeRequested(string typeName, real spawnX, real spawnY)
    signal addRerouteRequested(real spawnX, real spawnY)
    signal addCommentRequested(real spawnX, real spawnY)
    signal createGroupRequested(real spawnX, real spawnY)

    background: Rectangle {
        color: "#181818"
        border.color: "#303030"
        border.width: 1
        radius: 12
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#90000000"
            shadowBlur: 0.65
            shadowVerticalOffset: 6
        }
    }

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

    contentItem: ColumnLayout {
        id: searchPopupLayout
        width: parent.width
        spacing: 4

        // Subtle "Add Node" Title at the Top
        Text {
            Layout.leftMargin: 4  // (Line 63) Adjusted from 8 since popup padding handles the outer edge
            Layout.topMargin: 0   // (Line 64) Removed extra top margin to align with new padding
            Layout.bottomMargin: 2 // (Line 65)
            text: "Add Node"
            color: "#71717A"
            font.pixelSize: 11
        }

        // ContextSeparator {}

        // Dynamic Node List Filtered by Search Input
        ListView {
            id: availableNodeListView
            Layout.fillWidth: true
            implicitHeight: count > 0 ? Math.min(contentHeight, 260) : 0
            visible: count > 0
            clip: true
            spacing: 2

            model: {
                var q = searchField.text.trim().toLowerCase();
                if (q === "")
                    return searchPopup.availableNodeTypes;
                return searchPopup.availableNodeTypes.filter(function (item) {
                    return item.displayName.toLowerCase().indexOf(q) !== -1 || 
                           item.category.toLowerCase().indexOf(q) !== -1 || 
                           item.typeName.toLowerCase().indexOf(q) !== -1;
                });
            }

            delegate: ContextMenuRow {
                width: availableNodeListView.width
                iconSource: modelData.iconSource
                text: modelData.displayName

                // In SearchPopup.qml
                property real spawnX: 0
                property real spawnY: 0

                // In your delegate row onClicked:
                onClicked: {
                    var tName = modelData.typeName;
                    var posX = searchPopup.spawnX;
                    var posY = searchPopup.spawnY;

                    searchPopup.close();

                    if (searchPopup.isReadOnly)
                        return;

                    if (tName === "Reroute") {
                        searchPopup.addRerouteRequested(posX, posY);
                    } else if (tName === "CommentNode") {
                        searchPopup.addCommentRequested(posX, posY);
                    } else if (tName === "GroupNode") {
                        searchPopup.createGroupRequested(posX, posY);
                    } else {
                        searchPopup.addNodeRequested(tName, posX, posY);
                    }
                }
            }
        }

        // Empty State Message when no nodes match the filter
// Empty State Message when no nodes match the filter
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 40
            visible: availableNodeListView.count === 0
            text: "No matching nodes found"
            color: "#71717A"
            font.pixelSize: 11
            verticalAlignment: Text.AlignVCenter
            clip: true
        }

        ContextSeparator {}

        // Filter Text Input at the Bottom
        Rectangle {
            Layout.fillWidth: true
            height: 30
            radius: 6
            color: "#121212"
            border.color: searchField.activeFocus ? "#2555D3" : "#333333"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Image {
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12
                    source: "qrc:/assets/icons/search.svg"
                    opacity: 0.6
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                }
            }
        }
    }

    property real requestedX: 0
    property real requestedY: 0
    property real spawnX: 0
    property real spawnY: 0
    property string linkFromNodeId: ""
    property string linkFromSocketId: ""

    function reposition() {
        if (!Overlay.overlay)
            return;
        x = Math.max(8, Math.min(requestedX, Overlay.overlay.width - width - 8));
        y = Math.max(8, Math.min(requestedY, Overlay.overlay.height - height - 8));
    }

    onAboutToShow: {
        reposition()

        if (searchField) {
            searchField.text = "";
            searchField.forceActiveFocus();
        }
    }

    onImplicitWidthChanged: if (visible) reposition()
    onImplicitHeightChanged: if (visible) reposition()

    function openAt(sx, sy, lx, ly) {
        requestedX = sx;
        requestedY = sy;
        spawnX = lx !== undefined ? lx : sx;
        spawnY = ly !== undefined ? ly : sy;
        searchField.text = "";
        reposition();
        open();
        searchField.forceActiveFocus();
    }
}



// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts
// 
// Popup {
//     id: popup
//     width: 230
//     height: 250
//     padding: 6
//     modal: false
//     focus: true
//     closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
// 
//     property real spawnX: 0
//     property real spawnY: 0
//     property string linkFromNodeId: ""
//     property string linkFromSocketId: ""
// 
//     signal nodeSelected(string typeName, real x, real y, string fromNode, string fromSocket)
// 
//     background: Rectangle {
//         color: "#181818"
//         border.color: "#2d2d2d"
//         border.width: 1
//         radius: 6
//     }
// 
//     onOpened: {
//         searchInput.text = "";
//         searchInput.forceActiveFocus();
//         nodeListView.currentIndex = 0;
//     }
// 
//     ColumnLayout {
//         anchors.fill: parent
//         spacing: 6
// 
//         // Search Input Bar
//         Rectangle {
//             Layout.fillWidth: true
//             height: 28
//             color: "#121212"
//             border.color: searchInput.activeFocus ? "#3B82F6" : "#2d2d2d"
//             border.width: 1
//             radius: 4
// 
//             RowLayout {
//                 anchors.fill: parent
//                 anchors.leftMargin: 8
//                 anchors.rightMargin: 8
//                 spacing: 6
// 
//                 Image {
//                     source: "qrc:/assets/icons/search.svg"
//                     sourceSize.width: 12
//                     sourceSize.height: 12
//                     opacity: 0.5
//                 }
// 
//                 TextInput {
//                     id: searchInput
//                     Layout.fillWidth: true
//                     verticalAlignment: TextInput.AlignVCenter
//                     color: "#ffffff"
//                     font.pixelSize: 11
//                     selectByMouse: true
// 
//                     Keys.onDownPressed: {
//                         if (nodeListView.currentIndex < filteredModel.count - 1) {
//                             nodeListView.currentIndex++;
//                         }
//                     }
//                     Keys.onUpPressed: {
//                         if (nodeListView.currentIndex > 0) {
//                             nodeListView.currentIndex--;
//                         }
//                     }
//                     Keys.onReturnPressed: {
//                         if (nodeListView.currentItem) {
//                             nodeListView.currentItem.trigger();
//                         }
//                     }
//                 }
//             }
//         }
// 
//         ListModel {
//             id: allNodesModel
//             ListElement {
//                 name: "Color Grade"
//                 typeName: "ColorGrade"
//                 category: "Color"
//                 iconSource: "qrc:/assets/icons/palette.svg"
//             }
//             ListElement {
//                 name: "Transform"
//                 typeName: "Transform"
//                 category: "Spatial"
//                 iconSource: "qrc:/assets/icons/crop-landscape.svg"
//             }
//             ListElement {
//                 name: "Video Out"
//                 typeName: "VideoOut"
//                 category: "Output"
//                 iconSource: "qrc:/assets/icons/layout-grid.svg"
//             }
//             ListElement {
//                 name: "Video In"
//                 typeName: "VideoIn"
//                 category: "Source"
//                 iconSource: "qrc:/assets/icons/video.svg"
//             }
//         }
// 
//         ListModel {
//             id: filteredModel
//         }
// 
//         function filterNodes() {
//             filteredModel.clear();
//             var query = searchInput.text.toLowerCase().trim();
//             for (var i = 0; i < allNodesModel.count; ++i) {
//                 var item = allNodesModel.get(i);
//                 if (query === "" || item.name.toLowerCase().indexOf(query) !== -1 || item.category.toLowerCase().indexOf(query) !== -1) {
//                     filteredModel.append(item);
//                 }
//             }
//         }
// 
//         Component.onCompleted: filterNodes()
// 
//         Connections {
//             target: searchInput
//             function onTextChanged() {
//                 popup.filterNodes();
//                 nodeListView.currentIndex = 0;
//             }
//         }
// 
//         ListView {
//             id: nodeListView
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//             clip: true
//             model: filteredModel
// 
//             delegate: Rectangle {
//                 id: rowDelegate
//                 width: nodeListView.width
//                 height: 30
//                 color: (nodeListView.currentIndex === index || rowMouse.containsMouse) ? "#252526" : "transparent"
//                 border.color: (nodeListView.currentIndex === index || rowMouse.containsMouse) ? "#2d2d2d" : "transparent"
//                 border.width: 1
//                 radius: 4
// 
//                 function trigger() {
//                     popup.nodeSelected(model.typeName, popup.spawnX, popup.spawnY, popup.linkFromNodeId, popup.linkFromSocketId);
//                     popup.close();
//                 }
// 
//                 RowLayout {
//                     anchors.fill: parent
//                     anchors.leftMargin: 8
//                     anchors.rightMargin: 8
//                     spacing: 8
// 
//                     Image {
//                         source: model.iconSource
//                         sourceSize.width: 14
//                         sourceSize.height: 14
//                         visible: source != ""
//                     }
// 
//                     Text {
//                         text: model.name
//                         color: (nodeListView.currentIndex === index || rowMouse.containsMouse) ? "#ffffff" : "#cccccc"
//                         font.pixelSize: 11
//                         font.weight: Font.Medium
//                         Layout.fillWidth: true
//                     }
// 
//                     Text {
//                         text: model.category
//                         color: "#666666"
//                         font.pixelSize: 10
//                     }
//                 }
// 
//                 MouseArea {
//                     id: rowMouse
//                     anchors.fill: parent
//                     hoverEnabled: true
//                     onClicked: rowDelegate.trigger()
//                 }
//             }
//         }
//     }
// }
