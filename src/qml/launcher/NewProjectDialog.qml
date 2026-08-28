import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import "../components"

Window {
    id: dialogRoot

    title: "Create New Project"
    width: 600
    height: contentLayout.implicitHeight

    minimumWidth: 400
    maximumWidth: 900
    minimumHeight: 520
    maximumHeight: 900

    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    color: "transparent"

    function open() {
        dialogRoot.show();
        dialogRoot.requestActivate();
    }

    function close() {
        dialogRoot.hide();
    }

    Rectangle {
        id: mainBackground
        anchors.fill: parent
        color: "#121212"
        border.color: "#2d2d2d"
        border.width: 1
        radius: 8

        focus: true

        TapHandler {
            onTapped: mainBackground.forceActiveFocus()
        }

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            spacing: 0

            // Header (Draggable Handle)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: "#181818"
                topLeftRadius: 8
                topRightRadius: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    text: "Create New Project"
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#2d2d2d"
                }

                DragHandler {
                    id: windowDrag
                    target: null
                    onActiveChanged: {
                        if (active) {
                            dialogRoot.startSystemMove();
                        }
                    }
                }
            }

            // Body Form Inputs
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 20
                spacing: 16

                // Project Name Field
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Project Name"
                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    TextField {
                        id: projectNameInput
                        Layout.fillWidth: true
                        placeholderText: "MyProject1"
                        placeholderTextColor: "#555555"
                        color: "#ffffff"
                        font.pixelSize: 13
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 10
                        bottomPadding: 10
                        selectByMouse: true

                        background: Rectangle {
                            color: projectNameInput.activeFocus ? "#1f1f1f" : "#181818"
                            border.color: projectNameInput.activeFocus ? "#2555D3" : "#2d2d2d"
                            border.width: 1
                            radius: 6
                        }
                    }
                }

                // Folder Location Selector
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Location"
                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: pathInput
                            Layout.fillWidth: true
                            placeholderText: "/path/to/project"
                            placeholderTextColor: "#555555"
                            color: "#ffffff"
                            font.pixelSize: 13
                            leftPadding: 12
                            rightPadding: 12
                            topPadding: 10
                            bottomPadding: 10
                            selectByMouse: true

                            background: Rectangle {
                                color: pathInput.activeFocus ? "#1f1f1f" : "#181818"
                                border.color: pathInput.activeFocus ? "#2555D3" : "#2d2d2d"
                                border.width: 1
                                radius: 6
                            }
                        }

                        XylaTextButton {
                            id: browseBtn
                            text: "Browse"
                            leftPadding: 14
                            rightPadding: 14
                            onClicked: customFolderDialog.open()
                        }
                    }
                }

                // Profile Preset Section
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Text {
                        text: "Profile Preset"
                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: searchInput
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 32
                            placeholderText: "Search profiles..."
                            placeholderTextColor: "#555555"
                            color: "#ffffff"
                            font.pixelSize: 12
                            leftPadding: 10
                            rightPadding: 10
                            selectByMouse: true

                            background: Rectangle {
                                color: searchInput.activeFocus ? "#1f1f1f" : "#181818"
                                border.color: searchInput.activeFocus ? "#2555D3" : "#2d2d2d"
                                border.width: 1
                                radius: 6
                            }

                            onTextChanged: triggerProfileFilter()
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Filter Button & Embedded Popup
                        XylaIconButton {
                            id: filterBtn
                            iconSource: "qrc:/assets/icons/filter.svg"
                            primary: filterPopup.opened

                            onClicked: {
                                if (filterPopup._recentlyClosed) {
                                    filterPopup._recentlyClosed = false;
                                    return;
                                }

                                if (filterPopup.opened) {
                                    filterPopup.close();
                                } else {
                                    filterPopup.open();
                                }
                            }

                            Popup {
                                id: filterPopup
                                parent: filterBtn
                                y: parent.height + 6
                                x: parent.width - width
                                width: 240
                                padding: 12
                                clip: false

                                property bool _recentlyClosed: false

                                onAboutToHide: {
                                    _recentlyClosed = true;
                                    closeResetTimer.restart();
                                }

                                Timer {
                                    id: closeResetTimer
                                    interval: 200
                                    onTriggered: filterPopup._recentlyClosed = false
                                }

                                background: Rectangle {
                                    color: "#181818"
                                    border.color: "#2d2d2d"
                                    border.width: 1
                                    radius: 8
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
                                    spacing: 10

                                    Text {
                                        text: "Filter Profiles"
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    // Resolution Filter
                                    ColumnLayout {
                                        spacing: 4
                                        Text {
                                            text: "Resolution"
                                            color: "#888888"
                                            font.pixelSize: 11
                                        }
                                        XylaSelect {
                                            id: resolutionFilter
                                            Layout.fillWidth: true
                                            model: ["All Resolutions", "1080p", "4K", "720p", "Custom"]
                                            onCurrentTextChanged: triggerProfileFilter()
                                        }
                                    }

                                    // FPS Filter
                                    ColumnLayout {
                                        spacing: 4
                                        Text {
                                            text: "Framerate"
                                            color: "#888888"
                                            font.pixelSize: 11
                                        }
                                        XylaSelect {
                                            id: fpsFilter
                                            Layout.fillWidth: true
                                            model: ["All FPS", "60 fps", "30 fps", "24 fps", "50 fps"]
                                            onCurrentTextChanged: triggerProfileFilter()
                                        }
                                    }

                                    // Scan Mode Filter
                                    ColumnLayout {
                                        spacing: 4
                                        Text {
                                            text: "Scan Mode"
                                            color: "#888888"
                                            font.pixelSize: 11
                                        }
                                        XylaSelect {
                                            id: scanFilter
                                            Layout.fillWidth: true
                                            model: ["All Scans", "Progressive", "Interlaced"]
                                            onCurrentTextChanged: triggerProfileFilter()
                                        }
                                    }

                                    // Orientation Segmented Control
                                    ColumnLayout {
                                        spacing: 4
                                        Text {
                                            text: "Orientation"
                                            color: "#888888"
                                            font.pixelSize: 11
                                        }
                                        XylaSegmentedToggle {
                                            id: orientationToggle
                                            currentIndex: 0
                                            options: [
                                                {
                                                    icon: "qrc:/assets/icons/layout-grid.svg",
                                                    value: "all"
                                                },
                                                {
                                                    icon: "qrc:/assets/icons/crop-landscape.svg",
                                                    value: "landscape"
                                                },
                                                {
                                                    icon: "qrc:/assets/icons/crop-portrait.svg",
                                                    value: "portrait"
                                                }
                                            ]
                                            onOptionSelected: (index, value) => {
                                                triggerProfileFilter();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ProfileSelector {
                        id: profileSelector
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 180
                    }
                }

                // Tracks Section (Below Profile Presets)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Video Tracks Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Video Tracks:"
                            color: "#ffffff"
                            font.pixelSize: 13
                            Layout.preferredWidth: 95
                            Layout.alignment: Qt.AlignVCenter
                        }

                        XylaNumberInput {
                            id: videoTracksInput
                            value: 2
                            minValue: 1
                            maxValue: 16
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    // Audio Tracks Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Audio Tracks:"
                            color: "#ffffff"
                            font.pixelSize: 13
                            Layout.preferredWidth: 95
                            Layout.alignment: Qt.AlignVCenter
                        }

                        XylaNumberInput {
                            id: audioTracksInput
                            value: 2
                            minValue: 1
                            maxValue: 16
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Action Buttons Footer
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.bottomMargin: 20
                spacing: 10

                Item {
                    Layout.fillWidth: true
                }

                XylaTextButton {
                    id: cancelBtn
                    text: "Cancel"
                    onClicked: dialogRoot.hide()
                }

                XylaTextButton {
                    id: createBtn
                    text: "Create"
                    primary: true
                    onClicked: {
                        var name = projectNameInput.text.trim();
                        var path = pathInput.text.trim();
                        if (name !== "" && path !== "") {
                            // Passed 5 C++ expected arguments
                            projectManager.createProject(name, path, profileSelector.selectedWidth, profileSelector.selectedHeight, profileSelector.selectedFpsNum / profileSelector.selectedFpsDen);
                            dialogRoot.hide();
                        }
                    }
                }
            }
        }
    }

    // Custom Integrated Folder Selector Dialog
    XylaFolderDialog {
        id: customFolderDialog
        returnType: "folder"
        onFolderSelected: selectedPath => {
            pathInput.text = selectedPath;
        }
    }

    function triggerProfileFilter() {
        if (profileSelector.filterModel) {
            var orient = orientationToggle.currentValue;
            profileSelector.filterModel({
                search: searchInput.text,
                resolution: resolutionFilter.currentText,
                fps: fpsFilter.currentText,
                scan: scanFilter.currentText,
                allowLandscape: (orient === "all" || orient === "landscape"),
                allowPortrait: (orient === "all" || orient === "portrait")
            });
        }
    }
}
