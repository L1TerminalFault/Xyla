import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

Popup {
    id: dialogRoot

    parent: Overlay.overlay

    modal: true
    focus: true

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    padding: 0

    width: 480
    height: 220

    signal saveRequested
    signal discardRequested
    signal cancelRequested

    readonly property color bgDark: "#121212"
    readonly property color bgCard: "#1e1e1e"
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#aaaaaa"
    readonly property color accentColor: "#2555D3"

    function centerPopup() {
        x = Math.round((Overlay.overlay.width - width) / 2);
        y = Math.round((Overlay.overlay.height - height) / 2);
    }

    // ============================================================
    // Popup Background
    // ============================================================

    background: Rectangle {
        id: popupSurface

        anchors.fill: parent

        color: "#181818"

        radius: 12

        layer.enabled: true

        layer.effect: MultiEffect {
            shadowEnabled: true

            shadowColor: "#90000000"

            shadowBlur: 0.65

            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
        }
    }

    // ============================================================
    // Open Animation
    // ============================================================

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"

                from: 0.0
                to: 1.0

                duration: 150

                easing.type:
                    Easing.OutCubic
            }

            NumberAnimation {
                property: "scale"

                from: 0.95
                to: 1.0

                duration: 180

                easing.type:
                    Easing.OutCubic
            }
        }
    }

    // ============================================================
    // Close Animation
    // ============================================================

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"

                from: 1.0
                to: 0.0

                duration: 120

                easing.type:
                    Easing.OutCubic
            }

            NumberAnimation {
                property: "scale"

                from: 1.0
                to: 0.95

                duration: 120

                easing.type:
                    Easing.OutCubic
            }
        }
    }

    // ============================================================
    // Content
    // ============================================================

    contentItem: ColumnLayout {
        id: popupLayout

        anchors.fill: parent

        anchors.margins: 24

        spacing: 16

        // ========================================================
        // Warning / Message
        // ========================================================

        RowLayout {
            Layout.fillWidth: true

            spacing: 16

            // Warning icon
Image {
    Layout.preferredWidth: 40
    Layout.preferredHeight: 40

    source: "qrc:/assets/icons/warning.svg"

    sourceSize: Qt.size(40, 40)

    fillMode: Image.PreserveAspectFit
}
            // Rectangle {
            //     Layout.preferredWidth: 40
            //     Layout.preferredHeight: 40
            //
            //     radius: 20
            //
            //     color: "#2a2215"
            //
            //     Text {
            //         anchors.centerIn: parent
            //
            //         text: "!"
            //
            //         color: "#f59e0b"
            //
            //         font.pixelSize: 20
            //         font.bold: true
            //     }
            // }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: 4

                Text {
                    Layout.fillWidth: true

                    text:
                        "Save changes to project?"

                    color:
                        dialogRoot.textPrimary

                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true

                    text:
                        "The active project has unsaved modifications. If you close without saving, your changes will be lost."

                    color:
                        dialogRoot.textSecondary

                    font.pixelSize: 13

                    wrapMode:
                        Text.WordWrap
                }
            }
        }

        // ========================================================
        // Flexible Space
        // ========================================================

        Item {
            Layout.fillHeight: true
        }

        // ========================================================
        // Buttons
        // ========================================================

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

    // ============================================================
    // Center Popup In Overlay
    // ============================================================

    onOpened: {
        x = Math.round(
            (parent.width - width) / 2
        );

        y = Math.round(
            (parent.height - height) / 2
        );
    }
}
