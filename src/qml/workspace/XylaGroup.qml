import QtQuick
import com.kdab.dockwidgets 2.0

Rectangle {
    id: root

    property GroupView groupCpp
    readonly property QtObject titleBarCpp: groupCpp ? groupCpp.titleBar : null
    readonly property int nonContentsHeight: (titleBar.item ? titleBar.item.heightWhenVisible : 0) + tabbar.implicitHeight + (2 * contentsMargin) + titleBarContentsMargin
    property int contentsMargin: 0 // isMDI ? 2 : 1
    property int titleBarContentsMargin: 0
    property int mouseResizeMargin: 8
    readonly property bool isMDI: groupCpp && groupCpp.isMDI
    readonly property bool resizeAllowed: root.isMDI && !Singletons.helpers.isDragging && Singletons.dockRegistry && (!Singletons.helpers.groupViewInMDIResize || Singletons.helpers.groupViewInMDIResize === groupCpp)
    property alias tabBarHeight: tabbar.height
    readonly property bool hasCustomMouseEventRedirector: false
    readonly property bool isFixedHeight: groupCpp && groupCpp.isFixedHeight
    readonly property bool isFixedWidth: groupCpp && groupCpp.isFixedWidth
    readonly property bool tabsAtTop: !groupCpp || !groupCpp.tabsAtBottom

    SystemPalette {
        id: systemPalette
    }

    anchors {
      fill: parent
      // margins: 1
    }

    // =========================================================================
    // DOCKING AREA SIBLING & EDGE DETECTION
    // =========================================================================
    readonly property Item dockingAreaItem: {
        var p = parent
        while (p) {
            if (p.toString().indexOf("DockingArea") !== -1 || p.objectName === "MainLayout-1" || p.uniqueName !== undefined)
                return p
            p = p.parent
        }
        return null
    }

    property bool hasTopSibling: true
    property bool hasBottomSibling: true
    property bool hasLeftSibling: true
    property bool hasRightSibling: true

    function evaluateNeighbors() {
        if (!root.visible) return

        if (root.isFloating) {
            hasTopSibling = false
            hasBottomSibling = false
            hasLeftSibling = false
            hasRightSibling = false
            return
        }

        var area = dockingAreaItem
        if (!area || area.width <= 0 || area.height <= 0) {
            var win = root.Window.contentItem
            if (!win) return
            area = win
        }

        var pt = root.mapToItem(area, 0, 0)
        var tol = 6

        hasLeftSibling = (pt.x > tol)
        hasTopSibling = (pt.y > tol)
        hasRightSibling = ((pt.x + root.width) < (area.width - tol))
        hasBottomSibling = ((pt.y + root.height) < (area.height - tol))
    }

    // Direct geometry triggers
    onXChanged: Qt.callLater(evaluateNeighbors)
    onYChanged: Qt.callLater(evaluateNeighbors)
    onWidthChanged: Qt.callLater(evaluateNeighbors)
    onHeightChanged: Qt.callLater(evaluateNeighbors)
    onVisibleChanged: if (visible) Qt.callLater(evaluateNeighbors)
    onParentChanged: Qt.callLater(evaluateNeighbors)
    Component.onCompleted: Qt.callLater(evaluateNeighbors)

    // Re-evaluate when parent splitter resizes or child docks are removed/added:
    Connections {
        target: root.parent
        ignoreUnknownSignals: true
        function onWidthChanged() { Qt.callLater(root.evaluateNeighbors); }
        function onHeightChanged() { Qt.callLater(root.evaluateNeighbors); }
        function onChildrenChanged() { Qt.callLater(root.evaluateNeighbors); }
    }

    // Re-evaluate whenever ANY dock in the workspace is added, closed, or removed
    Connections {
        target: (typeof Singletons !== "undefined" && Singletons.dockRegistry) ? Singletons.dockRegistry : null
        ignoreUnknownSignals: true
        function onDockWidgetAdded() { Qt.callLater(root.evaluateNeighbors); }
        function onDockWidgetRemoved() { Qt.callLater(root.evaluateNeighbors); }
        function onFloatingWindowAdded() { Qt.callLater(root.evaluateNeighbors); }
        function onFloatingWindowRemoved() { Qt.callLater(root.evaluateNeighbors); }
        function onLayoutChanged() { Qt.callLater(root.evaluateNeighbors); }
    }

    // =========================================================================
    // SELECTIVE CORNER RADII (Replaces static radius: 10)
    // =========================================================================
    readonly property int cornerRadius: 10

    topLeftRadius: (root.isFloating || (!hasTopSibling && !hasLeftSibling)) ? cornerRadius : 0
    topRightRadius: (root.isFloating || (!hasTopSibling && !hasRightSibling)) ? cornerRadius : 0
    bottomLeftRadius: (root.isFloating || (!hasBottomSibling && !hasLeftSibling)) ? cornerRadius : 0
    bottomRightRadius: (root.isFloating || (!hasBottomSibling && !hasRightSibling)) ? cornerRadius : 0
    color: "#0E0E0E"                    // ← solid background (no transparency needed)
    border {
        color: systemPalette.mid
        width: 0
    }
    // =======================================

    // Keep everything else exactly as in the official Group.qml
    onGroupCppChanged: {
        if (groupCpp) {
            groupCpp.setStackLayout(stackLayout);
        }
    }

    onNonContentsHeightChanged: {
        if (groupCpp)
            groupCpp.geometryUpdated();
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor

        // ... (keep all the MDIResizeHandlerHelper items exactly as in the original)
        // For brevity I'm omitting the 8 resize helpers here – copy them from the official file
    }

    Loader {
        id: titleBar
        readonly property QtObject titleBarCpp: root.titleBarCpp
        source: root.groupCpp ? Singletons.widgetFactory.titleBarFilename() : ""

        anchors {
            top: parent ? parent.top : undefined
            left: parent ? parent.left : undefined
            right: parent ? parent.right : undefined
            topMargin: root.titleBarContentsMargin
            leftMargin: root.titleBarContentsMargin
            rightMargin: root.titleBarContentsMargin
        }
    }

    Loader {
        id: tabbar
        readonly property GroupView groupCpp: root.groupCpp
        readonly property bool hasCustomMouseEventRedirector: root.hasCustomMouseEventRedirector

        source: groupCpp ? Singletons.widgetFactory.tabbarFilename() : ""

        function topAnchor() {
            if (root.tabsAtTop) {
                return (titleBar && titleBar.visible) ? titleBar.bottom : (parent ? parent.top : undefined);
            } else {
                return undefined;
            }
        }

        anchors {
            left: parent ? parent.left : undefined
            right: parent ? parent.right : undefined
            top: topAnchor()
            bottom: root.tabsAtTop ? undefined : parent.bottom
            leftMargin: 1
            rightMargin: 1
        }
    }

    Item {
        id: stackLayout

        function bottomAnchor() {
            if (!parent)
                return undefined;

            if (root.tabsAtTop || !tabbar.visible)
                return parent.bottom;

            return tabbar.top;
        }

        anchors {
            left: parent ? parent.left : undefined
            right: parent ? parent.right : undefined
            top: (parent && tabbar.visible && root.tabsAtTop) ? tabbar.bottom : ((titleBar && titleBar.visible) ? titleBar.bottom : parent ? parent.top : undefined)
            bottom: bottomAnchor()

            leftMargin: root.contentsMargin
            rightMargin: root.contentsMargin
            bottomMargin: root.contentsMargin
        }
    }
}
