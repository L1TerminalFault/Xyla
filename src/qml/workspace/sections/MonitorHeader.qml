import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"

Rectangle {
    id: headerRoot

    property bool actionSafeEnabled: false
    property bool titleSafeEnabled: false
    property real actionSafePercent: 90.0
    property real titleSafePercent: 80.0

    property bool gridEnabled: false
    property int gridRows: 3
    property int gridColumns: 3
    property real gridOpacity: 0.35
    property color gridColor: "#ffffff"

    property bool rulersEnabled: false
    property bool guidesEnabled: true
    property bool guidesLocked: false
    property var horizontalGuides: []
    property var verticalGuides: []
    signal clearGuidesRequested

    property bool timecodeOverlayEnabled: false
    property string timecodeOverlayPosition: "bottom-right"

    property string currentZoomText: "Fit"
    property bool isCustomZoom: false
    property real customZoomPercent: 100.0

    signal zoomPresetSelected(real scaleRatio, string label)
    signal resetZoomRequested

    height: 30
    color: "#141416"

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#202024"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 4

        // --- LEFT: Zoom Controls ---
        XylaSelect {
            id: zoomSelect
            implicitHeight: 24
            implicitWidth: 120
            borderColor: "#28282c"
            backgroundColor: "#18181a"

            model: ["Fit", "25%", "50%", "100%", "150%", "200%"]

            displayText: headerRoot.isCustomZoom ? "Custom (" + Math.round(headerRoot.customZoomPercent) + "%)" : (currentIndex >= 0 ? model[currentIndex] : "Fit")

            onActivated: function (index) {
                var selected = model[index];
                if (selected === "Fit")
                    headerRoot.zoomPresetSelected(0.0, "Fit");
                else if (selected === "25%")
                    headerRoot.zoomPresetSelected(0.25, "25%");
                else if (selected === "50%")
                    headerRoot.zoomPresetSelected(0.50, "50%");
                else if (selected === "100%")
                    headerRoot.zoomPresetSelected(1.00, "100%");
                else if (selected === "150%")
                    headerRoot.zoomPresetSelected(1.50, "150%");
                else if (selected === "200%")
                    headerRoot.zoomPresetSelected(2.00, "200%");
            }

            Connections {
                target: headerRoot
                function onCurrentZoomTextChanged() {
                    if (!headerRoot.isCustomZoom) {
                        var idx = zoomSelect.model.indexOf(headerRoot.currentZoomText);
                        if (idx !== -1)
                            zoomSelect.currentIndex = idx;
                    }
                }
            }
        }

        XylaIconButton {
            implicitWidth: 26
            implicitHeight: 26
            iconWidth: 13
            iconHeight: 13
            ghost: true
            iconSource: "qrc:/assets/icons/arrows-maximize.svg"
            tooltip: "Reset Zoom to Fit (Shift+Z)"
            onClicked: {
                zoomSelect.currentIndex = 0;
                headerRoot.resetZoomRequested();
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // --- RIGHT: Timecode HUD, Grid, Safe Margins, Guides ---
        XylaIconButton {
            id: timecodeHudBtn
            implicitWidth: 26
            implicitHeight: 26
            iconWidth: 14
            iconHeight: 14
            ghost: !headerRoot.timecodeOverlayEnabled
            primary: headerRoot.timecodeOverlayEnabled
            iconSource: "qrc:/assets/icons/clock.svg"
            tooltip: "Timecode Overlay"
            onClicked: timecodePopup.opened ? timecodePopup.close() : timecodePopup.open()

            MonitorTimecodePopup {
                id: timecodePopup
                x: timecodeHudBtn.width - width
                y: timecodeHudBtn.height + 4

                timecodeEnabled: headerRoot.timecodeOverlayEnabled
                timecodePosition: headerRoot.timecodeOverlayPosition

                onTimecodeToggled: function (val) {
                    headerRoot.timecodeOverlayEnabled = val;
                }
                onPositionChanged: function (pos) {
                    headerRoot.timecodeOverlayPosition = pos;
                }
            }
        }

        XylaIconButton {
            id: gridBtn
            implicitWidth: 26
            implicitHeight: 26
            iconWidth: 14
            iconHeight: 14
            ghost: !headerRoot.gridEnabled
            primary: headerRoot.gridEnabled
            iconSource: "qrc:/assets/icons/layout-grid.svg"
            tooltip: "Alignment Grid"
            onClicked: gridPopup.opened ? gridPopup.close() : gridPopup.open()

            MonitorGridPopup {
                id: gridPopup
                x: gridBtn.width - width
                y: gridBtn.height + 4

                gridEnabled: headerRoot.gridEnabled
                gridRows: headerRoot.gridRows
                gridColumns: headerRoot.gridColumns
                gridOpacity: headerRoot.gridOpacity
                gridColor: headerRoot.gridColor

                onGridToggled: function (val) {
                    headerRoot.gridEnabled = val;
                }
                onRowsModified: function (val) {
                    headerRoot.gridRows = val;
                }
                onColumnsModified: function (val) {
                    headerRoot.gridColumns = val;
                }
                onOpacityModified: function (val) {
                    headerRoot.gridOpacity = val;
                }
                onColorSelected: function (val) {
                    headerRoot.gridColor = val;
                }
            }
        }

        XylaIconButton {
            id: safeMarginsBtn
            implicitWidth: 26
            implicitHeight: 26
            iconWidth: 14
            iconHeight: 14
            ghost: !(headerRoot.actionSafeEnabled || headerRoot.titleSafeEnabled)
            primary: headerRoot.actionSafeEnabled || headerRoot.titleSafeEnabled
            iconSource: "qrc:/assets/icons/border-outer.svg"
            tooltip: "Safe Margins Overlay"
            onClicked: safeMarginsPopup.opened ? safeMarginsPopup.close() : safeMarginsPopup.open()

            MonitorSafeMarginsPopup {
                id: safeMarginsPopup
                x: safeMarginsBtn.width - width
                y: safeMarginsBtn.height + 4

                actionSafeEnabled: headerRoot.actionSafeEnabled
                titleSafeEnabled: headerRoot.titleSafeEnabled
                actionSafePercent: headerRoot.actionSafePercent
                titleSafePercent: headerRoot.titleSafePercent

                onActionSafeToggled: function (val) {
                    headerRoot.actionSafeEnabled = val;
                }
                onTitleSafeToggled: function (val) {
                    headerRoot.titleSafeEnabled = val;
                }
                onActionPercentChanged: function (val) {
                    headerRoot.actionSafePercent = val;
                }
                onTitlePercentChanged: function (val) {
                    headerRoot.titleSafePercent = val;
                }
            }
        }

        XylaIconButton {
            id: guidesBtn
            implicitWidth: 26
            implicitHeight: 26
            iconWidth: 14
            iconHeight: 14
            ghost: !Boolean(headerRoot.rulersEnabled || headerRoot.guidesEnabled)
            primary: Boolean(headerRoot.rulersEnabled || headerRoot.guidesEnabled)
            iconSource: "qrc:/assets/icons/ruler.svg"
            tooltip: "Rulers & Guides"
            onClicked: guidesPopup.opened ? guidesPopup.close() : guidesPopup.open()

            MonitorGuidesPopup {
                id: guidesPopup
                x: guidesBtn.width - width
                y: guidesBtn.height + 4

                rulersEnabled: Boolean(headerRoot.rulersEnabled)
                guidesEnabled: Boolean(headerRoot.guidesEnabled)
                guidesLocked: Boolean(headerRoot.guidesLocked)
                guideCount: (headerRoot.horizontalGuides ? headerRoot.horizontalGuides.length : 0) + (headerRoot.verticalGuides ? headerRoot.verticalGuides.length : 0)

                onRulersToggled: function (val) {
                    headerRoot.rulersEnabled = val;
                }
                onGuidesToggled: function (val) {
                    headerRoot.guidesEnabled = val;
                }
                onGuidesLockedToggled: function (val) {
                    headerRoot.guidesLocked = val;
                }
                onClearAllGuidesRequested: {
                    headerRoot.clearGuidesRequested();
                }
            }
        }
    }
}
