import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: dialogRoot

    property string targetPath: ""
    property string originalName: ""
    property string errorMessage: ""

    signal renameRequested(string newName)
    signal rejected

    width: 420
    height: 190
    minimumWidth: 420
    maximumWidth: 420
    minimumHeight: 190
    maximumHeight: 190

    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    color: "transparent"

    function open() {
        nameInput.text = originalName;
        errorMessage = "";
        show();
        requestActivate();
        nameInput.forceActiveFocus();
        nameInput.selectAll();
    }

    function close() {
        hide();
    }

    function doRename() {
        var name = nameInput.text.trim();
        errorMessage = "";
        if (name === "") {
            errorMessage = "Please enter a name.";
            nameInput.forceActiveFocus();
            return;
        }
        renameRequested(name);
    }

    Rectangle {
        anchors.fill: parent
        color: "#121212"
        border.color: "#2d2d2d"
        border.width: 1
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Title bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: "#181818"
                topLeftRadius: 8
                topRightRadius: 8

                Image {
                    id: titleIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    source: "qrc:/assets/icons/edit.svg"
                    sourceSize: Qt.size(18, 18)
                }

                Text {
                    anchors.left: titleIcon.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Rename"
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
                    onClicked: {
                        dialogRoot.rejected();
                        dialogRoot.close();
                    }
                }
            }

            // Content
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 8

                Text {
                    text: "New Name"
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.bold: true
                }

                TextField {
                    id: nameInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: "#ffffff"
                    font.pixelSize: 13
                    leftPadding: 10
                    rightPadding: 10
                    selectByMouse: true

                    background: Rectangle {
                        color: nameInput.activeFocus ? "#191919" : "#181818"
                        border.color: dialogRoot.errorMessage !== "" ? "#ff5c5c" : nameInput.activeFocus ? "#2555D3" : "#2d2d2d"
                        border.width: 1
                        radius: 6
                    }

                    onTextChanged: if (dialogRoot.errorMessage !== "")
                        dialogRoot.errorMessage = ""
                    onAccepted: dialogRoot.doRename()
                }

                Text {
                    Layout.fillWidth: true
                    visible: dialogRoot.errorMessage !== ""
                    text: dialogRoot.errorMessage
                    color: "#ff5c5c"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item {
                        Layout.fillWidth: true
                    }

                    XylaTextButton {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 34
                        text: "Cancel"
                        onClicked: {
                            dialogRoot.rejected();
                            dialogRoot.close();
                        }
                    }

                    XylaTextButton {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 34
                        text: "Rename"
                        primary: true
                        enabled: nameInput.text.trim() !== ""
                        onClicked: dialogRoot.doRename()
                    }
                }
            }
        }
    }
}
