import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Window {
    id: dialogRoot
    width: 480
    height: 220
    minimumWidth: 480
    maximumWidth: 480
    minimumHeight: 220
    maximumHeight: 220
    flags: Qt.Dialog | Qt.MSWindowsFixedSizeDialogHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
    title: "Unsaved Changes"
    color: bgDark

    signal saveRequested
    signal discardRequested
    signal cancelRequested

    readonly property color bgDark: "#121212"
    readonly property color bgCard: "#1e1e1e"
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#aaaaaa"
    readonly property color accentColor: "#2555D3"
    readonly property color borderDark: "#2d2d2d"

    Rectangle {
        anchors.fill: parent
        color: dialogRoot.bgDark
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: "#2a2215"
                border.color: "#855410"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: "#f59e0b"
                    font.pixelSize: 20
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Save changes to project?"
                    color: dialogRoot.textPrimary
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: "The active project has unsaved modifications. If you close without saving, your changes will be lost."
                    color: dialogRoot.textSecondary
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                Layout.fillWidth: true
            }

            XylaTextButton {
                text: "Cancel"
                onClicked: {
                    dialogRoot.cancelRequested();
                    dialogRoot.close();
                }
            }

            XylaTextButton {
                text: "Don't Save"
                onClicked: {
                    dialogRoot.discardRequested();
                    dialogRoot.close();
                }
            }

            XylaTextButton {
                text: "Save"
                primary: true
                onClicked: {
                    dialogRoot.saveRequested();
                    dialogRoot.close();
                }
            }
        }
    }
}
