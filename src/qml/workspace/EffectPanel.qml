import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../editors"

Item {
    id: root

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property string activeClipId: (activeTimelineModel && activeTimelineModel.selectedClipId !== undefined) ? activeTimelineModel.selectedClipId : ""
    property var activeClipData: (activeTimelineModel && activeTimelineModel.selectedClipData !== undefined) ? activeTimelineModel.selectedClipData : null

    property var editorNodes: (activeClipData && activeClipData.editorNodes) ? activeClipData.editorNodes : []
    property string currentSelectedNodeId: ""
    property var currentNodeData: null

    function updateActiveNode() {
        if (!editorNodes || editorNodes.length === 0) {
            currentSelectedNodeId = "";
            currentNodeData = null;
            return;
        }

        for (var i = 0; i < editorNodes.length; ++i) {
            if (editorNodes[i].id === currentSelectedNodeId) {
                currentNodeData = editorNodes[i];
                return;
            }
        }

        currentSelectedNodeId = editorNodes[0].id;
        currentNodeData = editorNodes[0];
    }

    onEditorNodesChanged: updateActiveNode()
    onActiveClipIdChanged: {
        currentSelectedNodeId = "";
        updateActiveNode();
    }

    function focusNode(nodeId) {
        currentSelectedNodeId = nodeId;
        updateActiveNode();
    }

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header Navigation Toolbar
        Rectangle {
            Layout.fillWidth: true
            height: 38
            color: "#181818"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#2d2d2d"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                // Node Switcher Dropdown using XylaSelect
                XylaSelect {
                    id: nodeDropdown
                    Layout.preferredWidth: 150
                    implicitHeight: 22
                    visible: root.editorNodes && root.editorNodes.length > 0
                    model: {
                        var names = [];
                        for (var i = 0; i < root.editorNodes.length; ++i) {
                            names.push(root.editorNodes[i].name);
                        }
                        return names;
                    }

                    onActivated: function (index) {
                        if (index >= 0 && index < root.editorNodes.length) {
                            root.currentSelectedNodeId = root.editorNodes[index].id;
                            root.updateActiveNode();
                        }
                    }
                }

                Text {
                    visible: !root.editorNodes || root.editorNodes.length === 0
                    text: root.activeClipData ? "No Complex Effects" : "No Clip Selected"
                    color: "#666666"
                    font.pixelSize: 11
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                // Active Clip Indicator Pill
                Rectangle {
                    visible: root.activeClipData !== null
                    Layout.preferredHeight: 20
                    Layout.preferredWidth: Math.min(180, clipPillText.implicitWidth + 16)
                    color: "#121212"
                    border.color: "#2d2d2d"
                    border.width: 1
                    radius: 3

                    Text {
                        id: clipPillText
                        anchors.centerIn: parent
                        text: root.activeClipData ? root.activeClipData.name : ""
                        color: "#888888"
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // Dynamic Complex Effect View Mount Area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: effectLoader
                anchors.fill: parent
                source: (root.currentNodeData && root.currentNodeData.qmlUrl) ? root.currentNodeData.qmlUrl : ""

                onLoaded: {
                    if (item) {
                        item.nodeId = root.currentSelectedNodeId;
                        item.clipId = root.activeClipId;
                        item.activeTimelineModel = root.activeTimelineModel;
                    }
                }
            }

            // Fallback Empty State
            Item {
                anchors.centerIn: parent
                visible: effectLoader.source == ""

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        source: "qrc:/assets/icons/palette.svg"
                        sourceSize.width: 32
                        sourceSize.height: 32
                        opacity: 0.3
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.activeClipData ? "Select a clip with a Color Grade or Effect node" : "Select a clip on the timeline"
                        color: "#555555"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
