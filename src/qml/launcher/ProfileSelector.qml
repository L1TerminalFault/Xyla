import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

RowLayout {
    id: selectorRoot
    spacing: 12

    property int selectedWidth: 1920
    property int selectedHeight: 1080
    property int selectedFpsNum: 30
    property int selectedFpsDen: 1
    property string selectedColorspace: "ITU-R BT.709"
    property string selectedProfileName: ""

    Rectangle {
        Layout.fillHeight: true
        Layout.fillWidth: true
        color: "#181818"
        border.color: "#2d2d2d"
        radius: 6

        TreeView {
            id: treeView
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: (typeof profileManager !== "undefined" && profileManager) ? profileManager.model : null

            delegate: ItemDelegate {
                id: delegateRoot
                implicitWidth: treeView.width
                implicitHeight: 28

                required property int depth
                required property bool hasChildren

                required property bool isCategory
                required property string profileName

                onClicked: {
                    if (isCategory) {
                        treeView.toggleExpanded(row);
                    } else {
                        selectorRoot.selectedProfileName = delegateRoot.profileName;
                        selectorRoot.selectedWidth = model.width;
                        selectorRoot.selectedHeight = model.height;
                        selectorRoot.selectedFpsNum = model.frameRateNum;
                        selectorRoot.selectedFpsDen = model.frameRateDen;
                        selectorRoot.selectedColorspace = model.colorspace;
                    }
                }

                contentItem: RowLayout {
                    spacing: 6

                    Item {
                        implicitWidth: delegateRoot.depth * 10
                    }

                    Item {
                        implicitWidth: 12
                        implicitHeight: 12
                        Image {
                            id: chevron
                            width: 10
                            height: 10
                            source: delegateRoot.hasChildren ? (treeView.isExpanded(row) ? "qrc:/assets/icons/chevron-down.svg" : "qrc:/assets/icons/chevron-right.svg") : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: false
                        }
                        MultiEffect {
                            source: chevron
                            anchors.fill: chevron
                            colorization: 1.0
                            colorizationColor: "#888888"
                        }
                    }

                    Text {
                        text: delegateRoot.profileName
                        color: delegateRoot.isCategory ? "#888888" : "#ffffff"
                        font.pixelSize: 12
                        font.bold: delegateRoot.isCategory
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                background: Rectangle {
                    color: delegateRoot.hovered ? "#222222" : "transparent"
                    radius: 4
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: "#181818"
        border.color: "#2d2d2d"
        radius: 6

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Text {
                text: selectorRoot.selectedProfileName !== "" ? selectorRoot.selectedProfileName : "Select Profile Preset"
                color: "#ffffff"
                font.pixelSize: 13
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#2d2d2d"
            }

            GridLayout {
                columns: 2
                rowSpacing: 8
                columnSpacing: 10
                Layout.fillWidth: true

                Text {
                    text: "Size:"
                    color: "#888888"
                    font.pixelSize: 12
                }
                Text {
                    text: selectorRoot.selectedWidth + " x " + selectorRoot.selectedHeight
                    color: "#ffffff"
                    font.pixelSize: 12
                }

                Text {
                    text: "Frame rate:"
                    color: "#888888"
                    font.pixelSize: 12
                }
                Text {
                    text: (selectorRoot.selectedFpsDen > 0 ? (selectorRoot.selectedFpsNum / selectorRoot.selectedFpsDen).toFixed(2) : "0") + " fps"
                    color: "#ffffff"
                    font.pixelSize: 12
                }

                Text {
                    text: "Colorspace:"
                    color: "#888888"
                    font.pixelSize: 12
                }
                Text {
                    text: selectorRoot.selectedColorspace
                    color: "#ffffff"
                    font.pixelSize: 12
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
