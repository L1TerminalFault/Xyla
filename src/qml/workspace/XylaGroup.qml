import QtQuick
import com.kdab.dockwidgets 2.0

Rectangle {
    id: root

    property GroupView groupCpp
    readonly property QtObject titleBarCpp: groupCpp ? groupCpp.titleBar : null
    readonly property int nonContentsHeight: (titleBar.item ? titleBar.item.heightWhenVisible : 0) + tabbar.implicitHeight + (2 * contentsMargin) + titleBarContentsMargin
    property int contentsMargin: 0
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

    anchors.fill: parent

    // =========================================================================
    // DOCKING AREA SIBLING & EDGE DETECTION
    // =========================================================================
    readonly property Item dockingAreaItem: {
        var p = parent;
        while (p) {
            if (p.toString().indexOf("DockingArea") !== -1 || p.objectName === "MainLayout-1" || p.uniqueName !== undefined)
                return p;
            p = p.parent;
        }
        return null;
    }

    property bool hasTopSibling: true
    property bool hasBottomSibling: true
    property bool hasLeftSibling: true
    property bool hasRightSibling: true

    function evaluateNeighbors() {
        if (!root.visible)
            return;
        if (root.isFloating) {
            hasTopSibling = false;
            hasBottomSibling = false;
            hasLeftSibling = false;
            hasRightSibling = false;
            return;
        }

        var area = dockingAreaItem;
        if (!area || area.width <= 0 || area.height <= 0) {
            var win = root.Window.contentItem;
            if (!win)
                return;
            area = win;
        }

        var pt = root.mapToItem(area, 0, 0);
        var tol = 6;

        hasLeftSibling = (pt.x > tol);
        hasTopSibling = (pt.y > tol);
        hasRightSibling = ((pt.x + root.width) < (area.width - tol));
        hasBottomSibling = ((pt.y + root.height) < (area.height - tol));
    }

    onXChanged: Qt.callLater(evaluateNeighbors)
    onYChanged: Qt.callLater(evaluateNeighbors)
    onWidthChanged: Qt.callLater(evaluateNeighbors)
    onHeightChanged: Qt.callLater(evaluateNeighbors)
    onVisibleChanged: if (visible)
        Qt.callLater(evaluateNeighbors)
    onParentChanged: Qt.callLater(evaluateNeighbors)
    Component.onCompleted: Qt.callLater(evaluateNeighbors)

    // =========================================================================
    // SELECTIVE CORNER RADII
    // =========================================================================
    readonly property int cornerRadius: 10

    topLeftRadius: (root.isFloating || (!hasTopSibling && !hasLeftSibling)) ? cornerRadius : 0
    topRightRadius: (root.isFloating || (!hasTopSibling && !hasRightSibling)) ? cornerRadius : 0
    bottomLeftRadius: (root.isFloating || (!hasBottomSibling && !hasLeftSibling)) ? cornerRadius : 0
    bottomRightRadius: (root.isFloating || (!hasBottomSibling && !hasRightSibling)) ? cornerRadius : 0
    color: "#0E0E0E"
    border {
        color: systemPalette.mid
        width: 0
    }

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
