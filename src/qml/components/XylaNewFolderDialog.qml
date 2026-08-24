import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: dialogRoot

    property string folderName
    property string errorMessage

    signal rejected
    signal createRequested(string name)

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
        folderNameInput.text = "";
        dialogRoot.errorMessage = "";

        dialogRoot.show();
        dialogRoot.requestActivate();

        folderNameInput.forceActiveFocus();
    }

    function close() {
        dialogRoot.hide();
    }

    function createFolder() {
        var name = folderNameInput.text.trim();

        dialogRoot.errorMessage = "";

        if (name === "") {
            dialogRoot.errorMessage = "Please enter a folder name.";
            folderNameInput.forceActiveFocus();
            return;
        }

        createRequested(name);
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

            // =====================================================
            // TITLE BAR
            // =====================================================

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

                    source: "qrc:/assets/icons/folder-plus.svg"

                    sourceSize.width: 18
                    sourceSize.height: 18
                }

                Text {
                    anchors.left: titleIcon.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    text: "New Folder"

                    color: "#ffffff"

                    font.pixelSize: 14
                    font.bold: true
                }

                XylaIconButton {
                    id: closeBtn

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

            // =====================================================
            // CONTENT
            // =====================================================

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Layout.margins: 16

                spacing: 8

                Text {
                    text: "Folder Name"

                    color: "#ffffff"

                    font.pixelSize: 12
                    font.bold: true
                }

                TextField {
                    id: folderNameInput

                    Layout.fillWidth: true
                    Layout.preferredHeight: 36

                    placeholderText: "New Folder"

                    color: "#ffffff"
                    placeholderTextColor: "#555555"

                    font.pixelSize: 13

                    leftPadding: 10
                    rightPadding: 10

                    selectByMouse: true

                    background: Rectangle {
                        color: folderNameInput.activeFocus ? "#191919" : "#181818"

                        border.color: dialogRoot.errorMessage !== "" ? "#ff5c5c" : folderNameInput.activeFocus ? "#2555D3" : "#2d2d2d"

                        border.width: 1
                        radius: 6
                    }

                    // Clear the error as soon as the user starts correcting the name.
                    onTextChanged: {
                        if (dialogRoot.errorMessage !== "")
                            dialogRoot.errorMessage = "";
                    }

                    // Pressing Enter is equivalent to clicking Create.
                    onAccepted: {
                        dialogRoot.createFolder();
                    }
                }

                // Error message
                Text {
                    id: errorLabel

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

                        text: "Create"

                        primary: true

                        enabled: folderNameInput.text.trim() !== ""

                        onClicked: {
                            dialogRoot.createFolder();
                        }
                    }
                }
            }
        }
    }
}
