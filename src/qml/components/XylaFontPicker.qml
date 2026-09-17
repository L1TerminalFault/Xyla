import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Item {
    id: root

    property string currentFont: "Inter"
    signal fontSelected(string family)

    implicitHeight: 26
    implicitWidth: 180

    // Master list of system fonts
    readonly property var allSystemFonts: {
        var fonts = Qt.fontFamilies();
        fonts.sort(function (a, b) {
            return a.localeCompare(b);
        });
        return fonts;
    }

    property string searchFilter: ""
    property var filteredFonts: allSystemFonts

    function applyFilter(query) {
        searchFilter = query;
        if (!query || query.trim() === "") {
            filteredFonts = allSystemFonts;
            return;
        }
        var lower = query.toLowerCase().trim();
        filteredFonts = allSystemFonts.filter(function (f) {
            return f.toLowerCase().indexOf(lower) !== -1;
        });
    }

    // Custom Font File Loader for TTF / OTF
    FontLoader {
        id: customFontLoader
        onStatusChanged: {
            if (status === FontLoader.Ready) {
                var loadedFamily = customFontLoader.name;
                root.currentFont = loadedFamily;
                root.fontSelected(loadedFamily);
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 4

        // =====================================================================
        // FILTERABLE COMBOBOX
        // =====================================================================
        Rectangle {
            id: comboField
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 4
            color: "#101010"
            border.color: fontPopup.visible || searchInput.activeFocus ? "#3b82f6" : "#242424"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: 4

                // Searchable Input Box
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.currentFont
                    color: "#ffffff"
                    font.pixelSize: 11
                    selectByMouse: true
                    clip: true

                    onTextEdited: {
                        if (!fontPopup.visible) {
                            fontPopup.open();
                        }
                        root.applyFilter(text);
                    }

                    onAccepted: {
                        if (root.filteredFonts.length > 0) {
                            root.currentFont = root.filteredFonts[0];
                            root.fontSelected(root.currentFont);
                        }
                        fontPopup.close();
                        searchInput.focus = false;
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            selectAll();
                            root.applyFilter("");
                            fontPopup.open();
                        } else if (!fontPopup.visible) {
                            text = root.currentFont;
                        }
                    }
                }

                // Dropdown Chevron Indicator
                Image {
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12
                    source: "qrc:/assets/icons/chevron-down.svg"
                    sourceSize: Qt.size(12, 12)
                    opacity: 0.7

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (fontPopup.visible) {
                                fontPopup.close();
                            } else {
                                root.applyFilter("");
                                searchInput.text = root.currentFont;
                                fontPopup.open();
                            }
                        }
                    }
                }
            }

            // =================================================================
            // POPUP FONT LIST
            // =================================================================
            Popup {
                id: fontPopup
                y: comboField.height + 4
                width: Math.max(comboField.width, 220)
                height: Math.min(260, (fontListView.contentHeight + 12))
                padding: 4
                modal: false
                focus: false
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                background: Rectangle {
                    color: "#181818"
                    radius: 6
                    border.color: "#28282e"
                    border.width: 1
                }

                contentItem: ListView {
                    id: fontListView
                    clip: true
                    model: root.filteredFonts
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        width: 6
                        policy: fontListView.contentHeight > fontPopup.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        width: fontListView.width - (fontListView.contentHeight > fontPopup.height ? 8 : 0)
                        height: 28
                        radius: 4
                        color: itemMouse.containsMouse ? "#262626" : (modelData === root.currentFont ? "#1f1f24" : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            // Font rendered in its actual typography
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: modelData === root.currentFont ? "#3b82f6" : "#ffffff"
                                font.pixelSize: 12
                                font.family: modelData
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Checkmark for currently selected font
                            Image {
                                visible: modelData === root.currentFont
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                                source: "qrc:/assets/icons/check.svg"
                                sourceSize: Qt.size(12, 12)
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentFont = modelData;
                                searchInput.text = modelData;
                                root.fontSelected(modelData);
                                fontPopup.close();
                                searchInput.focus = false;
                            }
                        }
                    }
                }

                onClosed: {
                    searchInput.text = root.currentFont;
                }
            }
        }

        // =====================================================================
        // FILE OPENER BUTTON
        // =====================================================================
        Rectangle {
            id: browseBtn
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: 4
            color: browseMouse.containsMouse ? "#262626" : "#141414"
            border.color: "#28282e"
            border.width: 1

            Image {
                anchors.centerIn: parent
                width: 14
                height: 14
                source: "qrc:/assets/icons/folder.svg"
                sourceSize: Qt.size(14, 14)
                opacity: browseMouse.containsMouse ? 1.0 : 0.75
            }

            MouseArea {
                id: browseMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    fontFileDialog.returnType = "file";
                    fontFileDialog.nameFilter = "ttf";
                    fontFileDialog.selectMultiple = false;
                    fontFileDialog.open();
                }
            }
        }
    }

    // Correct component name from /src/qml/components/
    XylaFolderDialog {
        id: fontFileDialog

        onFolderSelected: function (paths) {
            var path = "";
            if (Array.isArray(paths) && paths.length > 0) {
                path = paths[0];
            } else if (typeof paths === "string") {
                path = paths;
            }

            if (path && path.length > 0) {
                var fileUrl = path.indexOf("://") === -1 ? ("file://" + path) : path;
                customFontLoader.source = fileUrl;

                if (typeof timelineModel !== "undefined" && timelineModel && timelineModel.registerCustomFont) {
                    timelineModel.registerCustomFont(path);
                }
            }
            fontFileDialog.hideDialog();
        }
    }
}
