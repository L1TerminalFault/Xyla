import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "qrc:/kddockwidgets/qtquick/views/qml/" as KDDW

KDDW.TabBarBase {
    id: root

    implicitHeight: 36
    currentTabIndex: 0

    readonly property Item parentGroup: {
        var p = parent;
        while (p) {
            if (p.hasOwnProperty("hasTopSibling"))
                return p;
            p = p.parent;
        }
        return null;
    }

    readonly property bool hasTopSibling: parentGroup ? parentGroup.hasTopSibling : false
    readonly property bool hasLeftSibling: parentGroup ? parentGroup.hasLeftSibling : false
    readonly property bool hasRightSibling: parentGroup ? parentGroup.hasRightSibling : false

    readonly property bool isFloating: {
        if (root.groupCpp) {
            if (typeof root.groupCpp.isFloating === "function")
                return Boolean(root.groupCpp.isFloating());
            if (typeof root.groupCpp.isFloating !== "undefined")
                return Boolean(root.groupCpp.isFloating);
        }
        var dw = getTargetDockWidget();
        if (dw) {
            if (typeof dw.isFloating === "function")
                return Boolean(dw.isFloating());
            if (typeof dw.isFloating !== "undefined")
                return Boolean(dw.isFloating);
        }
        if (root.Window && root.Window.window && root.Window.window !== root.parentGroup?.Window?.window) {
            if (typeof root.Window.window.isFloating !== "undefined")
                return Boolean(root.Window.window.isFloating);
            if (root.Window.window.toString().indexOf("FloatingWindow") !== -1)
                return true;
        }
        if (parentGroup) {
            if (typeof parentGroup.isFloating === "function")
                return Boolean(parentGroup.isFloating());
            if (typeof parentGroup.isFloating !== "undefined")
                return Boolean(parentGroup.isFloating);
        }
        return false;
    }

    function getTabAtIndex(index) {
        return tabBarRow.children[index];
    }

    function getTabIndexAtPosition(globalPoint) {
        var localPt = tabBarRow.mapFromGlobal(globalPoint.x, globalPoint.y);
        for (var i = 0; i < tabBarRow.children.length; ++i) {
            var tab = tabBarRow.children[i];
            if (tab && tab.visible && localPt.x >= tab.x && localPt.x <= (tab.x + tab.width)) {
                return i;
            }
        }
        return -1;
    }

    property int targetTabIndex: -1

    function getTargetDockWidget() {
        if (!root.groupCpp)
            return null;

        var idx = root.targetTabIndex >= 0 ? root.targetTabIndex : (root.groupCpp.currentIndex !== undefined ? root.groupCpp.currentIndex : 0);

        if (typeof root.groupCpp.dockWidgetAt === "function") {
            return root.groupCpp.dockWidgetAt(idx);
        }
        if (root.groupCpp.dockWidgets && root.groupCpp.dockWidgets.length > idx) {
            return root.groupCpp.dockWidgets[idx];
        }
        if (typeof root.groupCpp.currentDockWidget === "function") {
            return root.groupCpp.currentDockWidget();
        }
        if (root.groupCpp.currentDockWidget) {
            return root.groupCpp.currentDockWidget;
        }

        return null;
    }

    function isTargetTabFloating() {
        var dw = getTargetDockWidget();
        if (dw) {
            if (typeof dw.isFloating === "function")
                return Boolean(dw.isFloating());
            if (typeof dw.isFloating !== "undefined")
                return Boolean(dw.isFloating);
        }
        return root.isFloating;
    }

    function floatTargetTab() {
        if (!root.groupCpp)
            return;

        var idx = root.targetTabIndex >= 0 ? root.targetTabIndex : (root.groupCpp.currentIndex !== undefined ? root.groupCpp.currentIndex : 0);
        var dw = getTargetDockWidget();

        if (dw && typeof root.groupCpp.setCurrentDockWidget === "function") {
            root.groupCpp.setCurrentDockWidget(dw);
        } else if (typeof root.groupCpp.setCurrentIndex === "function") {
            root.groupCpp.setCurrentIndex(idx);
        } else if (typeof root.groupCpp.activateTab === "function") {
            root.groupCpp.activateTab(idx);
        }

        if (dw) {
            var currFloat = false;
            if (typeof dw.isFloating === "function")
                currFloat = Boolean(dw.isFloating());
            else if (typeof dw.isFloating !== "undefined")
                currFloat = Boolean(dw.isFloating);

            if (typeof dw.setFloating === "function") {
                dw.setFloating(!currFloat);
                return;
            } else if (typeof dw.isFloating !== "undefined") {
                dw.isFloating = !currFloat;
                return;
            } else if (typeof dw.float === "function") {
                dw.float();
                return;
            }
        }

        if (dw && typeof root.groupCpp.floatDockWidget === "function") {
            root.groupCpp.floatDockWidget(dw);
            return;
        } else if (typeof root.groupCpp.floatDockWidget === "function") {
            root.groupCpp.floatDockWidget(idx);
            return;
        }

        if (typeof layoutController !== "undefined" && layoutController) {
            if (typeof layoutController.floatDockWidgetAtIndex === "function") {
                layoutController.floatDockWidgetAtIndex(root.groupCpp, idx);
                return;
            } else if (typeof layoutController.floatCurrentTab === "function") {
                layoutController.floatCurrentTab(root.groupCpp);
                return;
            }
        }

        if (typeof root.floatButtonClicked === "function") {
            root.floatButtonClicked();
        }
    }

    function closeTargetTab() {
        if (!root.groupCpp)
            return;

        var idx = root.targetTabIndex >= 0 ? root.targetTabIndex : (root.groupCpp.currentIndex !== undefined ? root.groupCpp.currentIndex : 0);

        var dw = getTargetDockWidget();
        if (dw && typeof dw.close === "function") {
            dw.close();
            return;
        }

        if (typeof root.groupCpp.closeDockWidget === "function") {
            root.groupCpp.closeDockWidget(idx);
            return;
        }

        if (typeof layoutController !== "undefined" && layoutController) {
            if (typeof layoutController.closeDockWidgetAtIndex === "function") {
                layoutController.closeDockWidgetAtIndex(root.groupCpp, idx);
                return;
            } else if (typeof layoutController.closeCurrentTab === "function") {
                layoutController.closeCurrentTab(root.groupCpp);
                return;
            }
        }

        if (typeof root.closeButtonClicked === "function") {
            root.closeButtonClicked();
        }
    }

    // Automatically sync active dock ID whenever current tab changes
    Connections {
        target: root.groupCpp
        function onCurrentIndexChanged() {
            if (typeof layoutController !== "undefined" && layoutController && root.groupCpp) {
                var dw = root.getTargetDockWidget();
                if (dw && dw.uniqueName) {
                    layoutController.setActiveDockId(dw.uniqueName);
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // BACKGROUND (z: 0)
    // -------------------------------------------------------------------------
    Rectangle {
        id: tabBarBackground
        anchors.fill: parent
        color: "#191919"
        z: 0

        readonly property int cornerRadius: 10

        topLeftRadius: (!root.hasTopSibling && !root.hasLeftSibling) ? cornerRadius : 0
        topRightRadius: (!root.hasTopSibling && !root.hasRightSibling) ? cornerRadius : 0
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
    // TABS ROW (z: 1)
    // -------------------------------------------------------------------------
    Row {
        id: tabBarRow
        z: 1
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        spacing: 4

        property int hoveredIndex: -1

        Repeater {
            id: tabRepeater
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
                    ColorAnimation {
                        duration: 150
                    }
                }

                // Left-click tab to switch active panel and update layoutController
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.groupCpp) {
                            if (typeof root.groupCpp.setCurrentIndex === "function")
                                root.groupCpp.setCurrentIndex(index);
                            else
                                root.groupCpp.currentIndex = index;
                        }
                        if (typeof layoutController !== "undefined" && layoutController) {
                            var dw = (root.groupCpp && typeof root.groupCpp.dockWidgetAt === "function") ? root.groupCpp.dockWidgetAt(index) : null;
                            if (dw && dw.uniqueName) {
                                layoutController.setActiveDockId(dw.uniqueName);
                            }
                        }
                    }
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
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }

        Connections {
            target: typeof root.tabBarCpp !== "undefined" ? root.tabBarCpp : null
            function onHoveredTabIndexChanged(index) {
                tabBarRow.hoveredIndex = index;
            }
        }
    }

    // -------------------------------------------------------------------------
    // RIGHT-CLICK INTERCEPTOR FOR TABS ROW ONLY (z: 2)
    // -------------------------------------------------------------------------
    MouseArea {
        id: tabBarContextMenuArea
        z: 2
        anchors.fill: tabBarRow
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.ArrowCursor

        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                var globalPt = mapToItem(null, mouse.x, mouse.y);
                var clickedIndex = root.getTabIndexAtPosition(globalPt);
                root.targetTabIndex = clickedIndex;

                var localPos = mapToItem(root, mouse.x, mouse.y);
                var targetX = Math.max(4, Math.min(localPos.x, root.width - contextMenu.width - 4));
                var targetY = Math.max(4, localPos.y);

                contextMenu.x = targetX;
                contextMenu.y = targetY;
                contextMenu.open();
            }
        }
    }

    Popup {
        id: contextMenu
        parent: root
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 8

        background: Rectangle {
            id: popupSurface
            anchors.fill: parent
            color: "#181818"
            border.color: "#303030"
            border.width: 1
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
            id: popupLayout
            spacing: 2
            width: 180

            ContextMenuRow {
                readonly property bool targetFloating: root.isTargetTabFloating()
                iconSource: targetFloating ? "qrc:/assets/icons/minimize.svg" : "qrc:/assets/icons/maximize.svg"
                text: targetFloating ? "Dock" : "Float"
                tooltip: targetFloating ? "Docks window back into main layout" : "Detaches window into floating mode"
                onClicked: {
                    contextMenu.close();
                    contextMenu.visible = false;
                    root.floatTargetTab();
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#282828"
                Layout.topMargin: 3
                Layout.bottomMargin: 3
            }

            ContextMenuRow {
                iconSource: "qrc:/assets/icons/x.svg"
                text: "Close"
                destructive: true
                tooltip: "Closes this tab"
                onClicked: {
                    contextMenu.close();
                    contextMenu.visible = false;
                    root.closeTargetTab();
                }
            }
        }
    }

    component ContextMenuRow: Rectangle {
        id: row
        property string iconSource
        property string text
        property string shortcut: ""
        property bool destructive: false
        property bool showArrow: false
        property bool enabled_: true
        property string tooltip: ""

        signal clicked

        Layout.fillWidth: true
        implicitWidth: rowContent.implicitWidth + 18
        implicitHeight: rowContent.implicitHeight + 12
        radius: 7
        color: rowMouse.containsMouse && row.enabled_ ? "#252525" : "#181818"

        Behavior on color {
            ColorAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (row.enabled_) {
                    row.clicked();
                }
            }
        }

        RowLayout {
            id: rowContent
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            spacing: 10

            Item {
                id: iconContainer
                implicitWidth: 16
                implicitHeight: 16
                visible: row.iconSource !== ""
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: iconImg
                    anchors.fill: parent
                    source: row.iconSource
                    sourceSize: Qt.size(16, 16)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: iconImg
                    source: iconImg
                    colorization: 1.0
                    colorizationColor: row.enabled_ ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0")) : "#555555"
                }
            }

            Text {
                id: titleText
                text: row.text
                color: row.enabled_ ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0")) : "#555555"
                font.pixelSize: 12
                Layout.minimumWidth: 90
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
