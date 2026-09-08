import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "qrc:/kddockwidgets/qtquick/views/qml/" as KDDW

KDDW.TabBarBase {
    id: root

    implicitHeight: 36
    currentTabIndex: 0

    readonly property Item parentGroup: {
        var p = parent
        while (p) {
            if (p.hasOwnProperty("hasTopSibling")) return p
            p = p.parent
        }
        return null
    }

    readonly property bool hasTopSibling: parentGroup ? parentGroup.hasTopSibling : false
    readonly property bool hasLeftSibling: parentGroup ? parentGroup.hasLeftSibling : false
    readonly property bool hasRightSibling: parentGroup ? parentGroup.hasRightSibling : false
    // readonly property bool isFloating: parentGroup ? parentGroup.isFloating : false
    readonly property bool isFloating: Boolean(parentGroup && parentGroup.isFloating)

    function getTabAtIndex(index) {
        return tabBarRow.children[index];
    }

    function getTabIndexAtPosition(globalPoint) {
        for (var i = 0; i < tabBarRow.children.length; ++i) {
            var tab = tabBarRow.children[i];
            var localPt = tab.mapFromGlobal(globalPoint.x, globalPoint.y);
            if (tab.contains(localPt)) {
                return i;
            }
        }
        return -1;
    }

    function getActiveDockWidget() {
        if (!root.groupCpp) return null;

        // Method 1: direct property or getter function
        if (typeof root.groupCpp.currentDockWidget === "function") {
            return root.groupCpp.currentDockWidget();
        }
        if (root.groupCpp.currentDockWidget) {
            return root.groupCpp.currentDockWidget;
        }

        // Method 2: index lookup in dockWidgets list / model
        var idx = root.groupCpp.currentIndex !== undefined ? root.groupCpp.currentIndex : 0;
        if (typeof root.groupCpp.dockWidgetAt === "function") {
            return root.groupCpp.dockWidgetAt(idx);
        }
        if (root.groupCpp.dockWidgets && root.groupCpp.dockWidgets.length > idx) {
            return root.groupCpp.dockWidgets[idx];
        }

        return null;
    }

    function floatCurrentTab() {
        if (!root.groupCpp) return;
        var idx = root.groupCpp.currentIndex !== undefined ? root.groupCpp.currentIndex : 0;

        // 1. Try GroupView's native float method if present
        if (typeof root.groupCpp.floatDockWidget === "function") {
            root.groupCpp.floatDockWidget(idx);
            return;
        }

        // 2. Try on the active DockWidget itself
        var dw = getActiveDockWidget();
        if (dw) {
            if (typeof dw.setFloating === "function") {
                dw.setFloating(true);
            } else if (typeof dw.isFloating !== "undefined") {
                dw.isFloating = true;
            } else if (typeof dw.float === "function") {
                dw.float();
            }
            return;
        }

        // 3. Fallback to TitleBar / TabBar built-in signal
        if (typeof root.floatButtonClicked === "function") {
            root.floatButtonClicked();
        }
    }

    function closeCurrentTab() {
        if (!root.groupCpp) return;
        var idx = root.groupCpp.currentIndex !== undefined ? root.groupCpp.currentIndex : 0;

        // 1. Try GroupView's native close method if present
        if (typeof root.groupCpp.closeDockWidget === "function") {
            root.groupCpp.closeDockWidget(idx);
            return;
        }

        // 2. Try on the active DockWidget itself
        var dw = getActiveDockWidget();
        if (dw) {
            if (typeof dw.close === "function") {
                dw.close();
            } else if (typeof dw.toggleOverlay === "function") {
                dw.close();
            }
            return;
        }

        // 3. Fallback to TitleBar / TabBar built-in signal
        if (typeof root.closeButtonClicked === "function") {
            root.closeButtonClicked();
        }
    }

    // -------------------------------------------------------------------------
    // BACKGROUND (Cleanly placed at z: 0)
    // -------------------------------------------------------------------------
    Rectangle {
        id: tabBarBackground
        anchors.fill: parent
        color: "#191919"
        z: 0

        readonly property int cornerRadius: 10

        topLeftRadius: ( /* root.isFloating || */ (!root.hasTopSibling && !root.hasLeftSibling)) ? cornerRadius : 0
        topRightRadius: ( /* root.isFloating || */ (!root.hasTopSibling && !root.hasRightSibling)) ? cornerRadius : 0
        bottomLeftRadius: 0
        bottomRightRadius: 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#191919"
        }
    }

    // -------------------------------------------------------------------------
    // TABS ROW (z: 1 sits above background)
    // -------------------------------------------------------------------------
    Row {
        id: tabBarRow
        z: 1
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: actionButtonsRow.left
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        spacing: 4

        property int hoveredIndex: -1

        Repeater {
            model: root.groupCpp ? root.groupCpp.tabBar.dockWidgetModel : 0

            Rectangle {
                id: tab
                height: parent.height
                implicitWidth: Math.max(110, tabText.implicitWidth + 20)

                readonly property bool isCurrent: index == root.groupCpp.currentIndex
                readonly property int tabIndex: index

                color: isCurrent ? "#252526" : (tabBarRow.hoveredIndex == index ? "#181818" : "#0d0d0d")
                radius: 8

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Text {
                    id: tabText
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: title
                    color: isCurrent ? "#ffffff" : "#888888"
                    font.pixelSize: 12
                    font.weight: isCurrent ? Font.Medium : Font.Normal
                    elide: Text.ElideRight

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }
        }

        Connections {
            target: root.tabBarCpp

            function onHoveredTabIndexChanged(index) {
                tabBarRow.hoveredIndex = index;
            }
        }
    }

    // -------------------------------------------------------------------------
    // FLOAT & CLOSE BUTTONS (z: 99 sits on top of all KDDW mouse areas!)
    // -------------------------------------------------------------------------
    Row {
        id: actionButtonsRow
        z: 99
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        // Float / Maximize Button
        Rectangle {
            id: floatBtn
            width: 22
            height: 22
            radius: 6
            color: floatArea.containsMouse ? "#2d2d2d" : "#191919"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Image {
                id: floatIcon
                anchors.centerIn: parent
                width: 10
                height: 10
                source: "qrc:/assets/icons/maximize.svg"
                fillMode: Image.PreserveAspectFit

                property color iconColor: floatArea.containsMouse ? "#ffffff" : "#888888"

                Behavior on iconColor {
                    ColorAnimation { duration: 150 }
                }

                layer.enabled: true
                layer.effect: ColorOverlay {
                    color: floatIcon.iconColor
                }
            }

            MouseArea {
                id: floatArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
onClicked: mouse => {
    mouse.accepted = true

    // Prefer floating the current dock widget via C++ controller API
    if (root.groupCpp && root.groupCpp.currentDockWidget) {
        var dw = root.groupCpp.currentDockWidget
        // currentDockWidget may be a function in some bindings
        if (typeof dw === "function")
            dw = root.groupCpp.currentDockWidget()

        if (dw && typeof dw.setFloating === "function") {
            dw.setFloating(true)
            return
        }
    }

    // Fallback: layoutController with the Group controller if you keep that API
    if (typeof layoutController !== "undefined" && layoutController)
        layoutController.floatCurrentTab(root.groupCpp)
}
            }
        }

        // Close Button
        Rectangle {
            id: closeBtn
            width: 22
            height: 22
            radius: 6
            color: closeArea.containsMouse ? "#2d2d2d" : "#191919"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Image {
                id: closeIcon
                anchors.centerIn: parent
                width: 10
                height: 10
                source: "qrc:/assets/icons/x.svg"
                fillMode: Image.PreserveAspectFit

                property color iconColor: closeArea.containsMouse ? "#e81123" : "#df8888"

                Behavior on iconColor {
                    ColorAnimation { duration: 150 }
                }

                layer.enabled: true
                layer.effect: ColorOverlay {
                    color: closeIcon.iconColor
                }
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    mouse.accepted = true;
                    if (typeof layoutController !== "undefined" && layoutController) {
                        layoutController.closeCurrentTab(root.groupCpp);
                    }
                }
            }
        }
    }
}
